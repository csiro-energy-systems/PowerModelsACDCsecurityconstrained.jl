"""
Solves an SCOPF problem for integrated HVAC and HVDC grid by iteratively checking for
violated contingencies and resolving until a fixed-point is reached.

""" 
function run_scopf_acdc_contingencies(network::Dict{String,<:Any}, model_type_scopf::Type, model_type_filter::Type, run_scopf_prob::Function, optimizer_scopf, optimizer_filter, setting; max_iter::Int=100, time_limit::Float64=Inf)   
    if _IM.ismultinetwork(network)
        Memento.error(_LOGGER, "run_scopf_acdc_contingencies can only be used on single networks")
    end

    time_start = time()

    solution_mp = Dict{String,Any}()
    result_scopf = Dict{String,Any}()

    network_base = deepcopy(network)
    network_active = deepcopy(network)

    network_active["gen_contingencies"] = []
    network_active["branch_contingencies"] = []
    network_active["branchdc_contingencies"] = []
    network_active["convdc_contingencies"] = []

    multinetwork = build_scopf_acdc_multinetwork(network_active)
    result = run_scopf_prob(multinetwork, model_type_scopf, optimizer_scopf; setting = setting)
    result_scopf["base"] = result  
    
    if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        Memento.error(_LOGGER, "base-case scopf solve failed in run_scopf_acdc_contingencies, status $(result["termination_status"])")
    end
    #_PM.print_summary(result["solution"])
    solution = result["solution"]["nw"]["0"]
    solution["per_unit"] = result["solution"]["per_unit"]

    _PM.update_data!(network_base, solution)
    _PM.update_data!(network_active, solution)
    update_data_converter_setpoints!(network_base, solution)
    update_data_converter_setpoints!(network_active, solution)
    update_data_branch_tap_shift!(network_base, solution)
    update_data_branch_tap_shift!(network_active, solution)

    result["iterations"] = 0

    iteration = 1
    contingencies_found = 1
    while contingencies_found > 0
        time_start_iteration = time()
        
        contingencies = check_acdc_contingency_violations(network_base, model_type_filter, optimizer_filter, setting, contingency_limit=iteration)

        contingencies_found = 0
       
        for cont in contingencies.gen_contingencies
            if cont in network_active["gen_contingencies"]
                Memento.warn(_LOGGER, "generator contingency $(cont.label) is active but not secure")
            else
                push!(network_active["gen_contingencies"], cont)
                contingencies_found += 1
            end
        end

        for cont in contingencies.branch_contingencies
            if cont in network_active["branch_contingencies"]
                Memento.warn(_LOGGER, "branch contingency $(cont.label) is active but not secure")
            else
                push!(network_active["branch_contingencies"], cont)
                contingencies_found += 1
            end
        end
        
        for cont in contingencies.branchdc_contingencies
            if cont in network_active["branchdc_contingencies"]
                Memento.warn(_LOGGER, "branchdc contingency $(cont.label) is active but not secure")
            else
                push!(network_active["branchdc_contingencies"], cont)
                contingencies_found += 1
            end
        end

        for cont in contingencies.convdc_contingencies
            if cont in network_active["convdc_contingencies"]
                Memento.warn(_LOGGER, "convdc contingency $(cont.label) is active but not secure")
            else
                push!(network_active["convdc_contingencies"], cont)
                contingencies_found += 1
            end
        end

        if contingencies_found <= 0 
            Memento.info(_LOGGER, "no new violated contingencies found, scopf fixed-point reached")            
            break
        else
            Memento.info(_LOGGER, "found $(contingencies_found) new contingencies with violations")           
        end
        
        Memento.info(_LOGGER, "active contingencies: gen $(length(network_active["gen_contingencies"])), branch $(length(network_active["branch_contingencies"])), branchdc $(length(network_active["branchdc_contingencies"])), convdc $(length(network_active["convdc_contingencies"]))") 
  
        multinetwork = build_scopf_acdc_multinetwork(network_active)
        result = run_scopf_prob(multinetwork, model_type_scopf, optimizer_scopf; setting = setting)
        if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
            Memento.warn(_LOGGER, "scopf solve failed in run_scopf_acdc_contingencies, status $(result["termination_status"]), terminating fixed-point early")
            break
        end
   
        Memento.info(_LOGGER, "objective: $(result["objective"])")
        solution_mp = result
        solution = result["solution"]["nw"]["0"]
        solution["per_unit"] = result["solution"]["per_unit"]

        _PM.update_data!(network_base, solution)
        _PM.update_data!(network_active, solution)
        update_data_converter_setpoints!(network_base, solution)
        update_data_converter_setpoints!(network_active, solution)
        update_data_branch_tap_shift!(network_base, solution)
        update_data_branch_tap_shift!(network_active, solution)

            
        time_iteration = time() - time_start_iteration
        time_remaining = time_limit - (time() - time_start)
        if time_remaining < time_iteration
            Memento.warn(_LOGGER, "insufficent time for next iteration, time remaining $(time_remaining), estimated iteration time $(time_iteration)")
            break
        end
    
        iteration += 1
    end

    result_scopf["final"] = solution_mp 
    result_scopf["iterations"] = iteration
    result_scopf["time"] = time() - time_start                                                     
    return result_scopf
end
