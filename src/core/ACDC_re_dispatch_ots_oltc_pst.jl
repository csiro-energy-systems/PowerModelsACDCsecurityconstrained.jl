""
function run_acdcreopf_ots_oltc_pst(file::String, model_type::Type, solver; kwargs...)
    data = _PM.parse_file(file)
    PowerModelsACDC.process_additional_data!(data)
    return run_acdcreopf_ots_oltc_pst(data, model_type, solver; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function run_acdcreopf_ots_oltc_pst(data::Dict{String,Any}, model_type::Type, solver; kwargs...)
    return _PM.solve_model(data, model_type, solver, post_acdcreopf_ots_oltc_pst; ref_extensions=[_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function post_acdcreopf_ots_oltc_pst(pm::_PM.AbstractPowerModel)
    _PM.variable_branch_indicator(pm)
    _PM.variable_bus_voltage_on_off(pm)

    _PM.variable_branch_transform(pm)

    #_PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)

    variable_absolute_gen_power_real(pm)
    variable_branchdc_indicator(pm)
    
    _PMACDC.variable_active_dcbranch_flow(pm)
    _PMACDC.variable_dcbranch_current(pm)
    _PMACDC.variable_dc_converter(pm)
    _PMACDC.variable_dcgrid_voltage_magnitude(pm)

    _PM.constraint_model_voltage_on_off(pm)
    
    #_PM.constraint_model_voltage(pm)
    _PMACDC.constraint_voltage_dc(pm)

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        _PMACDC.constraint_power_balance_ac(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        constraint_ohms_y_oltc_pst_from_on_off(pm, i)
        constraint_ohms_y_oltc_pst_to_on_off(pm, i)
        _PM.constraint_voltage_angle_difference_on_off(pm, i)
        _PM.constraint_thermal_limit_from_on_off(pm, i)
        _PM.constraint_thermal_limit_to_on_off(pm, i)
    end
    for i in _PM.ids(pm, :busdc)
        _PMACDC.constraint_power_balance_dc(pm, i)
    end
    for i in _PM.ids(pm, :branchdc)
        constraint_ohms_dc_branch_on_off(pm, i)
    end
    for i in _PM.ids(pm, :convdc)
        _PMACDC.constraint_converter_losses(pm, i)
        _PMACDC.constraint_converter_current(pm, i)
        _PMACDC.constraint_conv_transformer(pm, i)
        _PMACDC.constraint_conv_reactor(pm, i)
        _PMACDC.constraint_conv_filter(pm, i)
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1
            _PMACDC.constraint_conv_firing_angle(pm, i)
        end
    end
    
    for i in _PM.ids(pm, :gen)
        p = _PM.var(pm, :pg, i)
        pabsp = _PM.var(pm, :pgabsp, i)
        pabsn = _PM.var(pm, :pgabsn, i)
        pref = _PM.ref(pm, :gen, i, "pgref")

        JuMP.@constraint(pm.model, pabsp - pabsn == pref - p )
    end
 
    pabsp = _PM.var(pm, :pgabsp)
    pabsn = _PM.var(pm, :pgabsn)

    JuMP.@objective(pm.model, Min,
    sum( pabsp[i] + pabsn[i] for (i, gen) in _PM.ref(pm, :gen) )
                    )
end

### Branch - On/Off Ohm's Law Constraints ###

""
function constraint_ohms_y_oltc_pst_from_on_off(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_ohms_y_oltc_pst_from_on_off(pm, nw, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, vad_min, vad_max)
end


""
function constraint_ohms_y_oltc_pst_to_on_off(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    
    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_ohms_y_oltc_pst_to_on_off(pm, nw, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, vad_min, vad_max)
end

"""
Branch - On/Off Ohm's Law Constraints + Creates Ohms constraints with variables for complex transformation ratio (y post fix indicates  Y is in rectangular form)
```
p[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm^2*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus]-ta)) + (-b*tr-g*ti)/tm^2*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]-ta)))
q[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm^2*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus]-ta)) + (-g*tr+b*ti)/tm^2*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]-ta)))
```
"""
function constraint_ohms_y_oltc_pst_from_on_off(pm::_PM.AbstractACPModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, vad_min, vad_max)
    p_fr  = _PM.var(pm, n,  :p, f_idx)
    q_fr  = _PM.var(pm, n,  :q, f_idx)
    vm_fr = _PM.var(pm, n, :vm, f_bus)
    vm_to = _PM.var(pm, n, :vm, t_bus)
    va_fr = _PM.var(pm, n, :va, f_bus)
    va_to = _PM.var(pm, n, :va, t_bus)
    tm = _PM.var(pm, n, :tm, f_idx[1])
    ta = _PM.var(pm, n, :ta, f_idx[1])
    z = _PM.var(pm, n, :z_branch, i)

    JuMP.@NLconstraint(pm.model, p_fr == z*( (g+g_fr)/tm^2*vm_fr^2 + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to-ta)) + (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to-ta))) )
    JuMP.@NLconstraint(pm.model, q_fr == z*(-(b+b_fr)/tm^2*vm_fr^2 - (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to-ta)) + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to-ta))) )

    #JuMP.@NLconstraint(pm.model, p_fr ==  (g+g_fr)/tm^2*vm_fr^2 + (-g)/tm*(vm_fr*vm_to*cos(va_fr-va_to-ta)) + (-b)/tm*(vm_fr*vm_to*sin(va_fr-va_to-ta)) )
    #JuMP.@NLconstraint(pm.model, q_fr == -(b+b_fr)/tm^2*vm_fr^2 - (-b)/tm*(vm_fr*vm_to*cos(va_fr-va_to-ta)) + (-g)/tm*(vm_fr*vm_to*sin(va_fr-va_to-ta)) )
end

"""
```
p[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm^2*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus]+ta)) + (-b*tr+g*ti)/tm^2*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]+ta)))
q[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm^2*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus]+ta)) + (-g*tr-b*ti)/tm^2*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]+ta)))
```
"""
function constraint_ohms_y_oltc_pst_to_on_off(pm::_PM.AbstractACPModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, vad_min, vad_max)
    p_to  = _PM.var(pm, n,  :p, t_idx)
    q_to  = _PM.var(pm, n,  :q, t_idx)
    vm_fr = _PM.var(pm, n, :vm, f_bus)
    vm_to = _PM.var(pm, n, :vm, t_bus)
    va_fr = _PM.var(pm, n, :va, f_bus)
    va_to = _PM.var(pm, n, :va, t_bus)
    tm = _PM.var(pm, n, :tm, f_idx[1])
    ta = _PM.var(pm, n, :ta, f_idx[1])
    z = _PM.var(pm, n, :z_branch, i)

    JuMP.@NLconstraint(pm.model, p_to == z*( (g+g_to)*vm_to^2 + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr+ta)) + (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr+ta))) )
    JuMP.@NLconstraint(pm.model, q_to == z*(-(b+b_to)*vm_to^2 - (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr+ta)) + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr+ta))) )

    #JuMP.@NLconstraint(pm.model, p_to ==  (g+g_to)*vm_to^2 + -g/tm*(vm_to*vm_fr*cos(va_to-va_fr+ta)) + -b/tm*(vm_to*vm_fr*sin(va_to-va_fr+ta)) )
    #JuMP.@NLconstraint(pm.model, q_to == -(b+b_to)*vm_to^2 - -b/tm*(vm_to*vm_fr*cos(va_to-va_fr+ta)) + -g/tm*(vm_to*vm_fr*sin(va_to-va_fr+ta)) )
end



