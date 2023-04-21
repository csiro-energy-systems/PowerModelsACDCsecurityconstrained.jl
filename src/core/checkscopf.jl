function run_c1_scopf_contigency_cuts_check(ini_file::String, model_type::Type, optimizer; scenario_id::String="", kwargs...)
    goc_data = _PMSC.parse_c1_case(ini_file, scenario_id=scenario_id)
    network = _PMSC.build_c1_pm_model(goc_data)
    return run_c1_scopf_contigency_cuts_check(network, model_type, optimizer; kwargs...)
end

"""
Solves a SCOPF problem by iteratively checking for violated contingencies and
resolving until a fixed-point is reached
"""
function run_c1_scopf_contigency_cuts_check(network::Dict{String,<:Any}, model_type::Type, optimizer; max_iter::Int=100, time_limit::Float64=Inf)
    if _IM.ismultinetwork(network)
        error(_LOGGER, "run_c1_scopf_contigency_cuts can only be used on single networks")
    end

    time_start = time()
    result_base_case = Dict()

    network_base = deepcopy(network)
    network_active = deepcopy(network)

    gen_contingencies = network_base["gen_contingencies"]
    branch_contingencies = network_base["branch_contingencies"]

    network_active["gen_contingencies"] = []
    network_active["branch_contingencies"] = []

    multinetwork = _PMSC.build_c1_scopf_multinetwork(network_active)

    result = run_c1_scopf_check(multinetwork, model_type, optimizer)
    if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        error(_LOGGER, "base-case SCOPF solve failed in run_c1_scopf_contigency_cuts, status $(result["termination_status"])")
    end
    #_PM.print_summary(result["solution"])
    solution = result["solution"]["nw"]["0"]
    solution["per_unit"] = result["solution"]["per_unit"]

    _PM.update_data!(network_base, solution)
    _PM.update_data!(network_active, solution)
    result_base_case["solution"] = solution
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
                _PMSC.warn(_LOGGER, "generator contingency $(cont.label) is active but not secure")
            else
                push!(network_active["gen_contingencies"], cont)
                contingencies_found += 1
            end
        end

        #append!(network_active["branch_contingencies"], contingencies.branch_contingencies)
        for cont in contingencies.branch_contingencies
            if cont in network_active["branch_contingencies"]
                _PMSC.warn(_LOGGER, "branch contingency $(cont.label) is active but not secure")
            else
                push!(network_active["branch_contingencies"], cont)
                contingencies_found += 1
            end
        end

        if contingencies_found <= 0
            _PMSC.info(_LOGGER, "no new violated contingencies found, scopf fixed-point reached")
            break
        else
            _PMSC.info(_LOGGER, "found $(contingencies_found) new contingencies with violations")
        end


        _PMSC.info(_LOGGER, "active contingencies: gen $(length(network_active["gen_contingencies"])), branch $(length(network_active["branch_contingencies"]))")

        time_solve_start = time()
        multinetwork = _PMSC.build_c1_scopf_multinetwork(network_active)
        result = run_c1_scopf_check(multinetwork, model_type, optimizer)
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
    result["base_case"] = result_base_case
    return result
end




""
function run_c1_scopf_check(file, model_constructor, solver; kwargs...)
    return _PM.run_model(file, model_constructor, solver, build_c1_scopf_check; multinetwork=true, kwargs...)
end

# enables support for v[1], required for objective_variable_pg_cost when pg is an expression
# Base.getindex(v::JuMP.GenericAffExpr, i::Int64) = v

""
function build_c1_scopf_check(pm::_PM.AbstractPowerModel)
    # base-case network id is 0

    _PM.variable_bus_voltage(pm, nw=0)
    _PM.variable_gen_power(pm, nw=0)
    _PM.variable_branch_power(pm, nw=0)

    _PM.constraint_model_voltage(pm, nw=0)

    for i in _PMSC.ids(pm, :ref_buses, nw=0)
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in _PMSC.ids(pm, :bus, nw=0)
        _PM.constraint_power_balance(pm, i, nw=0)
    end

    for i in _PMSC.ids(pm, :branch, nw=0)
        _PM.constraint_ohms_yt_from(pm, i, nw=0)
        _PM.constraint_ohms_yt_to(pm, i, nw=0)

        _PM.constraint_voltage_angle_difference(pm, i, nw=0)

        _PM.constraint_thermal_limit_from(pm, i, nw=0)
        _PM.constraint_thermal_limit_to(pm, i, nw=0)
    end


    contigency_ids = [id for id in _PMSC.nw_ids(pm) if id != 0]
    for nw in contigency_ids
        _PM.variable_bus_voltage(pm, nw=nw, bounded=false)
        _PM.variable_gen_power(pm, nw=nw, bounded=false)
        _PM.variable_branch_power(pm, nw=nw)

        _PMSC.variable_c1_response_delta(pm, nw=nw)

        variable_c1_voltage_response(pm, nw=nw)    # check

        _PM.constraint_model_voltage(pm, nw=nw)

        for i in _PMSC.ids(pm, :ref_buses, nw=nw)
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = _PM.ref(pm, :gen_buses, nw=nw)
        bus_gens = _PM.ref(pm, :bus_gens, nw=nw)
        
        for i in _PM.ids(pm, :bus, nw=nw)
            _PM.constraint_power_balance(pm, i, nw=nw)

            # if a bus has active generators, fix the voltage magnitude to the base case
            if i in gen_buses                                                                       # TO DO if response generator is ousted as a contingency
                # _PMSC.constraint_c1_voltage_magnitude_link(pm, i, nw_1=0, nw_2=nw)
                constraint_c1_gen_power_reactive_response_ap(pm, i, nw_1=0, nw_2=nw)
            end
        end


        response_gens = _PM.ref(pm, :response_gens, nw=nw)
        for (i,gen) in _PM.ref(pm, :gen, nw=nw)
            pg_base = _PM.var(pm, :pg, i, nw=0)

            # setup the linear response function or fix value to base case
            if i in response_gens 
                # _PMSC.constraint_c1_gen_power_real_response(pm, i, nw_1=0, nw_2=nw)
                constraint_c1_gen_power_real_response_ap(pm, i, nw_1=0, nw_2=nw)
            else
                _PMSC.constraint_c1_gen_power_real_link(pm, i, nw_1=0, nw_2=nw)
            end
        end


        for i in _PMSC.ids(pm, :branch, nw=nw)
            _PM.constraint_ohms_yt_from(pm, i, nw=nw)
            _PM.constraint_ohms_yt_to(pm, i, nw=nw)

            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)

            _PM.constraint_thermal_limit_from(pm, i, nw=nw)
            _PM.constraint_thermal_limit_to(pm, i, nw=nw)
        end
    end


    ##### Setup Objective #####
    _PMSC.objective_c1_variable_pg_cost_basecase(pm)

    # explicit network id needed because of conductor-less
    pg_cost = _PMSC.var(pm, 0, :pg_cost)

    JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i,gen) in _PMSC.ref(pm, 0, :gen) )
    )
end