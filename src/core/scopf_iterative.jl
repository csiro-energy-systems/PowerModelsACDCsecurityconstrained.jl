"""
Solves an ACDC SCOPF problem by iteratively checking for violated contingencies and 
resolving until a fixed-point is reached
"""
function run_c1_scopf_contigency_cuts_GM(network::Dict{String,<:Any}, model_type::Type, optimizer, setting; max_iter::Int=100, time_limit::Float64=Inf)    #Update_GM
    if _IM.ismultinetwork(network)
        error(_LOGGER, "run_c1_scopf_contigency_cuts_GM can only be used on single networks")
    end

    time_start = time()
    network["gen_cont_vio"] = 0.0
    network["branch_cont_vio"] = 0.0
    network["branchdc_cont_vio"] = 0.0

    network_base = deepcopy(network)
    network_active = deepcopy(network)

    network_active["gen_contingencies"] = []
    network_active["branch_contingencies"] = []
    network_active["branchdc_contingencies"] = []

    multinetwork = build_c1_scopf_multinetwork_GM(network_active)
    result = run_c1_scopf_GM(multinetwork, model_type, optimizer; setting = setting)
    
    if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        error(_LOGGER, "base-case ACDC SCOPF solve failed in run_c1_scopf_contigency_cuts, status $(result["termination_status"])")
    end
    #_PM.print_summary(result["solution"])
    solution = result["solution"]["nw"]["0"]
    solution["per_unit"] = result["solution"]["per_unit"]

    _PM.update_data!(network_base, solution)
    _PM.update_data!(network_active, solution)

    result["iterations"] = 0

    iteration = 1
    contingencies_found = 1
    result_scopf = Dict{String,Any}()
    while contingencies_found > 0
        time_start_iteration = time()

        contingencies = check_c1_contingency_violations_GM(network_base, model_type, optimizer, setting, contingency_limit=iteration)    #Update_GM
        #println(contingencies)
        result_scopf["$iteration"] = Dict{String,Any}()
        result_scopf["$iteration"]["sol_c"] = contingencies.results_c                                        # result dictionary_GM

        contingencies_found = 0
        #append!(network_active["gen_contingencies"], contingencies.gen_contingencies)
        for cont in contingencies.gen_contingencies
            if cont in network_active["gen_contingencies"]
                _PMSC.warn(_LOGGER, "generator contingency $(cont.label) is active but not secure")
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
            else
                push!(network_active["branchdc_contingencies"], cont)
                network_active["branchdc_cont_vio"] += contingencies.branchdc_cut_vio
                contingencies_found += 1
            end
        end

        if contingencies_found <= 0
            _PMSC.info(_LOGGER, "no new violated contingencies found, scopf fixed-point reached")           #Update_GM
            break
        else
            _PMSC.info(_LOGGER, "found $(contingencies_found) new contingencies with violations")           #Update_GM
        end


        _PMSC.info(_LOGGER, "active contingencies: gen $(length(network_active["gen_contingencies"])), branch $(length(network_active["branch_contingencies"])), branchdc $(length(network_active["branchdc_contingencies"]))")   #Update_GM

        time_solve_start = time()
        #_PMACDC.fix_data!(network_active)
        multinetwork = build_c1_scopf_multinetwork_GM(network_active)   #Update_GM
        result = run_c1_scopf_GM(multinetwork, model_type, optimizer; setting = setting)   #Update_GM    _soft
        # result = run_c1_scopf_GM_soft(multinetwork, model_type, optimizer; setting = setting)   #Update_GM    _soft
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
        solution = result["solution"]["nw"]["0"]
        solution["per_unit"] = result["solution"]["per_unit"]

        _PM.update_data!(network_base, solution)
        _PM.update_data!(network_active, solution)

        time_iteration = time() - time_start_iteration
        time_remaining = time_limit - (time() - time_start)
        if time_remaining < time_iteration
            _PMSC.warn(_LOGGER, "insufficent time for next iteration, time remaining $(time_remaining), estimated iteration time $(time_iteration)")
            break
        end
        iteration += 1
    end

    result["solution"] = solution
    result["iterations"] = iteration
    result_scopf["final"] = result                                                       # result dictionary_GM
    return result_scopf
end
