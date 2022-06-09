function check_c1_contingency_violations_GM(network, optimizer;
    gen_contingency_limit=15, branch_contingency_limit=15, branchdc_contingency_limit=15, contingency_limit=typemax(Int64),
    gen_eval_limit=typemax(Int64), branch_eval_limit=typemax(Int64), branchdc_eval_limit=typemax(Int64), sm_threshold=0.01)     # Update_GM
    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false)            # Update_GM
    results_c = Dict()

if _IM.ismultinetwork(network)
    error(_LOGGER, "the branch flow cut generator can only be used on single networks")
end
time_contingencies_start = time()


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
    _PMSC.warn(_LOGGER, "active power losses found $(p_losses) increasing loads by $(p_delta)")         # Update_GM
end



gen_contingencies = _PMSC.calc_c1_gen_contingency_subset(network_lal, gen_eval_limit=gen_eval_limit)
branch_contingencies = _PMSC.calc_c1_branch_contingency_subset(network_lal, branch_eval_limit=branch_eval_limit)
branchdc_contingencies = calc_c1_branchdc_contingency_subset(network_lal, branchdc_eval_limit=branchdc_eval_limit)            # Update_GM

gen_cuts = []
for (i,cont) in enumerate(gen_contingencies)
    if length(gen_cuts) >= gen_contingency_limit
        _PMSC.info(_LOGGER, "hit gen flow cut limit $(gen_contingency_limit)")       # Update_GM
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

    try
        solution =  run_acdcpf_GM( network_lal, _PM.ACPPowerModel, optimizer; setting = s)["solution"]  # _PM.compute_dc_pf(network_lal)["solution"]       # Update_GM function acdcpf
        _PM.update_data!(network_lal, solution)
        results_c["c$(cont.label)"] = solution  
    catch exception
        _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
        continue
    end
                                          # result dictionary_GM
    ##flow = _PM.calc_branch_flow_dc(network_lal)
    ##_PM.update_data!(network_lal, flow)


    vio = calc_c1_violations_GM(network_lal, network_lal)            # Update_GM
    results_c["vio_c$(cont.label)"] = vio
    #info(_LOGGER, "$(cont.label) violations $(vio)")
    #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold
    if vio.sm > sm_threshold
        _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint flow violations $(vio.sm)")           # Update_GM
        push!(gen_cuts, cont)
    end

    cont_gen["gen_status"] = 1
    cont_gen["pg"] = pg_lost
    network_lal["delta"] = 0.0
end
######################################################################################################################################################

branch_cuts = []
for (i,cont) in enumerate(branch_contingencies)
    if length(branch_cuts) >= branch_contingency_limit
        _PMSC.info(_LOGGER, "hit branch flow cut limit $(branch_contingency_limit)")                   # Update_GM
        break
    end
    if length(gen_cuts) + length(branch_cuts) >= contingency_limit
        _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                                      # Update_GM
        break
    end

    #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

    cont_branch = network_lal["branch"]["$(cont.idx)"]
    cont_branch["br_status"] = 0
    _PMACDC.fix_data!(network_lal)
    #export network_lal        #@show # Update_GM     # Update_GM     # Update_GM
    #try
        solution = run_acdcpf_GM( network_lal, _PM.ACPPowerModel, optimizer; setting = s)["solution"]  # _PM.compute_dc_pf(network_lal)["solution"]       # Update_GM function acdcpf
        _PM.update_data!(network_lal, solution)
        results_c["c$(cont.label)"] = solution
    #catch exception
    #    _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
    #    continue
    #end
                                           # result dictionary_GM
    ##flow = _PM.calc_branch_flow_dc(network_lal)
    ##_PM.update_data!(network_lal, flow)

    vio = calc_c1_violations_GM(network_lal, network_lal)          # Update_GM 
    results_c["vio_c$(cont.label)"] = vio
   
    #info(_LOGGER, "$(cont.label) violations $(vio)")
    #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold
    if vio.sm > sm_threshold
        _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint flow violations $(vio.sm)")                              # Update_GM
        push!(branch_cuts, cont)
    end

    cont_branch["br_status"] = 1
    
end

########################################################################################################################################

if p_delta != 0.0
    _PMSC.warn(_LOGGER, "re-adjusting loads by $(-p_delta)")        # Update_GM
    for (i,load) in load_active
        load["pd"] -= p_delta
    end
end
########################################################################################################################################

branchdc_cuts = []       # Update_GM
for (i,cont) in enumerate(branchdc_contingencies)        # Update_GM
    if length(branchdc_cuts) >= branchdc_contingency_limit       # Update_GM
        _PMSC.info(_LOGGER, "hit branch flow cut limit $(branchdc_contingency_limit)")                # Update_GM
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
        solution = run_acdcpf_GM( network_lal, _PM.ACPPowerModel, optimizer; setting = s)["solution"]  # _PM.compute_dc_pf(network_lal)["solution"]       # Update_GM function acdcpf
        _PM.update_data!(network_lal, solution)
        results_c["c$(cont.label)"] = solution
    catch exception
        _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
        continue
    end
                                           # result dictionary_GM
    ##flow = _PM.calc_branch_flow_dc(network_lal)
    ###_PM.update_data!(network_lal, flow)

    vio = calc_c1_violations_GM(network_lal, network_lal)          # Update_GM 
    results_c["vio_c$(cont.label)"] = vio
    #info(_LOGGER, "$(cont.label) violations $(vio)")
    #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold
    if vio.smdc > sm_threshold
        _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint flow violations $(vio.smdc)")            # Update_GM
        push!(branchdc_cuts, cont)
    end

    cont_branchdc["status"] = 1
end

########################################################################################################################################

time_contingencies = time() - time_contingencies_start
_PMSC.info(_LOGGER, "contingency eval time: $(time_contingencies)")            # Update_GM

return (gen_contingencies=gen_cuts, branch_contingencies=branch_cuts, branchdc_contingencies=branchdc_cuts, results_c)
end