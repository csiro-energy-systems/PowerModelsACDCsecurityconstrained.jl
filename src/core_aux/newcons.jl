""
function constraint_c1_power_balance_shunt_dispatch(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_storage = ref(pm, nw, :bus_storage, i)

    bus_shunts_const = ref(pm, :bus_shunts_const, i)
    bus_shunts_var = ref(pm, :bus_shunts_var, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs_const = Dict(k => ref(pm, :shunt, k, "gs") for k in bus_shunts_const)
    bus_bs_const = Dict(k => ref(pm, :shunt, k, "bs") for k in bus_shunts_const)

    constraint_c1_power_balance_shunt_dispatch(pm, nw, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_shunts_var, bus_pd, bus_qd, bus_gs_const, bus_bs_const)
end

""
function constraint_c1_power_balance_shunt_dispatch_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_storage = ref(pm, nw, :bus_storage, i)

    bus_shunts_const = ref(pm, :bus_shunts_const, i)
    bus_shunts_var = ref(pm, :bus_shunts_var, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs_const = Dict(k => ref(pm, :shunt, k, "gs") for k in bus_shunts_const)
    bus_bs_const = Dict(k => ref(pm, :shunt, k, "bs") for k in bus_shunts_const)

    constraint_c1_power_balance_shunt_dispatch_soft(pm, nw, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_shunts_var, bus_pd, bus_qd, bus_gs_const, bus_bs_const)
end
""
function constraint_c1_power_balance_shunt_dispatch(pm::_PM.AbstractACPModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_shunts_var, bus_pd, bus_qd, bus_gs_const, bus_bs_const)
    vm   = var(pm, n, :vm, i)
    p    = get(var(pm, n),    :p, Dict()); _PM._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n),    :q, Dict()); _PM._check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n),   :pg, Dict()); _PM._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n),   :qg, Dict()); _PM._check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n),   :ps, Dict()); _PM._check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n),   :qs, Dict()); _PM._check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n),  :psw, Dict()); _PM._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n),  :qsw, Dict()); _PM._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n), :p_dc, Dict()); _PM._check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n), :q_dc, Dict()); _PM._check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")

    bs = get(var(pm, n), :bs, Dict()); _PM._check_var_keys(bs, bus_shunts_var, "reactive power", "shunt")

    cstr_p = JuMP.@NLconstraint(pm.model, 0 == - sum(p[a] for a in bus_arcs) + sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs_const))*vm^2)
    cstr_q = JuMP.@NLconstraint(pm.model, 0 == - sum(q[a] for a in bus_arcs) + sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs_const))*vm^2 + sum(bs[s]*vm^2 for s in bus_shunts_var))

    if _IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end

""
function constraint_c1_power_balance_shunt_dispatch_soft(pm::_PM.AbstractACPModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_storage, bus_gens, bus_shunts_var, bus_pd, bus_qd, bus_gs_const, bus_bs_const)
    vm   = var(pm, n, :vm, i)
    p    = get(var(pm, n),    :p, Dict()); _PM._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n),    :q, Dict()); _PM._check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n),   :pg, Dict()); _PM._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n),   :qg, Dict()); _PM._check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n),   :ps, Dict()); _PM._check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n),   :qs, Dict()); _PM._check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n),  :psw, Dict()); _PM._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n),  :qsw, Dict()); _PM._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n), :p_dc, Dict()); _PM._check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n), :q_dc, Dict()); _PM._check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")

    bs = get(var(pm, n), :bs, Dict()); _PM._check_var_keys(bs, bus_shunts_var, "reactive power", "shunt")

    p_delta_abs = var(pm, n, :p_delta_abs, i)
    q_delta_abs = var(pm, n, :q_delta_abs, i)

    p_delta = @NLexpression(pm.model, - sum(p[a] for a in bus_arcs) + sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs_const))*vm^2)
    q_delta = @NLexpression(pm.model, - sum(q[a] for a in bus_arcs) + sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs_const))*vm^2 + sum(bs[s]*vm^2 for s in bus_shunts_var))

    @NLconstraint(pm.model,  p_delta_abs >= p_delta)
    @NLconstraint(pm.model, -p_delta_abs <= p_delta)

    @NLconstraint(pm.model,  q_delta_abs >= q_delta)
    @NLconstraint(pm.model, -q_delta_abs <= q_delta)
end

function constraint_c1_branch_contingency_ptdf_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    cut = ref(pm, :branch_flow_cuts, i)
    branch = ref(pm, nw, :branch, cut.branch_id)

    if haskey(branch, "rate_c")
        constraint_c1_branch_contingency_ptdf_thermal_limit_from_soft(pm, nw, i, cut.bus_injection, branch["rate_c"])
    end
end

""
function constraint_c1_branch_contingency_ptdf_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    cut = ref(pm, :branch_flow_cuts, i)
    branch = ref(pm, nw, :branch, cut.branch_id)

    if haskey(branch, "rate_c")
        constraint_c1_branch_contingency_ptdf_thermal_limit_to_soft(pm, nw, i, cut.bus_injection, branch["rate_c"])
    end
end

""
function constraint_c1_branch_contingency_ptdf_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_map, rate)
    bus_injection = var(pm, :bus_pg)
    bus_withdrawal = var(pm, :bus_wdp)

    JuMP.@constraint(pm.model, sum(weight*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight) in cut_map) <= rate + var(pm, :branch_cont_flow_vio, i))
end


""
function constraint_c1_branch_contingency_ptdf_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_map, rate)
    bus_injection = var(pm, :bus_pg)
    bus_withdrawal = var(pm, :bus_wdp)

    JuMP.@constraint(pm.model, -sum(weight*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight) in cut_map) <= rate + var(pm, :branch_cont_flow_vio, i))
end

