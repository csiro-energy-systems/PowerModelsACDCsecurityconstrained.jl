"""
This function checks a given operating point against the contingencies to look
for branch HVAC and HVDC flow violations. The ACDC Power Flow is used for flow
simulation. It returns a list of contingencies where a violation is found.

"""

function check_contingency_violations_SI(network, model_type, optimizer, setting;
    gen_contingency_limit=1000, branch_contingency_limit=1000, branchdc_contingency_limit=1000, convdc_contingency_limit=1000, contingency_limit=typemax(Int64),
    gen_eval_limit=typemax(Int64), branch_eval_limit=typemax(Int64), branchdc_eval_limit=typemax(Int64), convdc_eval_limit=typemax(Int64), sm_threshold=0.01, pg_threshold=0.01, qg_threshold=0.01,vm_threshold=0.01 )     # Update_GM

    ### results_c = Dict{String,Any}()

    if _IM.ismultinetwork(network)
        error(_LOGGER, "the branch flow cut generator can only be used on single networks")
    end
    time_contingencies_start = time()

    network_lal = deepcopy(network)     # lal -> losses as loads

    #ref_bus_id = _PM.reference_bus(network_lal)["index"]

    gen_pg_init = Dict(i => gen["pg"] for (i,gen) in network_lal["gen"])

    load_active = Dict(i => load for (i, load) in network_lal["load"] if load["status"] != 0)
    
    pd_total = sum(load["pd"] for (i,load) in load_active)
    p_losses = sum(gen["pg"] for (i,gen) in network_lal["gen"] if gen["gen_status"] != 0) - pd_total
    p_delta = 0.0
    
    if p_losses > C1_PG_LOSS_TOL
        load_count = length(load_active)
        p_delta = p_losses/load_count
        for (i,load) in load_active
            load["pd"] += p_delta
        end
        _PMSC.warn(_LOGGER, "ac active power losses found $(p_losses) increasing loads by $(p_delta)")         # Update_GM
    end

    gen_contingencies = _PMSC.calc_c1_gen_contingency_subset(network_lal, gen_eval_limit=gen_eval_limit)
    branch_contingencies = _PMSC.calc_c1_branch_contingency_subset(network_lal, branch_eval_limit=branch_eval_limit)
    branchdc_contingencies = calc_c1_branchdc_contingency_subset(network_lal, branchdc_eval_limit=branchdc_eval_limit)            # Update_GM
    convdc_contingencies = calc_convdc_contingency_subset(network_lal, convdc_eval_limit=convdc_eval_limit)

    ######################################################################################################################################################
    total_cuts_pre_filter = []
    gen_cuts = []
    gen_cut_vio = 0.0
    for (i,cont) in enumerate(gen_contingencies)
        if length(gen_cuts) >= gen_contingency_limit
            _PMSC.info(_LOGGER, "hit gen cut limit $(gen_contingency_limit)")       # Update_GM
            break
        end
        if length(gen_cuts) >= contingency_limit
            _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")              # Update_GM
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
            _PMSC.warn(_LOGGER, "no available active power response in cont $(cont.label), active gens $(length(alpha_gens))")  # Update_GM
            continue
        end

        alpha_total = sum(alpha_gens)
        delta = pg_lost/alpha_total
        network_lal["delta"] = delta
        #info(_LOGGER, "$(pg_lost) - $(alpha_total) - $(delta)")

        for (i,gen) in gen_active
            gen["pg"] += gen["alpha"]*delta
        end


        for (i,gen) in network_lal["gen"]
            if isnan(gen["pg"]) || isnan(gen["qg"])
                println("gen $i")
            end
        end
        for (i,branch) in network_lal["branch"]
            if isnan(branch["br_r"]) || isnan(branch["br_x"])
                println("branch $i")
            end
        end

        try
            solution =  _PMACDC.run_acdcpf( network_lal, _PM.ACPPowerModel, optimizer, setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
            ### results_c["c$(cont.label)"] = solution  
        catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
            continue
        end

        vio = calc_violations(network_lal, network_lal)            # Update_GM
        ### results_c["vio_c$(cont.label)"] = vio
        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > sm_threshold
            _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $(vio)")           # Update_GM
            push!(gen_cuts, cont)
            gen_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc
        else
            gen_cut_vio = 0.0
        end
        
        cont_gen["gen_status"] = 1
        cont_gen["pg"] = pg_lost
        network_lal["delta"] = 0.0
    end
    ######################################################################################################################################################

    branch_cuts = []
    branch_cut_vio = 0.0
    for (i,cont) in enumerate(branch_contingencies)
        if length(branch_cuts) >= branch_contingency_limit
            _PMSC.info(_LOGGER, "hit branch flow cut limit $(branch_contingency_limit)")                   # Update_GM
            break
        end
        if length(gen_cuts) + length(branch_cuts) >= contingency_limit
            _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                                      # Update_GM
            break
        end

        # info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

        cont_branch = network_lal["branch"]["$(cont.idx)"]
        cont_branch["br_status"] = 0
        _PMACDC.fix_data!(network_lal)
        try
            solution = _PMACDC.run_acdcpf( network_lal, _PM.ACPPowerModel, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
            ### results_c["c$(cont.label)"] = solution
        catch exception
           _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")
           continue
        end
        
        vio = calc_violations(network_lal, network_lal)          # Update_GM 
        ### results_c["vio_c$(cont.label)"] = vio
    
        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > sm_threshold
            _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $(vio)")                              # Update_GM
            push!(branch_cuts, cont)
            branch_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc
        else
            branch_cut_vio = 0.0
        end

        cont_branch["br_status"] = 1
        
    end

    ######################################################################################################################################################
    
    branchdc_cuts = []       # Update_GM
    branchdc_cut_vio = 0.0
    for (i,cont) in enumerate(branchdc_contingencies)        # Update_GM
        if length(branchdc_cuts) >= branchdc_contingency_limit       # Update_GM
            _PMSC.info(_LOGGER, "hit branchdc flow cut limit $(branchdc_contingency_limit)")                # Update_GM
            break
        end
        if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) >= contingency_limit       # Update_GM
            _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                  # Update_GM
            break
        end

        #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

        cont_branchdc = network_lal["branchdc"]["$(cont.idx)"]            # Update_GM
        cont_branchdc["status"] = 0                                       # Update_GM

        try
            solution = _PMACDC.run_acdcpf( network_lal, _PM.ACPPowerModel, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
            ### results_c["c$(cont.label)"] = solution
        catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
            continue
        end

        vio = calc_violations(network_lal, network_lal)          # Update_GM 
        ### results_c["vio_c$(cont.label)"] = vio
        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.smdc > sm_threshold || vio.sm > sm_threshold
            _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $(vio)")            # Update_GM
            push!(branchdc_cuts, cont)
            branchdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc
        else
            branchdc_cut_vio = 0.0
        end

        cont_branchdc["status"] = 1
    end

    ######################################################################################################################################################
    convdc_cuts = []  
    convdc_cut_vio = 0.0
    for (i,cont) in enumerate(convdc_contingencies)        # Update_GM
        if length(convdc_cuts) >= convdc_contingency_limit       # Update_GM
            _PMSC.info(_LOGGER, "hit convdc cut limit $(convdc_contingency_limit)")                # Update_GM
            break
        end
        if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) + length(convdc_cuts) >= contingency_limit       # Update_GM
            _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                  # Update_GM
            break
        end

        #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

        cont_convdc = network_lal["convdc"]["$(cont.idx)"]            # Update_GM
        cont_convdc["status"] = 0                                       # Update_GM

        try
            solution = _PMACDC.run_acdcpf( network_lal, _PM.ACPPowerModel, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
            ### results_c["c$(cont.label)"] = solution
        catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
            continue
        end

        vio = calc_violations(network_lal, network_lal)          # Update_GM 
        ### results_c["vio_c$(cont.label)"] = vio
        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold || vio.cmac > sm_threshold || vio.cmdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > sm_threshold 
            _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $(vio)")            # Update_GM
            push!(convdc_cuts, cont)
            convdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
        else
            convdc_cut_vio = 0.0
        end

        cont_convdc["status"] = 1
    end



    ######################################################################################################################################################

    if p_delta != 0.0
        _PMSC.warn(_LOGGER, "re-adjusting ac loads by $(-p_delta)")        # Update_GM
        for (i,load) in load_active
            load["pd"] -= p_delta
        end
    end
    total_cuts_pre_filter = 0
    time_contingencies = time() - time_contingencies_start
    _PMSC.info(_LOGGER, "contingency eval time: $(time_contingencies)")            # Update_GM

    return (gen_contingencies=gen_cuts, branch_contingencies=branch_cuts, branchdc_contingencies=branchdc_cuts, convdc_contingencies=convdc_cuts, gen_cut_vio, branch_cut_vio, branchdc_cut_vio, convdc_cut_vio, total_cuts_pre_filter) # results_c
end


