"""
Solves an SCOPF problem for integrated HVAC and HVDC grid by iteratively checking for
violated contingencies and resolving until a fixed-point is reached.

"""
function run_ACDC_scopf_contigency_cuts(network::Dict{String,<:Any}, model_type::Type, run_scopf_prob::Function, optimizer, setting; max_iter::Int=100, time_limit::Float64=Inf)   
    if _IM.ismultinetwork(network)
        error(_LOGGER, "run_ACDC_scopf_contigency_cuts can only be used on single networks")
    end

    time_start = time()
    result_scopf = Dict{String,Any}()
    network["gen_cont_vio"] = 0.0
    network["branch_cont_vio"] = 0.0
    network["branchdc_cont_vio"] = 0.0

    network_base = deepcopy(network)
    network_active = deepcopy(network)

    network_active["gen_contingencies"] = []
    network_active["branch_contingencies"] = []
    network_active["branchdc_contingencies"] = []

    multinetwork = build_ACDC_scopf_multinetwork(network_active)
    result = run_scopf(multinetwork, model_type, optimizer; setting = setting)
    result_scopf["base"] = result  
    
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
    while contingencies_found > 0
        time_start_iteration = time()

        contingencies = check_contingency_violations(network_base, model_type, optimizer, setting, contingency_limit=iteration)    
        #println(contingencies)
        result_scopf["$iteration"] = Dict{String,Any}()
        result_scopf["$iteration"]["sol_c"] = contingencies.results_c                               # post-contingency results 

        contingencies_found = 0
        #append!(network_active["gen_contingencies"], contingencies.gen_contingencies)
        for cont in contingencies.gen_contingencies
            if cont in network_active["gen_contingencies"]
                _PMSC.warn(_LOGGER, "generator contingency $(cont.label) is active but not secure")
                result_scopf["gen_contingencies_unsecure"] = cont
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
                result_scopf["branch_contingencies_unsecure"] = cont 
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
                result_scopf["branchdc_contingencies_unsecure"] = cont
            else
                push!(network_active["branchdc_contingencies"], cont)
                network_active["branchdc_cont_vio"] += contingencies.branchdc_cut_vio
                contingencies_found += 1
            end
        end

        if contingencies_found <= 0
            _PMSC.info(_LOGGER, "no new violated contingencies found, scopf fixed-point reached")          
            break
        else
            _PMSC.info(_LOGGER, "found $(contingencies_found) new contingencies with violations")           
        end


        _PMSC.info(_LOGGER, "active contingencies: gen $(length(network_active["gen_contingencies"])), branch $(length(network_active["branch_contingencies"])), branchdc $(length(network_active["branchdc_contingencies"]))")   #Update_GM

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
    result_scopf["final"] = result                                                      
    return result_scopf
end
