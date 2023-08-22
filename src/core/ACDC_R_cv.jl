
#v = JuMP.@variable(Upper(model), 0 <= F[n=1:Nodes,w=1:Nodes,s=1:Fares;n>w] <= cap)
function variable_branch_indicator_R(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, relax::Bool=false, report::Bool=true)
    if !relax
        z_branch = _PM.var(pm, nw)[:z_branch] = JuMP.@variable(BilevelJuMP.Upper(pm.model),
            [l in _PM.ids(pm, nw, :branch)], base_name="$(nw)_z_branch",
            binary = true,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :branch, l), "z_branch_start", 1.0)
        )
    else
        z_branch = _PM.var(pm, nw)[:z_branch] = JuMP.@variable(BilevelJuMP.Upper(pm.model),
            [l in _PM.ids(pm, nw, :branch)], base_name="$(nw)_z_branch",
            lower_bound = 0.0,
            upper_bound = 1.0,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :branch, l), "z_branch_start", 1.0)
        )
    end

    report && _PM.sol_component_value(pm, nw, :branch, :br_status, _PM.ids(pm, nw, :branch), z_branch)
end

# c = @constraint(Upper(model),[n=1:Nodes,w=1:Nodes;n>w], sum(F[n,w,s] for s in 1:Fares) <= cap) for cc in c; push!(ctrs, cc); end
function constraint_branch_contingency_limit(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default)
    cmax = _PM.ref(pm, nw, cmax)
    constraint_branch_contingency_limit(pm, nw, cmax)
end
function constraint_branch_contingency_limit(pm::_PM.AbstractPowerModel, n::Int, cmax)
    z_branch = _PM.var(pm, n, :z_branch)
    JuMP.@constraint( Upper(pm.model),  sum( (1 - z_branch[i]) for i in _PM.ids(pm, :branch) ) <= cmax )
end
# lower level v1
function variable_bus_voltage(pm::_PM.AbstractACPModel; kwargs...)
    variable_bus_voltage_angle(pm; kwargs...)
    variable_bus_voltage_magnitude(pm; kwargs...)
end

