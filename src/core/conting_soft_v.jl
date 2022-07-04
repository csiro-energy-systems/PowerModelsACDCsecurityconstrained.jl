
"""
Checks a given operating point against the contingencies to look for branch
flow violations.  The DC Power Flow approximation is used for flow simulation.
If a violation is found, computes a PTDF cut based on bus injections.  Uses the
participation factor based generator response model from the ARPA-e GOC
Challenge 1 specification.
"""
function check_c1_contingencies_branch_power_GM(network;
        gen_flow_cut_limit=15, branch_flow_cut_limit=15, branchdc_flow_cut_limit=15, total_cut_limit=typemax(Int64),
        gen_eval_limit=typemax(Int64), branch_eval_limit=typemax(Int64), branchdc_eval_limit=typemax(Int64), sm_threshold=0.01,
        gen_flow_cuts=[], branch_flow_cuts=[], branchdc_flow_cuts=[])     # Update_GM

    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)        #Update_GM

    if _IM.ismultinetwork(network)
        error(_LOGGER, "the branch flow cut generator can only be used on single networks")
    end
    time_contingencies_start = time()

    gen_cuts_active = Dict()
    for gen_cut in gen_flow_cuts
        if !haskey(gen_cuts_active, gen_cut.cont_label)
            gen_cuts_active[gen_cut.cont_label] = Set{Int}()
        end
        push!(gen_cuts_active[gen_cut.cont_label], gen_cut.branch_id)
    end

    branch_cuts_active = Dict()
    for branch_cut in branch_flow_cuts
        if !haskey(branch_cuts_active, branch_cut.cont_label)
            branch_cuts_active[branch_cut.cont_label] = Set{Int}()
        end
        push!(branch_cuts_active[branch_cut.cont_label], branch_cut.branch_id)
    end

    branchdc_cuts_active = Dict()
    for branchdc_cut in branchdc_flow_cuts
        if !haskey(branchdc_cuts_active, branchdc_cut.cont_label)
            branchdc_cuts_active[branchdc_cut.cont_label] = Set{Int}()
        end
        push!(branchdc_cuts_active[branchdc_cut.cont_label], branchdc_cut.branchdc_id)
    end


    network_lal = deepcopy(network) #lal -> losses as loads

    ref_bus_id = _PM.reference_bus(network_lal)["index"]

    gen_pg_init = Dict(i => gen["pg"] for (i,gen) in network_lal["gen"])

    load_active = Dict(i => load for (i,load) in network_lal["load"] if load["status"] != 0)

    pd_total = sum(load["pd"] for (i,load) in load_active)
    p_losses = sum(gen["pg"] for (i,gen) in network_lal["gen"] if gen["gen_status"] != 0) - pd_total
    p_delta = 0.0

    if p_losses > C1_PG_LOSS_TOL
        load_count = length(load_active)
        p_delta = p_losses/load_count
        for (i,load) in load_active
            load["pd"] += p_delta
        end
        warn(_LOGGER, "active power losses found $(p_losses) increasing loads by $(p_delta)")
    end


    gen_contingencies = _PMSC.calc_c1_gen_contingency_subset(network_lal, gen_eval_limit=gen_eval_limit)
    branch_contingencies =  _PMSC.calc_c1_branch_contingency_subset(network_lal, branch_eval_limit=branch_eval_limit)
    branchdc_contingencies = calc_c1_branchdc_contingency_subset(network_lal, branchdc_eval_limit=branchdc_eval_limit)            # Update_GM

    ######################################################################################################################################################
    gen_cuts = []
    for (i,cont) in enumerate(gen_contingencies)
        if length(gen_cuts) >= gen_flow_cut_limit
            _PMSC.info(_LOGGER, "hit gen flow cut limit $(gen_flow_cut_limit)")
            break
        end
        if length(gen_cuts) >= total_cut_limit
            _PMSC.info(_LOGGER, "hit total cut limit $(total_cut_limit)")
            break
        end
        #info(_LOGGER, "working on ($(i)/$(gen_eval_limit)/$(gen_cont_total)): $(cont.label)")

        for (i,gen) in network_lal["gen"]
            gen["pg"] = gen_pg_init[i]
        end

        cont_gen = network_lal["gen"]["$(cont.idx)"]
        pg_lost = cont_gen["pg"]

        cont_gen["gen_status"] = 0
        cont_gen["pg"] = 0.0


        gen_bus = network_lal["bus"]["$(cont_gen["gen_bus"])"]
        gen_set = network_lal["area_gens"][gen_bus["area"]]

        gen_active = Dict(i => gen for (i,gen) in network_lal["gen"] if gen["index"] != cont.idx && gen["index"] in gen_set && gen["gen_status"] != 0)

        alpha_gens = [gen["alpha"] for (i,gen) in gen_active]
        if length(alpha_gens) == 0 || isapprox(sum(alpha_gens), 0.0)
            _PMSC.warn(_LOGGER, "no available active power response in cont $(cont.label), active gens $(length(alpha_gens))")
            continue
        end

        alpha_total = sum(alpha_gens)
        delta = pg_lost/alpha_total
        network_lal["delta"] = delta
        #info(_LOGGER, "$(pg_lost) - $(alpha_total) - $(delta)")

        for (i,gen) in gen_active
            gen["pg"] += gen["alpha"]*delta
        end

        try
            solution =  run_acdcpf_GM( network_lal, _PM.ACPPowerModel, optimizer; setting = s)["solution"]  # _PM.compute_dc_pf(network_lal)["solution"]       # Update_GM function acdcpf
            _PM.update_data!(network_lal, solution)
        catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")
            continue
        end

        #flow = _PM.calc_branch_flow_dc(network_lal)
        #_PM.update_data!(network_lal, flow)


        vio = calc_c1_violations_GM(network_lal, network_lal)            # Update_GM 

        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.sm > sm_threshold
            branch_vios = branch_c1_violations_sorted(network_lal, network_lal)
            branch_vio = branch_vios[1]

            if !haskey(gen_cuts_active, cont.label) || !(branch_vio.branch_id in gen_cuts_active[cont.label])
                _PMSC.info(_LOGGER, "adding flow cut on cont $(cont.label) branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")

                am = _PM.calc_susceptance_matrix(network_lal)
                branch = network_lal["branch"]["$(branch_vio.branch_id)"]

                bus_injection = calc_c1_branch_ptdf_single(am, ref_bus_id, branch)
                cut = (gen_id=cont.idx, cont_label=cont.label, branch_id=branch_vio.branch_id, rating_level=1.0, bus_injection=bus_injection)
                push!(gen_cuts, cut)
            else
                _PMSC.warn(_LOGGER, "skipping active flow cut on cont $(cont.label) branch $(branch_vio.branch_id) with constraint flow violations $(branch_vio.sm_vio)")
            end

        end

        cont_gen["gen_status"] = 1
        cont_gen["pg"] = pg_lost
        network_lal["delta"] = 0.0
    end
