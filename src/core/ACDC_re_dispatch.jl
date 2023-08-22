""
function run_acdcreopf(file::String, model_type::Type, solver; kwargs...)
    data = _PM.parse_file(file)
    PowerModelsACDC.process_additional_data!(data)
    return run_acdcreopf(data, model_type, solver; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function run_acdcreopf(data::Dict{String,Any}, model_type::Type, solver; kwargs...)
    return _PM.run_model(data, model_type, solver, post_acdcreopf; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function post_acdcreopf(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    variable_absolute_gen_power_real(pm)
    _PM.variable_branch_power(pm)

    _PMACDC.variable_active_dcbranch_flow(pm)
    _PMACDC.variable_dcbranch_current(pm)
    _PMACDC.variable_dc_converter(pm)
    _PMACDC.variable_dcgrid_voltage_magnitude(pm)

    _PM.constraint_model_voltage(pm)
    _PMACDC.constraint_voltage_dc(pm)

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        _PMACDC.constraint_power_balance_ac(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        _PM.constraint_ohms_yt_from(pm, i)
        _PM.constraint_ohms_yt_to(pm, i)
        _PM.constraint_voltage_angle_difference(pm, i) 
        _PM.constraint_thermal_limit_from(pm, i)
        _PM.constraint_thermal_limit_to(pm, i)
    end
    for i in _PM.ids(pm, :busdc)
        _PMACDC.constraint_power_balance_dc(pm, i)
    end
    for i in _PM.ids(pm, :branchdc)
        _PMACDC.constraint_ohms_dc_branch(pm, i)
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

##
"generates variables `pgabsp[j]` & `pgabsn[j]` for `j` in `gen` for linearizing the absolute `active` generation difference from the given reference values for re-dispatch"
function variable_absolute_gen_power_real(pm::_PM.AbstractPowerModel; kwargs...)
    variable_absolute_gen_power_real_positive(pm; kwargs...)
    variable_absolute_gen_power_real_negative(pm; kwargs...)
end


function variable_absolute_gen_power_real_positive(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pgabsp = _PM.var(pm, nw)[:pgabsp] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_pgabsp",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "pgabsp_start")
    )

    if bounded
        for (i, gen) in _PM.ref(pm, nw, :gen)
            JuMP.set_lower_bound(pgabsp[i], 0)
            JuMP.set_upper_bound(pgabsp[i], gen["pmax"])
        end
    end
# 
    # report && _IM.sol_component_value(pm, nw, :gen, :pgabsp, _PM.ids(pm, nw, :gen), pgabsp)
end

function variable_absolute_gen_power_real_negative(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pgabsn = _PM.var(pm, nw)[:pgabsn] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_pgabsn",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "pgabsn_start")
    )

    if bounded
        for (i, gen) in _PM.ref(pm, nw, :gen)
            JuMP.set_lower_bound(pgabsn[i], 0)
            JuMP.set_upper_bound(pgabsn[i], gen["pmax"])
        end
    end

    # report && _IM.sol_component_value(pm, nw, :gen, :pgabsn, _PM.ids(pm, nw, :gen), pgabsn)
end


###