function variable_bus_voltage_angle(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    va = _PM.var(pm, nw)[:va] = JuMP.@variable(Lower(pm.model),
        [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_va",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :bus, i), "va_start")
    )

    report && _PM.sol_component_value(pm, nw, :bus, :va, _PM.ids(pm, nw, :bus), va)
end

function variable_bus_voltage_magnitude(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    vm = _PM.var(pm, nw)[:vm] = JuMP.@variable(Lower(pm.model),
        [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_vm",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :bus, i), "vm_start", 1.0)
    )

    if bounded
        for (i, bus) in _PM.ref(pm, nw, :bus)
            JuMP.set_lower_bound(vm[i], bus["vmin"])
            JuMP.set_upper_bound(vm[i], bus["vmax"])
        end
    end

    report && _PM.sol_component_value(pm, nw, :bus, :vm, _PM.ids(pm, nw, :bus), vm)
end

# v2
function variable_gen_power(pm::_PM.AbstractPowerModel; kwargs...)
    variable_gen_power_real(pm; kwargs...)
    variable_gen_power_imaginary(pm; kwargs...)
end

function variable_gen_power_real(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pg = _PM.var(pm, nw)[:pg] = JuMP.@variable(Lower(pm.model),
        [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_pg",
        start = _PM.comp_start_value(ref(pm, nw, :gen, i), "pg_start")
    )

    if bounded
        for (i, gen) in _PM.ref(pm, nw, :gen)
            JuMP.set_lower_bound(pg[i], gen["pmin"])
            JuMP.set_upper_bound(pg[i], gen["pmax"])
        end
    end

    report && _PM.sol_component_value(pm, nw, :gen, :pg, _PM.ids(pm, nw, :gen), pg)
end

function variable_gen_power_imaginary(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    qg = _PM.var(pm, nw)[:qg] = JuMP.@variable(Lower(pm.model),
        [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_qg",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "qg_start")
    )

    if bounded
        for (i, gen) in _PM.ref(pm, nw, :gen)
            JuMP.set_lower_bound(qg[i], gen["qmin"])
            JuMP.set_upper_bound(qg[i], gen["qmax"])
        end
    end

    report && _PM.sol_component_value(pm, nw, :gen, :qg, _PM.ids(pm, nw, :gen), qg)
end

# v3
function variable_branch_power(pm::_PM.AbstractPowerModel; kwargs...)
    variable_branch_power_real(pm; kwargs...)
    variable_branch_power_imaginary(pm; kwargs...)
end


function variable_branch_power_real(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    p = _PM.var(pm, nw)[:p] = JuMP.@variable(Lower(pm.model),
        [(l,i,j) in _PM.ref(pm, nw, :arcs)], base_name="$(nw)_p",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branch, l), "p_start")
    )

    if bounded
        flow_lb, flow_ub = _PM.ref_calc_branch_flow_bounds(_PM.ref(pm, nw, :branch), _PM.ref(pm, nw, :bus))

        for arc in _PM.ref(pm, nw, :arcs)
            l,i,j = arc
            if !isinf(flow_lb[l])
                JuMP.set_lower_bound(p[arc], flow_lb[l])
            end
            if !isinf(flow_ub[l])
                JuMP.set_upper_bound(p[arc], flow_ub[l])
            end
        end
    end

    for (l,branch) in _PM.ref(pm, nw, :branch)
        if haskey(branch, "pf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.set_start_value(p[f_idx], branch["pf_start"])
        end
        if haskey(branch, "pt_start")
            t_idx = (l, branch["t_bus"], branch["f_bus"])
            JuMP.set_start_value(p[t_idx], branch["pt_start"])
        end
    end

    report && _PM.sol_component_value_edge(pm, nw, :branch, :pf, :pt, _PM.ref(pm, nw, :arcs_from), _PM.ref(pm, nw, :arcs_to), p)
end

function variable_branch_power_imaginary(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    q =  _PM.var(pm, nw)[:q] = JuMP.@variable(Lower(pm.model),
        [(l,i,j) in  _PM.ref(pm, nw, :arcs)], base_name="$(nw)_q",
        start =  _PM.comp_start_value(ref(pm, nw, :branch, l), "q_start")
    )

    if bounded
        flow_lb, flow_ub =  _PM.ref_calc_branch_flow_bounds( _PM.ref(pm, nw, :branch),  _PM.ref(pm, nw, :bus))

        for arc in  _PM.ref(pm, nw, :arcs)
            l,i,j = arc
            if !isinf(flow_lb[l])
                JuMP.set_lower_bound(q[arc], flow_lb[l])
            end
            if !isinf(flow_ub[l])
                JuMP.set_upper_bound(q[arc], flow_ub[l])
            end
        end
    end

    for (l,branch) in  _PM.ref(pm, nw, :branch)
        if haskey(branch, "qf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.set_start_value(q[f_idx], branch["qf_start"])
        end
        if haskey(branch, "qt_start")
            t_idx = (l, branch["t_bus"], branch["f_bus"])
            JuMP.set_start_value(q[t_idx], branch["qt_start"])
        end
    end

    report &&  _PM.sol_component_value_edge(pm, nw, :branch, :qf, :qt,  _PM.ref(pm, nw, :arcs_from),  _PM.ref(pm, nw, :arcs_to), q)
end

# dcp c1
function constraint_model_voltage(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default)
    constraint_model_voltage(pm, nw)
end

"do nothing, this model does not have complex voltage variables"
function constraint_model_voltage(pm::_PM.AbstractDCPModel, nw)
end
# dcp c2
function constraint_theta_ref(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    constraint_theta_ref(pm, nw, i)
end

"nothing to do, no voltage angle variables"
function constraint_theta_ref(pm::_PM.AbstractDCPModel, n::Int, i::Int)
end
# dcp c3
function constraint_power_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    bus = _PM.ref(pm, nw, :bus, i)
    bus_arcs = _PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = _PM.ref(pm, nw, :bus_arcs_dc, i)
    bus_arcs_sw = _PM.ref(pm, nw, :bus_arcs_sw, i)
    bus_gens = _PM.ref(pm, nw, :bus_gens, i)
    bus_loads = _PM.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PM.ref(pm, nw, :bus_shunts, i)
    bus_storage = _PM.ref(pm, nw, :bus_storage, i)

    bus_pd = Dict(k => _PM.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => _PM.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_power_balance(pm, nw, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
end
function constraint_power_balance(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    p    = get(_PM.var(pm, n),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    pg   = get(_PM.var(pm, n),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    ps   = get(_PM.var(pm, n),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    psw  = get(_PM.var(pm, n),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    p_dc = get(_PM.var(pm, n), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")


    cstr = JuMP.@constraint(Lower(pm.model),
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*1.0^2
    )

    if _IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr
        sol(pm, n, :bus, i)[:lam_kcl_i] = NaN
    end
end
# dcp c4
function constraint_ohms_yt_from(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_ohms_yt_from(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
end
function constraint_ohms_yt_from(pm::_PM.AbstractDCPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr  = _PM.var(pm, n,  :p, f_idx)
    va_fr = _PM.var(pm, n, :va, f_bus)
    va_to = _PM.var(pm, n, :va, t_bus)
    z = _PM.var(pm, n, :z_branch, i)

    JuMP.@constraint(Lower(pm.model), p_fr == -b*(va_fr - va_to) * z)
    # omit reactive constraint
end
# dcp c5
function constraint_ohms_yt_to(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    constraint_ohms_yt_to(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
end
function constraint_ohms_yt_to(pm::_PM.AbstractDCPModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
end
# dcp c6
function constraint_voltage_angle_difference(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    pair = (f_bus, t_bus)
    buspair = _PM.ref(pm, nw, :buspairs, pair)

    if buspair["branch"] == i
        constraint_voltage_angle_difference(pm, nw, f_idx, buspair["angmin"], buspair["angmax"])
    end
end
"nothing to do, no voltage angle variables"
function constraint_voltage_angle_difference(pm::_PM.AbstractDCPModel, n::Int, f_idx, angmin, angmax)
end
# dcp c7
function constraint_thermal_limit_from(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_from(pm, nw, i, f_idx, branch["rate_a"])
    end
end
function constraint_thermal_limit_from(pm::_PM.AbstractDCPModel, n::Int, i, f_idx, rate_a)   
    p_fr = _PM.var(pm, n, :p, f_idx)
    z = _PM.var(pm, n, :z_branch, i)
    if isa(p_fr, JuMP.VariableRef) && JuMP.has_lower_bound(p_fr)
        cstr = JuMP.LowerBoundRef(p_fr)
        JuMP.lower_bound(p_fr) < -rate_a * z && JuMP.set_lower_bound(p_fr, -rate_a * z)
        if JuMP.has_upper_bound(p_fr)
            JuMP.upper_bound(p_fr) > rate_a * z && JuMP.set_upper_bound(p_fr, rate_a * z)
        end
    else
        cstr = JuMP.@constraint(Lower(pm.model), p_fr <= rate_a * z)
    end

    if _IM.report_duals(pm)
        sol(pm, n, :branch, f_idx[1])[:mu_sm_fr] = cstr
    end
end

# dcp c8
function constraint_thermal_limit_to(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_to(pm, nw, i, t_idx, branch["rate_a"])
    end
end
function constraint_thermal_limit_to(pm::_PM.AbstractDCPModel, n::Int, i::Int, t_idx, rate_a)                 #_PM.AbstractDCPModel
    p_to = _PM.var(pm, n, :p, t_idx)
    z = _PM.var(pm, n, :z_branch, i)
    if isa(p_to, JuMP.VariableRef) && JuMP.has_lower_bound(p_to)
        cstr = JuMP.LowerBoundRef(p_to)
        JuMP.lower_bound(p_to) < -rate_a * z && JuMP.set_lower_bound(p_to, -rate_a * z)
        if JuMP.has_upper_bound(p_to)
            JuMP.upper_bound(p_to) >  rate_a * z && JuMP.set_upper_bound(p_to,  rate_a * z)
        end
    else
        cstr = JuMP.@constraint(Lower(pm.model), p_to <= rate_a * z)
    end

    if _IM.report_duals(pm)
        sol(pm, n, :branch, t_idx[1])[:mu_sm_to] = cstr
    end
end