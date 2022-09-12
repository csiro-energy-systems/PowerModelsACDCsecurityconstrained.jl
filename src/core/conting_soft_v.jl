
"""
Checks a given operating point against the contingencies to look for branch
flow violations.  The DC Power Flow approximation is used for flow simulation.
If a violation is found, computes a PTDF cut based on bus injections.  Uses the
participation factor based generator response model from the ARPA-e GOC
Challenge 1 specification.
"""
function check_c1_contingencies_branch_power_GM(network, optimizer;
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
        _PMSC.warn(_LOGGER, "active power losses found $(p_losses) increasing loads by $(p_delta)")
    end


    gen_contingencies = _PMSC.calc_c1_gen_contingency_subset(network_lal, gen_eval_limit=gen_eval_limit)
    branch_contingencies =  _PMSC.calc_c1_branch_contingency_subset(network_lal, branch_eval_limit=branch_eval_limit)
    branchdc_contingencies = calc_c1_branchdc_contingency_subset(network_lal, branchdc_eval_limit=branchdc_eval_limit)            

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
            solution =  run_acdcpf_GM( network_lal, _PM.ACPPowerModel, optimizer; setting = s)["solution"]       
            _PM.update_data!(network_lal, solution)
        catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")
            continue
        end


        vio = calc_violations(network_lal, network_lal)             

        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.sm > sm_threshold
            branch_vios = _PMSC.branch_c1_violations_sorted(network_lal, network_lal)          # Update_GM 
            branch_vio = branch_vios[1]


            if !haskey(gen_cuts_active, cont.label) || !(branch_vio.branch_id in gen_cuts_active[cont.label])
                _PMSC.info(_LOGGER, "adding flow cut on cont $(cont.label) branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")

                branch = network_lal["branch"]["$(branch_vio.branch_id)"]
                
                ptdf_branch, dcdf_branch = calc_branch_ptdf_branchdc_dcdf_single(network_lal, ref_bus_id, branch)
                
                cut = (gen_cont_id=cont.idx, cont_label=cont.label, branch_id=branch_vio.branch_id, rating_level=1.0, ptdf_branch=ptdf_branch, dcdf_branch=dcdf_branch)
                push!(gen_cuts, cut)
            else
                _PMSC.warn(_LOGGER, "skipping flow cut on cont $(cont.label) branch $(branch_vio.branch_id) with constraint flow violations $(branch_vio.sm_vio)")
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
            _PMSC.info(_LOGGER, "hit branch flow cut limit $(branch_flow_cut_limit)")
            break
        end
        if length(gen_cuts) + length(branch_cuts) >= total_cut_limit
            _PMSC.info(_LOGGER, "hit total cut limit $(total_cut_limit)")
            break
        end

        #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

        cont_branch = network_lal["branch"]["$(cont.idx)"]
        cont_branch["br_status"] = 0

        try
            solution = run_acdcpf_GM( network_lal, _PM.ACPPowerModel, optimizer; setting = s)["solution"]          
            _PM.update_data!(network_lal, solution)
        catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")
            continue
        end


        vio = calc_violations(network_lal, network_lal)           

        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold
        if vio.sm > sm_threshold
            branch_vio = _PMSC.branch_c1_violations_sorted(network_lal, network_lal)[1]
            if !haskey(branch_cuts_active, cont.label) || !(branch_vio.branch_id in branch_cuts_active[cont.label])
                _PMSC.info(_LOGGER, "adding flow cut on cont $(cont.label) branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")

                branch = network_lal["branch"]["$(branch_vio.branch_id)"]
                
                ptdf_branch, dcdf_branch = calc_branch_ptdf_branchdc_dcdf_single(network_lal, ref_bus_id, branch)
                
                cut = (branch_cont_id=cont.idx, cont_label=cont.label, branch_id=branch_vio.branch_id, rating_level=1.0, ptdf_branch=ptdf_branch, dcdf_branch=dcdf_branch)
                push!(branch_cuts, cut)
            else
                _PMSC.warn(_LOGGER, "skipping flow cut on cont $(cont.label) branch $(branch_vio.branch_id) with constraint flow violations $(branch_vio.sm_vio)")
            end
        end

        cont_branch["br_status"] = 1
    end
######################################################################################################################################################

branchdc_cuts = []
    for (i,cont) in enumerate(branchdc_contingencies)
        if length(branchdc_cuts) >= branchdc_flow_cut_limit
            _PMSC.info(_LOGGER, "hit branchdc flow cut limit $(branchdc_flow_cut_limit)")
            break
        end
        if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) >= total_cut_limit
            _PMSC.info(_LOGGER, "hit total cut limit $(total_cut_limit)")
            break
        end

        cont_branchdc = network_lal["branchdc"]["$(cont.idx)"]
        cont_branchdc["status"] = 0

        try
            solution = run_acdcpf_GM( network_lal, _PM.ACPPowerModel, optimizer; setting = s)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")
            continue
        end

        vio = calc_violations(network_lal, network_lal)             

        ##info(_LOGGER, "$(cont.label) violations $(vio)")
        ##if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.smdc > sm_threshold
            branchdc_vio = branchdc_c1_violations_sorted(network_lal, network_lal)[1]
            if !haskey(branchdc_cuts_active, cont.label) || !(branchdc_vio.branchdc_id in branchdc_cuts_active[cont.label])
                _PMSC.info(_LOGGER, "adding flow cut on cont $(cont.label) branchdc $(branchdc_vio.branchdc_id) due to constraint flow violations $(branchdc_vio.smdc_vio)")

                branchdc = network_lal["branchdc"]["$(branchdc_vio.branchdc_id)"]
                
                ptdf_matrix = calc_ptdf_matrix(network_lal)
                inc_matrix_dc = calc_incidence_matrix_dc(network_lal)
                dcdf_matrix = - ptdf_matrix * transpose(inc_matrix_dc)
                branch_map = dcdf_matrix[1:end, branchdc["index"]]
                branch_index = [branch_map[i] for i in branch_map if branch_map != 0]

                for i = 1: length(branch_index)
                branch = network_lal["branch"]["$i"]
                ptdf_branch, dcdf_branch = calc_branch_ptdf_branchdc_dcdf_single(network_lal, ref_bus_id, branch)
                cut = (branchdc_cont_id=cont.idx, cont_label=cont.label, branch_id=branch_vio.branch_id, rating_level=1.0, ptdf_branch=ptdf_branch, dcdf_branch=dcdf_branch)
                push!(branchdc_cuts, cut)
                end
            else
                _PMSC.warn(_LOGGER, "skipping flow cut on cont $(cont.label) branchdc $(branchdc_vio.branchdc_id) with constraint flow violations $(branchdc_vio.smdc_vio)")
            end
        end

        cont_branchdc["status"] = 1
    end

