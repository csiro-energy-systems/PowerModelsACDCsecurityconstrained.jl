"""
    constraint_power_balance_ac(pm, i; nw)

Extends PowerModels constraint_power_balance_ac by replacing the static load (pd) with a 
load variable for scheduled loads.
"""
function constraint_power_balance_ac(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    bus = _PM.ref(pm, nw, :bus, i)
    bus_arcs = _PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = _PM.ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = _PM.ref(pm, nw, :bus_gens, i)
    bus_convs_ac = _PM.ref(pm, nw, :bus_convs_ac, i)
    bus_loads = _PM.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PM.ref(pm, nw, :bus_shunts, i)

    pd = Dict{Int64,Any}(k => _PM.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => _PM.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_power_balance_ac(pm, nw, i, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
end

function constraint_power_balance_ac(pm::_PM.AbstractACPModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
    vm = _PM.var(pm, n, :vm, i)
    p = _PM.var(pm, n, :p)
    q = _PM.var(pm, n, :q)
    pg = _PM.var(pm, n, :pg)
    qg = _PM.var(pm, n, :qg)
    pd_vars = _PM.var(pm, n, :pd)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n, :qconv_tf_fr)

    for l in keys(pd_vars)
        if l[1] in bus_loads
            pd[l[1]] = pd_vars[l[1]]
        end
    end

    cstr_p = JuMP.@NLconstraint(pm.model, sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac) == sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts) * vm^2)
    cstr_q = JuMP.@NLconstraint(pm.model, sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac) == sum(qg[g] for g in bus_gens) - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts) * vm^2)

    if _IM.report_duals(pm)
        _PM.sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        _PM.sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end

function constraint_power_balance_ac(pm::_PM.AbstractDCPModel, n::Int,  i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
    p = _PM.var(pm, n, :p)
    pg = _PM.var(pm, n, :pg)
    pd_vars = _PM.var(pm, n, :pd)
    pconv_ac = _PM.var(pm, n, :pconv_ac)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    v = 1

    for l in keys(pd_vars)
        if l[1] in bus_loads
            pd[l[1]] = pd_vars[l[1]]
        end
    end

    cstr_p = JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)

    if _IM.report_duals(pm)
        _PM.sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
    end
end

"""
    constraint_fcas_max_available(pm, service, nw)

Simple constraint to ensure the calculated fcas for a generator/load is below the max fcas availability
"""
function constraint_fcas_max_available(pm::_PM.AbstractPowerModel, service::FCASService, nw::Int=_PM.nw_id_default)
    for (i, gen) in get_fcas_participants(_PM.ref(pm, nw, :gen), service)
        fcas = gen["fcas"][service.id]
        p_fcas = _PM.var(pm, nw, Symbol("gen_$(fcas_name(service))"), i)

        JuMP.@constraint(pm.model, p_fcas <= fcas["amax"])
    end

    for (i, load) in get_fcas_participants(_PM.ref(pm, nw, :load), service)
        fcas = load["fcas"][service.id]
        p_fcas = _PM.var(pm, nw, Symbol("load_$(fcas_name(service))"), i)

        JuMP.@constraint(pm.model, p_fcas <= fcas["amax"])
    end
end

"""
    constraint_fcas_energy_regulating_capacity(pm, service, nw)

Ensures that the combined energy and regulating fcas values are contained within the fcas trapezium
"""
function constraint_fcas_energy_regulating_capacity(pm::_PM.AbstractPowerModel, service::FCASRegulatingService, nw::Int=_PM.nw_id_default)
    for (i, gen) in get_fcas_participants(_PM.ref(pm, nw, :gen), service)
        pg = _PM.var(pm, nw, :pg, i)

        fcas = gen["fcas"][service.id]
        p_fcas = _PM.var(pm, nw, Symbol("gen_$(fcas_name(service))"), i)

        lower_slope = fcas["lower_slope"]
        JuMP.@constraint(pm.model, pg - (lower_slope * p_fcas) >= fcas["emin"])

        upper_slope = fcas["upper_slope"]
        JuMP.@constraint(pm.model, pg + (upper_slope * p_fcas) <= fcas["emax"])
    end

    for (i, load) in get_fcas_participants(_PM.ref(pm, nw, :load), service)
        pd = _PM.var(pm, nw, :pd, i)

        fcas = load["fcas"][service.id]
        p_fcas = _PM.var(pm, nw, Symbol("load_$(fcas_name(service))"), i)

        lower_slope = fcas["lower_slope"]
        JuMP.@constraint(pm.model, pd - (lower_slope * p_fcas) >= fcas["emin"])

        upper_slope = fcas["upper_slope"]
        JuMP.@constraint(pm.model, pd + (upper_slope * p_fcas) <= fcas["emax"])

    end
