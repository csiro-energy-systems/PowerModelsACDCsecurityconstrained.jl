""
function run_acdcreopf_ots(file::String, model_type::Type, solver; kwargs...)
    data = _PM.parse_file(file)
    PowerModelsACDC.process_additional_data!(data)
    return run_acdcreopf_ots(data, model_type, solver; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function run_acdcreopf_ots(data::Dict{String,Any}, model_type::Type, solver; kwargs...)
    return _PM.solve_model(data, model_type, solver, post_acdcreopf_ots; ref_extensions=[_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function post_acdcreopf_ots(pm::_PM.AbstractPowerModel)
    _PM.variable_branch_indicator(pm)
    _PM.variable_bus_voltage_on_off(pm)

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
        _PM.constraint_ohms_yt_from_on_off(pm, i)
        _PM.constraint_ohms_yt_to_on_off(pm, i)
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


"variable: `0 <= z_branchdc[l] <= 1` for `l` in `dc branch`es"
function variable_branchdc_indicator(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, relax::Bool=false, report::Bool=true)
    if !relax
        z_branchdc = _PM.var(pm, nw)[:z_branchdc] = JuMP.@variable(pm.model,
            [l in _PM.ids(pm, nw, :branchdc)], base_name="$(nw)_z_branchdc",
            binary = true,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :branchdc, l), "z_branchdc_start", 1.0)
        )
    else
        z_branch = _PM.var(pm, nw)[:z_branchdc] = JuMP.@variable(pm.model,
            [l in _PM.ids(pm, nw, :branchdc)], base_name="$(nw)_z_branchdc",
            lower_bound = 0.0,
            upper_bound = 1.0,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :branchdc, l), "z_branchdc_start", 1.0)
        )
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branchdc, :brdc_status, _PM.ids(pm, nw, :branchdc), z_branchdc)
end

###
function constraint_ohms_dc_branch_on_off(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branchdc, i)
    f_bus = branch["fbusdc"]
    t_bus = branch["tbusdc"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p = _PM.ref(pm, nw, :dcpol)

    constraint_ohms_dc_branch_on_off(pm, nw, i, f_bus, t_bus, f_idx, t_idx, branch["r"], p)
end
function constraint_ohms_dc_branch_on_off(pm::_PM.AbstractACPModel, n::Int, i::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
    vmdc_fr = _PM.var(pm, n,  :vdcm, f_bus)
    vmdc_to = _PM.var(pm, n,  :vdcm, t_bus)
    z_dc = _PM.var(pm, n,  :z_branchdc, i)

    if r == 0
        JuMP.@constraint(pm.model, z_dc * p_dc_fr + p_dc_to == 0)
    else
        g = 1 / r
        JuMP.@NLconstraint(pm.model, p_dc_fr == z_dc * p * g * vmdc_fr * (vmdc_fr - vmdc_to))
        JuMP.@NLconstraint(pm.model, p_dc_to == z_dc * p * g * vmdc_to * (vmdc_to - vmdc_fr))
    end
end