######################################################################################################################################################

    if p_delta != 0.0
        _PMSC.warn(_LOGGER, "re-adjusting loads by $(-p_delta)")
        for (i,load) in load_active
            load["pd"] -= p_delta
        end
    end

    time_contingencies = time() - time_contingencies_start
    _PMSC.info(_LOGGER, "contingency eval time: $(time_contingencies)")

    return (gen_cuts=gen_cuts, branch_cuts=branch_cuts, branchdc_cuts=branchdc_cuts)
end

##############################################################################################################################################################################
##############################################################################################################################################################################
##############################################################################################################################################################################

"""
Given a network data dict, returns a sparse integer valued incidence
matrix with one row for each branchdc and one column for each busdc.
In each branchdc row a +1 is used to indicate the _from_ bus and -1 is used to
indicate _to_ busdc. mapping converter buses, lossless converter & line assumption
"""
function calc_incidence_matrix_dc(data::Dict{String,<:Any})

    I = Int[]
    J = Int[]   
    V = Int[]

    b = [branchdc for (i,branchdc) in data["branchdc"] if branchdc["status"] != 0]
    branchdc_ordered = sort(b, by=(x) -> x["index"])
    for (i,branchdc) in enumerate(branchdc_ordered)
        fbusdc_conv = [convdc["busac_i"] for (j,convdc) in data["convdc"] if convdc["busdc_i"] == branchdc["fbusdc"]]
        tbusdc_conv = [convdc["busac_i"] for (j,convdc) in data["convdc"] if convdc["busdc_i"] == branchdc["tbusdc"]]
        
        push!(I, i); push!(J, fbusdc_conv[1]); push!(V,  1)
        push!(I, i); push!(J, tbusdc_conv[1]); push!(V, -1)

        for k in length(J):length(data["bus"])
            push!(I, i); push!(J, k); push!(V, 0)
        end
    end

    return _PM.sparse(I,J,V)
end

"""
Given a basic network data dict, returns a PTDF & DCDF matrix corresponding to a single branch

"""
function calc_branch_ptdf_branchdc_dcdf_single(data::Dict{String,<:Any}, ref_bus::Int, branch::Dict{String,<:Any})
    
    ptdf_matrix = calc_ptdf_matrix(data)
    inc_matrix_dc = PowerModelsACDCsecurityconstrained.calc_incidence_matrix_dc(data)   
    dcdf_matrix = - ptdf_matrix * transpose(inc_matrix_dc)

    ptdf_branch_wr = Dict(1:length(ptdf_matrix[branch["index"], :]) .=> - ptdf_matrix[branch["index"], :])
    dcdf_branch = Dict(1:length(dcdf_matrix[branch["index"], :]) .=> - dcdf_matrix[branch["index"], :])
    ptdf_branch = Dict(k => v for (k, v) in ptdf_branch_wr if k != ref_bus)          # remove reference
    
    # single branch PTDF and DCDF matrix 
    return ptdf_branch, dcdf_branch
end

"""
given a network data dict, returns a real valued ptdf matrix with one
row for each branch and one column for each bus in the network.
Multiplying the ptdf matrix by bus injection values yields a vector
active power flow values on each branch.
"""
function calc_ptdf_matrix(data::Dict{String,<:Any})

    num_bus = length(data["bus"])
    num_branch = length(data["branch"])

    b_inv = _PM.calc_susceptance_matrix_inv(data).matrix

    ptdf = zeros(num_branch, num_bus)
    for (i,branch) in data["branch"]
        branch_idx = branch["index"]
        bus_fr = branch["f_bus"]
        bus_to = branch["t_bus"]
        g,b =  _PM.calc_branch_y(branch)
        for n in 1:num_bus
            ptdf[branch_idx, n] = b*(b_inv[bus_fr, n] - b_inv[bus_to, n])
        end
    end

    return ptdf
end