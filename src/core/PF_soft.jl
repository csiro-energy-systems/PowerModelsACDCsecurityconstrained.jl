"""
An SCOPF formulation conforming to the ARPA-e GOC Challenge 1 specification.
A DC power flow approximation is used. Power balance and line flow constraints
are strictly enforced in the first stage.  Contingency branch flow constraints
are enforced by PTDF cuts and penalized based on a conservative linear
approximation of the formulation's specification.

This formulation is used in conjunction with the contingency filters that
generate PTDF cuts.
"""
function run_c1_scopf_cuts_soft_GM(data, model_constructor, solver; kwargs...)
    return _PM.run_model(data, model_constructor, solver, build_c1_scopf_cuts_soft_GM; ref_extensions=[_PMSC.ref_c1!], kwargs...) #ref_extensions = [_PMACDC.add_ref_dcgrid!],
end

""
function build_c1_scopf_cuts_soft_GM(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)

    _PMSC.variable_c1_shunt_admittance_imaginary(pm)

    _PMSC.variable_c1_branch_contigency_power_violation(pm)
    _PMSC.variable_c1_gen_contigency_power_violation(pm)
    _PMSC.variable_c1_gen_contigency_capacity_violation(pm)

    for i in _PMSC.ids(pm, :bus)
        _PMSC.expression_c1_bus_generation(pm, i)
        _PMSC.expression_c1_bus_withdrawal(pm, i)
    end


    _PM.constraint_model_voltage(pm)

    for i in _PMSC.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PMSC.ids(pm, :bus)
        _PMSC.constraint_c1_power_balance_shunt_dispatch(pm, i)
    end

    for i in _PMSC.ids(pm, :branch)
        _PMSC.constraint_goc_ohms_yt_from(pm, i)
        _PM.constraint_ohms_yt_to(pm, i)

        _PM.constraint_voltage_angle_difference(pm, i)

        _PM.constraint_thermal_limit_from(pm, i)
        _PM.constraint_thermal_limit_to(pm, i)
    end


    for (i,cut) in enumerate(_PMSC.ref(pm, :branch_flow_cuts))
        _PMSC.constraint_c1_branch_contingency_ptdf_thermal_limit_from_soft(pm, i)
        _PMSC.constraint_c1_branch_contingency_ptdf_thermal_limit_to_soft(pm, i)
    end

    bus_withdrawal = _PMSC.var(pm, :bus_wdp)

    for (i,cut) in enumerate(_PMSC.ref(pm, :gen_flow_cuts))
        branch = _PMSC.ref(pm, :branch, cut.branch_id)
        gen = _PMSC.ref(pm, :gen, cut.gen_id)
        gen_bus = _PMSC.ref(pm, :bus, gen["gen_bus"])
        gen_set = _PMSC.ref(pm, :area_gens)[gen_bus["area"]]
        alpha_total = sum(gen["alpha"] for (i,gen) in _PMSC.ref(pm, :gen) if gen["index"] != cut.gen_id && i in gen_set)

        cont_bus_injection = Dict{Int,Any}()
        for (i, bus) in _PMSC.ref(pm, :bus)
            inj = 0.0
            for g in _PMSC.ref(pm, :bus_gens, i)
                if g != cut.gen_id
                    if g in gen_set
                        inj += _PMSC.var(pm, :pg, g) + gen["alpha"]*_PMSC.var(pm, :pg, cut.gen_id)/alpha_total
                    else
                        inj += _PMSC.var(pm, :pg, g)
                    end
                end
            end
            cont_bus_injection[i] = inj
        end

        #rate = branch["rate_a"]
        rate = branch["rate_c"]
        JuMP.@constraint(pm.model,  sum( weight*(cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight) in cut.bus_injection) <= rate + _PMSC.var(pm, :gen_cont_flow_vio, i))
        JuMP.@constraint(pm.model, -sum( weight*(cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight) in cut.bus_injection) <= rate + _PMSC.var(pm, :gen_cont_flow_vio, i))
    end

    for (i,gen_cont) in enumerate(_PMSC.ref(pm, :gen_contingencies))
        #println(gen_cont)
        gen = _PMSC.ref(pm, :gen, gen_cont.idx)
        gen_bus = _PMSC.ref(pm, :bus, gen["gen_bus"])
        gen_set = _PMSC.ref(pm, :area_gens)[gen_bus["area"]]
        response_gens = Dict(g => _PMSC.ref(pm, :gen, g) for g in gen_set if g != gen_cont.idx)

        # factor of 1.2 accounts for losses in a DC model
        #@constraint(pm.model, sum(gen["pmax"] - var(pm, :pg, g) for (g,gen) in response_gens) >= 1.2*var(pm, :pg, gen_cont.idx))
        JuMP.@constraint(pm.model, _PMSC.var(pm, :gen_cont_cap_vio, i) + sum(gen["pmax"] - _PMSC.var(pm, :pg, g) for (g,gen) in response_gens) >= _PMSC.var(pm, :pg, gen_cont.idx))
        #@constraint(pm.model, sum(gen["pmin"] - var(pm, :pg, g) for (g,gen) in response_gens) <= var(pm, :pg, gen_cont.idx))
    end

    ##### Setup Objective #####
    _PM.objective_variable_pg_cost(pm)
    # explicit network id needed because of conductor-less
    pg_cost = _PMSC.var(pm, :pg_cost)
    branch_cont_flow_vio = _PMSC.var(pm, :branch_cont_flow_vio)
    gen_cont_flow_vio = _PMSC.var(pm, :gen_cont_flow_vio)
    gen_cont_cap_vio = _PMSC.var(pm, :gen_cont_cap_vio)

    JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i,gen) in _PMSC.ref(pm, :gen) ) +
        sum( 5e5*branch_cont_flow_vio[i] for i in 1:length(_PMSC.ref(pm, :branch_flow_cuts)) ) +
        sum( 5e5*gen_cont_flow_vio[i] for i in 1:length(_PMSC.ref(pm, :gen_flow_cuts)) ) + 
        sum( 5e5*gen_cont_cap_vio[i] for i in 1:length(_PMSC.ref(pm, :gen_contingencies)) )
    )
end