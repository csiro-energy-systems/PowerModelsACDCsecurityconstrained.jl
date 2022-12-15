
# Constraint AC Powre Balance Template
function constraint_power_balance_ac(pm::AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    bus_arcs   = _PM.ref(pm, nw, :bus_arcs, i)
    bus_gens   = _PM.ref(pm, nw, :bus_gens, i)
    bus_loads  = _PM.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PM.ref(pm, nw, :bus_shunts, i)
    bus_arcs_dc = _PM.ref(pm, nw, :bus_arcs_dc, i)
    bus_convs_ac = _PM.ref(pm, nw, :bus_convs_ac, i)

    bus_pd = Dict(k => _PM.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => _PM.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_power_balance_ac(pm, nw, i, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, bus_pd, bus_qd, bus_gs, bus_bs)
end

# Constraint AC Powre Balance
function constraint_power_balance_ac(pm::AbstractACRModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, bus_pd, bus_qd, bus_gs, bus_bs)
    vr = _PM.var(pm, n, :vr, i)
    vi = _PM.var(pm, n, :vi, i)

    p    = _PM.get(_PM.var(pm, n),    :p, Dict()); _PM._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = _PM.get(_PM.var(pm, n),    :q, Dict()); _PM._check_var_keys(q, bus_arcs, "reactive power", "branch")
    
    pg   = _PM.get(_PM.var(pm, n),   :pg, Dict()); _PM._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = _PM.get(_PM.var(pm, n),   :qg, Dict()); _PM._check_var_keys(qg, bus_gens, "reactive power", "generator")

    pconv_grid_ac = _PM.var(pm, n,  :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n,  :qconv_tf_fr)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*(vr^2 + vi^2))
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac) == sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs))*(vr^2 + vi^2))
end




# Constraint DC Powre Balance Template
function constraint_power_balance_dc(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    bus_arcs_dcgrid = _PM.ref(pm, nw, :bus_arcs_dcgrid, i)
    bus_convs_dc = _PM.ref(pm, nw, :bus_convs_dc, i)
    pd = _PM.ref(pm, nw, :busdc, i)["Pdc"]
    constraint_power_balance_dc(pm, nw, i, bus_arcs_dcgrid, bus_convs_dc, pd)
end

# Constraint DC Powre Balance
function constraint_power_balance_dc(pm::_PM.AbstractPowerModel, n::Int, i::Int, bus_arcs_dcgrid, bus_convs_dc, pd)
    p_dcgrid = _PM.var(pm, n, :p_dcgrid)
    pconv_dc = _PM.var(pm, n, :pconv_dc)

    JuMP.@constraint(pm.model, sum(p_dcgrid[a] for a in bus_arcs_dcgrid) + sum(pconv_dc[c] for c in bus_convs_dc) == (-pd))
end

# Constraint DC Powre Balance
function constraint_ohms_dc_branch(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branchdc, i)
    f_bus = branch["fbusdc"]
    t_bus = branch["tbusdc"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p = _PM.ref(pm, nw, :dcpol)

    constraint_ohms_dc_branch(pm, nw, f_bus, t_bus, f_idx, t_idx, branch["r"], p)
end


    function constraint_ohms_dc_branch(pm::_PM.AbstractACPModel, n::Int,  f_bus, t_bus, f_idx, t_idx, r, p)
        p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
        p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
        vmdc_fr = _PM.var(pm, n,  :vdcm, f_bus)
        vmdc_to = _PM.var(pm, n,  :vdcm, t_bus)
    
        if r == 0
            JuMP.@constraint(pm.model, p_dc_fr + p_dc_to == 0)
        else
            g = 1 / r
            JuMP.@NLconstraint(pm.model, p_dc_fr == p * g * vmdc_fr * (vmdc_fr - vmdc_to))
            JuMP.@NLconstraint(pm.model, p_dc_to == p * g * vmdc_to * (vmdc_to - vmdc_fr))
        end
    end


    function constraint_ohms_dc_branch(pm::_PM.AbstractWRModels, n::Int,  f_bus, t_bus, f_idx, t_idx, r, p)
        p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)
        p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)
        wdc_fr = _PM.var(pm, n, :wdc, f_bus)
        wdc_to = _PM.var(pm, n, :wdc, t_bus)
        wdc_frto = _PM.var(pm, n, :wdcr, (f_bus, t_bus))
    
        if r == 0
            JuMP.@constraint(pm.model, p_dc_fr + p_dc_to == 0)
        else
            g = 1 / r
            JuMP.@constraint(pm.model, p_dc_fr == p * g *  (wdc_fr - wdc_frto))
            JuMP.@constraint(pm.model, p_dc_to == p * g *  (wdc_to - wdc_frto))
        end
    end