######################################################################################################################################################

    branch_cuts = []
    for (i,cont) in enumerate(branch_contingencies)
        if length(branch_cuts) >= branch_flow_cut_limit
            info(_LOGGER, "hit branch flow cut limit $(branch_flow_cut_limit)")
            break
        end
        if length(gen_cuts) + length(branch_cuts) >= total_cut_limit
            info(_LOGGER, "hit total cut limit $(total_cut_limit)")
            break
        end

        #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

        cont_branch = network_lal["branch"]["$(cont.idx)"]
        cont_branch["br_status"] = 0

        try
            solution = _PM.compute_dc_pf(network_lal)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            warn(_LOGGER, "linear solve failed on $(cont.label)")
            continue
        end

        flow = _PM.calc_branch_flow_dc(network_lal)
        _PM.update_data!(network_lal, flow)

        vio = calc_c1_violations(network_lal, network_lal)

        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold
        if vio.sm > sm_threshold
            branch_vio = branch_c1_violations_sorted(network_lal, network_lal)[1]
            if !haskey(branch_cuts_active, cont.label) || !(branch_vio.branch_id in branch_cuts_active[cont.label])
                info(_LOGGER, "adding flow cut on cont $(cont.label) branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")

                am = _PM.calc_susceptance_matrix(network_lal)
                branch = network_lal["branch"]["$(branch_vio.branch_id)"]

                bus_injection = calc_c1_branch_ptdf_single(am, ref_bus_id, branch)
                cut = (cont_label=cont.label, branch_id=branch_vio.branch_id, rating_level=1.0, bus_injection=bus_injection)
                push!(branch_cuts, cut)
            else
                warn(_LOGGER, "skipping active flow cut on cont $(cont.label) branch $(branch_vio.branch_id) with constraint flow violations $(branch_vio.sm_vio)")
            end
        end

        cont_branch["br_status"] = 1
    end
######################################################################################################################################################


######################################################################################################################################################

    if p_delta != 0.0
        warn(_LOGGER, "re-adjusting loads by $(-p_delta)")
        for (i,load) in load_active
            load["pd"] -= p_delta
        end
    end

    time_contingencies = time() - time_contingencies_start
    info(_LOGGER, "contingency eval time: $(time_contingencies)")

    return (gen_cuts=gen_cuts, branch_cuts=branch_cuts)
end