end

"do nothing, not required for contingency FCAS services"
function constraint_fcas_energy_regulating_capacity(pm::_PM.AbstractPowerModel, service::FCASContingencyService, nw::Int=_PM.nw_id_default)
end

"do nothing, not required for regulating FCAS services"
function constraint_fcas_joint_capacity(pm::_PM.AbstractPowerModel, service::FCASRegulatingService, nw::Int=_PM.nw_id_default)
end

"""
    constraint_fcas_joint_capacity(pm, service, nw)

Ensures that the combined energy, regulating fcas and contingency fcas values are contained within the fcas trapezium
"""
function constraint_fcas_joint_capacity(pm::_PM.AbstractPowerModel, service::FCASContingencyService, nw::Int=_PM.nw_id_default)
    service_key = service.id

    for (i, gen) in get_fcas_participants(_PM.ref(pm, nw, :gen), service)
        pg = _PM.var(pm, nw, :pg, i)

        fcas = gen["fcas"][service_key]

        lower_regulating_enabled = fcas_enabled(fcas_services["LOWERREG"], gen)
        raise_regulating_enabled = fcas_enabled(fcas_services["RAISEREG"], gen)

        p_fcas = _PM.var(pm, nw, Symbol("gen_$(fcas_name(service))"), i)
        p_fcas_lreg = lower_regulating_enabled ? _PM.var(pm, nw, Symbol("gen_LReg"), i) : nothing
        p_fcas_rreg = raise_regulating_enabled ? _PM.var(pm, nw, Symbol("gen_RReg"), i) : nothing

        lower_slope = fcas["lower_slope"]
        if lower_regulating_enabled
            JuMP.@constraint(pm.model, pg - (lower_slope * p_fcas) - p_fcas_lreg >= fcas["emin"])
        else
            JuMP.@constraint(pm.model, pg - (lower_slope * p_fcas) >= fcas["emin"])
        end

        upper_slope = fcas["upper_slope"]
        if raise_regulating_enabled
            JuMP.@constraint(pm.model, pg + (upper_slope * p_fcas) + p_fcas_rreg <= fcas["emax"])
        else
            JuMP.@constraint(pm.model, pg + (upper_slope * p_fcas) <= fcas["emax"])
        end
    end

    for (i, load) in get_fcas_participants(_PM.ref(pm, nw, :load), service)
        pd = _PM.var(pm, nw, :pd, i)

        fcas = load["fcas"][service_key]
        lower_slope = fcas["lower_slope"]
        upper_slope = fcas["upper_slope"]

        p_fcas = _PM.var(pm, nw, Symbol("load_$(fcas_name(service))"), i)

        if fcas_enabled(fcas_services["LOWERREG"], load)
            p_fcas_lreg = _PM.var(pm, nw, Symbol("load_LReg"), i)
            JuMP.@constraint(pm.model, pd - (lower_slope * p_fcas) - p_fcas_lreg >= fcas["emin"])
        else
            JuMP.@constraint(pm.model, pd - (lower_slope * p_fcas) >= fcas["emin"])
        end

        if fcas_enabled(fcas_services["RAISEREG"], load)
            p_fcas_rreg = _PM.var(pm, nw, Symbol("load_RReg"), i)
            JuMP.@constraint(pm.model, pd + (upper_slope * p_fcas) + p_fcas_rreg <= fcas["emax"])
        else
            JuMP.@constraint(pm.model, pd + (upper_slope * p_fcas) <= fcas["emax"])
        end
    end
end

"""
    constraint_fcas_target(pm, service, nw)

Creates an equality constraint that sets an fcas service target
"""
function constraint_fcas_target(pm::_PM.AbstractPowerModel, service::FCASService, nw::Int=_PM.nw_id_default)
    fcas_targets = _PM.ref(pm, nw, :fcas_target)
    target = filter(x -> haskey(x, "service") && x["service"] == service.id, fcas_targets)

    if length(target) > 0
        fcas_target = first(target)

        JuMP.@constraint(pm.model,
            sum(_PM.var(pm, nw, Symbol("gen_$(fcas_name(service))"), i) for i in keys(get_fcas_participants(_PM.ref(pm, nw, :gen), service))) +
            sum(_PM.var(pm, nw, Symbol("load_$(fcas_name(service))"), i) for i in keys(get_fcas_participants(_PM.ref(pm, nw, :load), service)))
            ==
            fcas_target["p"])
    end
end