function constraint_gp_power_branch_to(pm::AbstractPowerModel, i::Int; nw::Int=nw_id_default)
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

    T2  = pm.data["T2"]
    T3  = pm.data["T3"]

    constraint_gp_power_branch_to(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, T2, T3)
end

function constraint_gp_power_branch_from(pm::AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    
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
    
    T2  = pm.data["T2"]
    T3  = pm.data["T3"]

    constraint_gp_power_branch_from(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, T2, T3)
end

function constraint_gp_power_branch_to(pm::AbstractACRModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, T2, T3)
    p_to = _PM.var(pm, n, :p, t_idx)
    q_to = _PM.var(pm, n, :q, t_idx)  
    
    vr_fr = Dict(nw => _PM.var(pm, nw, :vr, f_bus) for nw in _PM.nw_ids(pm))
    vr_to = Dict(nw => _PM.var(pm, nw, :vr, t_bus) for nw in _PM.nw_ids(pm))
    vi_fr = Dict(nw => _PM.var(pm, nw, :vi, f_bus) for nw in _PM.nw_ids(pm))
    vi_to = Dict(nw => _PM.var(pm, nw, :vi, t_bus) for nw in _PM.nw_ids(pm))
   
    JuMP.@constraint(pm.model,  p_to * T2.get([n-1,n-1])
                                ==
                                sum(T3.get([n1-1,n2-1,n-1]) *
                                    ((g + g_to) * (vr_to[n1] * vr_to[n2] + vi_to[n1] * vi_to[n2]) + 
                                     (-g * tr - b * ti) / tm^2 * (vr_fr[n1] * vr_to[n2] + vi_fr[n1] * vi_to[n2]) + 
                                     (-b * tr + g * ti) / tm^2 * (-(vi_fr[n1] * vr_to[n2] - vr_fr[n1] * vi_to[n2]))
                                    )
                                    for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm))
                    )
   
    JuMP.@constraint(pm.model,  q_to * T2.get([n-1,n-1])
                                ==
                                sum(T3.get([n1-1,n2-1,n-1]) *
                                    (-(b + b_to) * (vr_to[n1] * vr_to[n2] + vi_to[n1] * vi_to[n2]) - 
                                     (-b * tr + g * ti) / tm^2 * (vr_fr[n1] * vr_to[n2] + vi_fr[n1] * vi_to[n2]) + 
                                     (-g * tr - b * ti) / tm^2 * (-(vi_fr[n1] * vr_to[n2] - vr_fr[n1] * vi_to[n2]))
                                    )
                                    for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm))
                    )
end



