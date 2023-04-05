"""
Solves an SCOPF problem for integrated HVAC and HVDC grid by iteratively checking for
violated contingencies and resolving until a fixed-point is reached.

"""
function run_ACDC_scopf_contigency_cuts(network::Dict{String,<:Any}, model_type::Type, run_scopf_prob::Function, check_contingency_violation::Function, optimizer, setting; max_iter::Int=100, time_limit::Float64=Inf)   
    if _IM.ismultinetwork(network)
        Memento.error(_LOGGER, "run_ACDC_scopf_contigency_cuts can only be used on single networks")
    end

    time_start = time()
    result_scopf = Dict{String,Any}()
    solution_mp = Dict()
    network["gen_cont_vio"] = 0.0
    network["branch_cont_vio"] = 0.0
    network["branchdc_cont_vio"] = 0.0
    network["convdc_cont_vio"] = 0.0

    network_base = deepcopy(network)
    network_active = deepcopy(network)

    network_active["gen_contingencies"] = []
    network_active["branch_contingencies"] = []
    network_active["branchdc_contingencies"] = []
    network_active["convdc_contingencies"] = []

    result_scopf["gen_contingencies_unsecure"] = []
    result_scopf["branch_contingencies_unsecure"] = []
    result_scopf["branchdc_contingencies_unsecure"] = []
    result_scopf["convdc_contingencies_unsecure"] = []

    multinetwork = build_ACDC_scopf_multinetwork(network_active)
    result = run_scopf_prob(multinetwork, model_type, optimizer; setting = setting)
    result_scopf["base"] = result  
    
    if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        Memento.error(_LOGGER, "base-case ACDC SCOPF solve failed in run_c1_scopf_contigency_cuts, status $(result["termination_status"])")
    end
    #_PM.print_summary(result["solution"])
    solution = result["solution"]["nw"]["0"]
    solution["per_unit"] = result["solution"]["per_unit"]

    _PM.update_data!(network_base, solution)
    _PM.update_data!(network_active, solution)
    # update dc part
    for (i,conv) in network_base["convdc"]
        conv["P_g"] = -solution["convdc"][i]["pgrid"]
        conv["Q_g"] = solution["convdc"][i]["qgrid"]
        if conv["type_dc"] == 2
            conv["type_dc"] == 2
        else
            conv["type_dc"] == 1
        end
        conv["Pdcset"] = solution["convdc"][i]["pdc"]
    end
    for (i,conv) in network_active["convdc"]
        conv["P_g"] = -solution["convdc"][i]["pgrid"]
        conv["Q_g"] = solution["convdc"][i]["qgrid"]
        if conv["type_dc"] == 2
            conv["type_dc"] == 2
        else
            conv["type_dc"] == 1
        end
        conv["Pdcset"] = solution["convdc"][i]["pdc"]
    end
    
    for (i, branch) in network_base["branch"]
        if haskey(solution["branch"], i)
            branch["tap"] = solution["branch"][i]["tm"]
            branch["shift"] = solution["branch"][i]["ta"]
        end
    end
    for (i, branch) in network_active["branch"]
        if haskey(solution["branch"], i)
            branch["tap"] = solution["branch"][i]["tm"]
            branch["shift"] = solution["branch"][i]["ta"]
        end
    end

    

    result["iterations"] = 0

    iteration = 1
    contingencies_found = 1
    while contingencies_found > 0
        time_start_iteration = time()

        contingencies = check_contingency_violation(network_base, model_type, optimizer, setting, contingency_limit=iteration)    
        #println(contingencies)
        # result_scopf["$iteration"] = Dict{String,Any}()
        # result_scopf["$iteration"]["sol_c"] = contingencies.results_c                               # post-contingency results 

        contingencies_found = 0
        #append!(network_active["gen_contingencies"], contingencies.gen_contingencies)
        for cont in contingencies.gen_contingencies
            if cont in network_active["gen_contingencies"]
                _PMSC.warn(_LOGGER, "generator contingency $(cont.label) is active but not secure")
                if !(cont in result_scopf["gen_contingencies_unsecure"])
                    push!(result_scopf["gen_contingencies_unsecure"], cont)
                end
            else
                push!(network_active["gen_contingencies"], cont)
                network_active["gen_cont_vio"] += contingencies.gen_cut_vio
                contingencies_found += 1
            end
        end

        #append!(network_active["branch_contingencies"], contingencies.branch_contingencies)
        for cont in contingencies.branch_contingencies
            if cont in network_active["branch_contingencies"]
                _PMSC.warn(_LOGGER, "branch contingency $(cont.label) is active but not secure")
                if !(cont in result_scopf["branch_contingencies_unsecure"])
                    push!(result_scopf["branch_contingencies_unsecure"], cont) 
                end
            else
                push!(network_active["branch_contingencies"], cont)
                network_active["branch_cont_vio"] += contingencies.branch_cut_vio
                contingencies_found += 1
            end
        end
        
        #append!(network_active["branchdc_contingencies"], contingencies.branchdc_contingencies)
        for cont in contingencies.branchdc_contingencies
            if cont in network_active["branchdc_contingencies"]
                _PMSC.warn(_LOGGER, "branchdc contingency $(cont.label) is active but not secure")
                if !(cont in result_scopf["branchdc_contingencies_unsecure"])
                    push!(result_scopf["branchdc_contingencies_unsecure"], cont)
                end
            else
                push!(network_active["branchdc_contingencies"], cont)
                network_active["branchdc_cont_vio"] += contingencies.branchdc_cut_vio
                contingencies_found += 1
            end
        end

        #append!(network_active["convdc_contingencies"], contingencies.convdc_contingencies)
        for cont in contingencies.convdc_contingencies
            if cont in network_active["convdc_contingencies"]
                _PMSC.warn(_LOGGER, "convdc contingency $(cont.label) is active but not secure")
                if !(cont in result_scopf["convdc_contingencies_unsecure"])
                    push!(result_scopf["convdc_contingencies_unsecure"], cont)
                end
            else
                push!(network_active["convdc_contingencies"], cont)
                network_active["convdc_cont_vio"] += contingencies.convdc_cut_vio
                contingencies_found += 1
            end
        end

        if contingencies_found <= 0
            _PMSC.info(_LOGGER, "no new violated contingencies found, scopf fixed-point reached")          
            break
        else
            _PMSC.info(_LOGGER, "found $(contingencies_found) new contingencies with violations")           
        end


        _PMSC.info(_LOGGER, "active contingencies: gen $(length(network_active["gen_contingencies"])), branch $(length(network_active["branch_contingencies"])), branchdc $(length(network_active["branchdc_contingencies"])), convdc $(length(network_active["convdc_contingencies"]))")   #Update_GM

        time_solve_start = time()
        #_PMACDC.fix_data!(network_active)
        multinetwork = build_ACDC_scopf_multinetwork(network_active)
        result = run_scopf_prob(multinetwork, model_type, optimizer; setting = setting)
        # result = run_scopf(multinetwork, model_type, optimizer; setting = setting)
        # result = run_scopf_soft(multinetwork, model_type, optimizer; setting = setting)
        if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
            _PMSC.warn(_LOGGER, "scopf solve failed with status $(result["termination_status"]), terminating fixed-point early")
            break
        end
        # for (nw,nw_sol) in result["solution"]["nw"]
        #     if nw != "0"
        #         println(nw, " ", nw_sol["delta"])
        #     end
        # end
        _PMSC.info(_LOGGER, "objective: $(result["objective"])")
        solution_mp = result
        solution = result["solution"]["nw"]["0"]
        solution["per_unit"] = result["solution"]["per_unit"]

        _PM.update_data!(network_base, solution)
        _PM.update_data!(network_active, solution)

        # update dc part
        for (i,conv) in network_base["convdc"]
            conv["P_g"] = -solution["convdc"][i]["pgrid"]
            conv["Q_g"] = solution["convdc"][i]["qgrid"]
            if conv["type_dc"] == 2
                conv["type_dc"] == 2
            else
                conv["type_dc"] == 1
            end
            conv["Pdcset"] = solution["convdc"][i]["pdc"]
        end
        for (i,conv) in network_active["convdc"]
            conv["P_g"] = -solution["convdc"][i]["pgrid"]
            conv["Q_g"] = solution["convdc"][i]["qgrid"]
            if conv["type_dc"] == 2
                conv["type_dc"] == 2
            else
                conv["type_dc"] == 1
            end
            conv["Pdcset"] = solution["convdc"][i]["pdc"]
        end
        for (i, branch) in network_base["branch"]
            if haskey(solution["branch"], i)
                branch["tap"] = solution["branch"][i]["tm"]
                branch["shift"] = solution["branch"][i]["ta"]
            end
        end
        for (i, branch) in network_active["branch"]
            if haskey(solution["branch"], i)
                branch["tap"] = solution["branch"][i]["tm"]
                branch["shift"] = solution["branch"][i]["ta"]
            end
        end
        

        time_iteration = time() - time_start_iteration
        time_remaining = time_limit - (time() - time_start)
        if time_remaining < time_iteration
            _PMSC.warn(_LOGGER, "insufficent time for next iteration, time remaining $(time_remaining), estimated iteration time $(time_iteration)")
            break
        end
        # result_scopf["itr_time"] = time_iteration
        # result_scopf["vio"] = contingencies.results_c
        iteration += 1
    end

    #result["solution"] = solution
    #result["iterations"] = iteration
    result_scopf["final"] = solution_mp 
    #result_scopf["final"] = result                                                      
    return result_scopf
end
