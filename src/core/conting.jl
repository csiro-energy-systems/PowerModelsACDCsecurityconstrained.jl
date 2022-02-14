# function greet()
#     print("hello world")
# end
# function run_c1_scopf_contigency_cuts_GM(ini_file::String, model_type::Type, optimizer; scenario_id::String="", kwargs...)
#     goc_data = _PMSC.parse_c1_case(ini_file, scenario_id=scenario_id)               # parse_c1_case do not need any changes now
#     network = build_c1_pm_model(goc_data)                                        
#     return run_c1_scopf_contigency_cuts_GM(network, model_type, optimizer; kwargs...)
# end

"""
Solves a SCOPF problem by iteratively checking for violated contingencies and 
resolving until a fixed-point is reached
"""
function run_c1_scopf_contigency_cuts_GM(network::Dict{String,<:Any}, model_type::Type, optimizer; max_iter::Int=100, time_limit::Float64=Inf)    #Update_GM
    if _IM.ismultinetwork(network)
        error(_LOGGER, "run_c1_scopf_contigency_cuts can only be used on single networks")
    end

    time_start = time()

    network_base = deepcopy(network)
    network_active = deepcopy(network)

    gen_contingencies = network_base["gen_contingencies"]
    branch_contingencies = network_base["branch_contingencies"]

    network_active["gen_contingencies"] = []
    network_active["branch_contingencies"] = []

    multinetwork = _PMSC.build_c1_scopf_multinetwork(network_active)
    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)        #Update_GM
    result = run_c1_scopf_GM(multinetwork, model_type, optimizer; setting = s)         #Update_GM
    if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        error(_LOGGER, "base-case SCOPF solve failed in run_c1_scopf_contigency_cuts, status $(result["termination_status"])")
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

        contingencies = _PMSC.check_c1_contingency_violations(network_base, contingency_limit=iteration)
        #println(contingencies)

        contingencies_found = 0
        #append!(network_active["gen_contingencies"], contingencies.gen_contingencies)
        for cont in contingencies.gen_contingencies
            if cont in network_active["gen_contingencies"]
                warn(_LOGGER, "generator contingency $(cont.label) is active but not secure")
            else
                push!(network_active["gen_contingencies"], cont)
                contingencies_found += 1
            end
        end

        #append!(network_active["branch_contingencies"], contingencies.branch_contingencies)
        for cont in contingencies.branch_contingencies
            if cont in network_active["branch_contingencies"]
                warn(_LOGGER, "branch contingency $(cont.label) is active but not secure")
            else
                push!(network_active["branch_contingencies"], cont)
                contingencies_found += 1
            end
        end

        if contingencies_found <= 0
            _PMSC.info(_LOGGER, "no new violated contingencies found, scopf fixed-point reached")           #Update_GM
            break
        else
            _PMSC.info(_LOGGER, "found $(contingencies_found) new contingencies with violations")           #Update_GM
        end


        _PMSC.info(_LOGGER, "active contingencies: gen $(length(network_active["gen_contingencies"])), branch $(length(network_active["branch_contingencies"]))")   #Update_GM

        time_solve_start = time()
        multinetwork = _PMSC.build_c1_scopf_multinetwork(network_active)
        result = run_c1_scopf_GM(multinetwork, model_type, optimizer; setting = s)   #Update_GM
        if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
            warn(_LOGGER, "scopf solve failed with status $(result["termination_status"]), terminating fixed-point early")
            break
        end
        # for (nw,nw_sol) in result["solution"]["nw"]
        #     if nw != "0"
        #         println(nw, " ", nw_sol["delta"])
        #     end
        # end
        info(_LOGGER, "objective: $(result["objective"])")
        solution = result["solution"]["nw"]["0"]
        solution["per_unit"] = result["solution"]["per_unit"]

        _PM.update_data!(network_base, solution)
        _PM.update_data!(network_active, solution)

        time_iteration = time() - time_start_iteration
        time_remaining = time_limit - (time() - time_start)
        if time_remaining < time_iteration
            warn(_LOGGER, "insufficent time for next iteration, time remaining $(time_remaining), estimated iteration time $(time_iteration)")
            break
        end
        iteration += 1
    end

    result["solution"] = solution
    result["iterations"] = iteration

    return result
end