""
function constraint_gp_power_branch_from(pm::AbstractACRModel, n::Int,f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, T2, T3)
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)

    vr_fr = Dict(nw => _PM.var(pm, nw, :vr, f_bus) for nw in _PM.nw_ids(pm))
    vr_to = Dict(nw => _PM.var(pm, nw, :vr, t_bus) for nw in _PM.nw_ids(pm))
    vi_fr = Dict(nw => _PM.var(pm, nw, :vi, f_bus) for nw in _PM.nw_ids(pm))
    vi_to = Dict(nw => _PM.var(pm, nw, :vi, t_bus) for nw in _PM.nw_ids(pm))

    JuMP.@constraint(pm.model,  p_fr * T2.get([n-1,n-1])
                                ==
                                sum(T3.get([n1-1,n2-1,n-1]) *
                                    ((g + g_fr) / tm^2 * (vr_fr[n1] * vr_fr[n2] + vi_fr[n1] * vi_fr[n2]) + 
                                     (-g * tr + b * ti) / tm^2 * (vr_fr[n1] * vr_to[n2] + vi_fr[n1] * vi_to[n2]) + 
                                     (-b * tr - g * ti) / tm^2 * (vi_fr[n1] * vr_to[n2] - vr_fr[n1] * vi_to[n2])
                                    )
                                for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm))
                    )

    JuMP.@constraint(pm.model,  q_fr * T2.get([n-1,n-1])
                                ==
                                sum(T3.get([n1-1,n2-1,n-1]) *
                                    (-(b + b_fr) / tm^2 * (vr_fr[n1] * vr_fr[n2] + vi_fr[n1] * vi_fr[n2]) - 
                                     (-b * tr - g * ti) / tm^2 * (vr_fr[n1] * vr_to[n2] + vi_fr[n1] * vi_to[n2]) + 
                                     (-g * tr + b * ti) / tm^2 * (vi_fr[n1] * vr_to[n2] - vr_fr[n1] * vi_to[n2]) 
                                    )
                                for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm))
                    )
end


# dcbranch current ####################################################################################################################################################
function variable_branch_current(pm::AbstractACRModel; nw::Int=nw_id_default, aux::Bool=true, bounded::Bool=true, report::Bool=true, aux_fix::Bool=false, kwargs...)
    variable_branch_voltage_drop_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_branch_voltage_drop_img(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    
    if aux
        variable_branch_series_current_squared(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
    else
        if nw == nw_id_default
            variable_branch_series_current_expectation(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
            variable_branch_series_current_variance(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
        end 
    end
end
# branch voltage drop
"variable: `vbdr[l,i,j]` for `(l,i,j)` in `arcs_from`"
function variable_branch_voltage_drop_real(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    vbdr = _PM.var(pm, nw)[:vbdr] = JuMP.@variable(pm.model,
        [l in _PM.ids(pm, nw, :branch)], base_name="$(nw)_vbdr",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branch, l), "vbdr_start", 0.01)
    )
    
    report && _PM.sol_component_value(pm, nw, :branch, :vbdr, _PM.ids(pm, nw, :branch), vbdr)
end

"variable: `vbdi[l,i,j]` for `(l,i,j)` in `arcs_from`"
function variable_branch_voltage_drop_img(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)

    vbdi = _PM.var(pm, nw)[:vbdi] = JuMP.@variable(pm.model,
        [l in _PM.ids(pm, nw, :branch)], base_name="$(nw)_vbdi",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branch, l), "vbdi_start", 0.01)
    )

    report && _PM.sol_component_value(pm, nw, :branch, :vbdi, _PM.ids(pm, nw, :branch), vbdi)
end
"variable: `css[l,i,j]` for `(l,i,j)` in `arcs_from`"
function variable_branch_series_current_squared(pm::AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, aux_fix::Bool=false, report::Bool=true)
    css = _PM.var(pm, nw)[:css] = JuMP.@variable(pm.model,
        [l in _PM.ids(pm, nw, :branch)], base_name="$(nw)_css",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branch, l), "css_start", 0.0)
    )

    if bounded
        bus = _PM.ref(pm, nw, :bus)
        branch = _PM.ref(pm, nw, :branch)

        for (l,i,j) in _PM.ref(pm, nw, :arcs_from)
            b = branch[l]
            ub = Inf
            if haskey(b, "rate_a")
                rate = b["rate_a"] * b["tap"]
                y_fr = abs(b["g_fr"] + im * b["b_fr"])
                y_to = abs(b["g_to"] + im * b["b_to"])
                shunt_current = max(y_fr * bus[i]["vmax"]^2, y_to * bus[j]["vmax"]^2)
                series_current = max(rate / bus[i]["vmin"], rate / bus[j]["vmin"])
                ub = series_current + shunt_current
            end
            if haskey(b, "c_rating_a")
                total_current = b["c_rating_a"]
                y_fr = abs(b["g_fr"] + im * b["b_fr"])
                y_to = abs(b["g_to"] + im * b["b_to"])
                shunt_current = max(y_fr * bus[i]["vmax"]^2, y_to * bus[j]["vmax"]^2)
                ub = total_current + shunt_current
            end

            if !isinf(ub)
                JuMP.set_lower_bound(css[l], -2.0 * ub^2)
                JuMP.set_upper_bound(css[l],  2.0 * ub^2)
            end
        end
    end

    if aux_fix
        JuMP.fix.(css, 0.0; force=true)
    end

    report && _PM.sol_component_value(pm, nw, :branch, :css, _PM.ids(pm, nw, :branch), css)
end

function variable_dcbranch_current(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, aux::Bool=true, bounded::Bool=true, report::Bool=true, aux_fix::Bool=false, kwargs...)
    variable_dcbranch_voltage_drop_magnitude(pm, nw=nw, bounded=bounded, report=report; kwargs...)
        
    if aux
        variable_dcbranch_current_sqr(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
    else
        if nw == nw_id_default
            variable_dcbranch_series_current_expectation(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
            variable_dcbranch_series_current_variance(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
        end 
    end
end
function variable_dcbranch_voltage_drop_magnitude(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    vmdcbdr = _PM.var(pm, nw)[:vmdcbdr] = JuMP.@variable(pm.model,
        [l in _PM.ids(pm, nw, :branchdc)], base_name="$(nw)_vmdcbdr",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branchdc, l), "vmdcbdr_start", 0.01)
    )
    
    report && _PM.sol_component_value(pm, nw, :branchdc, :vmdcbdr, _PM.ids(pm, nw, :branchdc), vmdcbdr)
end
function variable_dcbranch_current_sqr(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true, aux_fix::Bool=false, kwargs...)
    vpu = 0.8;
    cc = _PM.var(pm, nw)[:ccm_dcgrid] = JuMP.@variable(pm.model,
    [l in _PM.ids(pm, nw, :branchdc)], base_name="$(nw)_ccm_dcgrid",
    start = (_PM.comp_start_value(_PM.ref(pm, nw, :branchdc, l), "p_start", 0.0) / vpu)^2
    )
    if bounded
        for (l, branchdc) in _PM.ref(pm, nw, :branchdc)
            JuMP.set_lower_bound(cc[l], 0)
            JuMP.set_upper_bound(cc[l], (branchdc["rateA"] / vpu)^2)
        end
    end

    if aux_fix
        JuMP.fix.(cc, 0.0; force=true)
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branchdc, :ccm, _PM.ids(pm, nw, :branchdc), cc)
end
function variable_dcbranch_current_expectation(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, aux_fix::Bool=false, report::Bool=true)
    ce = _PM.var(pm, nw)[:ce] = JuMP.@variable(pm.model,
        [l in _PM.ids(pm, nw, :branchdc)], base_name="$(nw)_ce",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branchdc, l), "ce_start", 0.0)
    )

    if bounded
        for l in _PM.ids(pm, nw, :branchdc)
            JuMP.set_lower_bound(ce[l], 0.0)
        end
    end

    if aux_fix
        JuMP.fix.(ce, 0.0; force=true)
    end

    report && _PM.sol_component_value(pm, nw, :branchdc, :ce, _PM.ids(pm, nw, :branchdc), ce)
end
function variable_dcbranch_current_variance(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, aux_fix::Bool=false, report::Bool=true)
    cv = _PM.var(pm, nw)[:cv] = JuMP.@variable(pm.model,
        [l in _PM.ids(pm, nw, :branchdc)], base_name="$(nw)_cv",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branchdc, l), "cv_start", 0.0)
    )

    if bounded
        for l in _PM.ids(pm, nw, :branchdc)
                JuMP.set_lower_bound(cv[l], 0.0)
        end
    end

    if aux_fix
        JuMP.fix.(cv, 0.0; force=true)
    end

    report && _PM.sol_component_value(pm, nw, :branchdc, :cv, _PM.ids(pm, nw, :branchdc), cv)
end
