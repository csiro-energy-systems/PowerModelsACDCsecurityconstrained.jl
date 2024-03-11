"""
An OPF formulation for integrated HVAC and HVDC grid.

"""
function run_acdcpf_GM(file::String, model_type::Type, solver; kwargs...)
    data = _PM.parse_file(file)
    PowerModelsACDC.process_additional_data!(data)
    return run_acdcpf_GM(data::Dict{String,Any}, model_type, solver; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end


function run_acdcpf_GM(data::Dict{String,Any}, model_type::Type, solver; kwargs...)
    return _PM.run_model(data, model_type, solver, post_acdcpf_GM; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end


function post_acdcpf_GM(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm, bounded = false)
    _PM.variable_gen_power(pm, bounded = false)
    _PM.variable_branch_power(pm, bounded = false)

    # dirty, should be improved in the future TODO
    if typeof(pm) <: _PM.SOCBFPowerModel
        _PM.variable_branch_current(pm, bounded = false)
    end

    _PMACDC.variable_active_dcbranch_flow(pm, bounded = false)
    _PMACDC.variable_dcbranch_current(pm, bounded = false)
    _PMACDC.variable_dc_converter(pm, bounded = false)
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, bounded = false)

    _PM.constraint_model_voltage(pm)
    _PMACDC.constraint_voltage_dc(pm)

     variable_dc_droop_control(pm)


    for (i,bus) in _PM.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PM.constraint_theta_ref(pm, i)
        _PM.constraint_voltage_magnitude_setpoint(pm, i)  ##
    end

    for (i, bus) in _PM.ref(pm, :bus)# _PM.ids(pm, :bus)
        _PMACDC.constraint_power_balance_ac(pm, i)
        # PV Bus Constraints
        if length(_PM.ref(pm, :bus_gens, i)) > 0 && !(i in _PM.ids(pm,:ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2
            _PM.constraint_voltage_magnitude_setpoint(pm, i)    ##
            for j in _PM.ref(pm, :bus_gens, i)
                _PM.constraint_gen_setpoint_active(pm, j)       ##
            end
        end
    end

    for i in _PM.ids(pm, :branch)
        # dirty, should be improved in the future TODO
        if typeof(pm) <: _PM.SOCBFPowerModel
            _PM.constraint_power_losses(pm, i)
            _PM.constraint_voltage_magnitude_difference(pm, i)
            _PM.constraint_branch_current(pm, i)
        else
            _PM.constraint_ohms_yt_from(pm, i)
            _PM.constraint_ohms_yt_to(pm, i)
        end
    end
    for i in _PM.ids(pm, :busdc)
        _PMACDC.constraint_power_balance_dc(pm, i)
    end
    for i in _PM.ids(pm, :branchdc)
        _PMACDC.constraint_ohms_dc_branch(pm, i)
    end
    for (c, conv) in _PM.ref(pm, :convdc)
        _PMACDC.constraint_conv_transformer(pm, c)
        _PMACDC.constraint_conv_reactor(pm, c)
        _PMACDC.constraint_conv_filter(pm, c)
        if conv["type_dc"] == 2
            _PMACDC.constraint_dc_voltage_magnitude_setpoint(pm, c)
            _PMACDC.constraint_reactive_conv_setpoint(pm, c)
        elseif conv["type_dc"] == 3
            constraint_dc_droop_control(pm, c)
        elseif conv["type_dc"] == 1 &&  conv["type_ac"] == 2 || conv["type_ac"] == 3
            _PMACDC.constraint_active_conv_setpoint(pm, c)
        elseif conv["type_dc"] == 1 &&  conv["type_ac"] != 2 || conv["type_ac"] != 3
            _PMACDC.constraint_active_conv_setpoint(pm, c)
            _PMACDC.constraint_reactive_conv_setpoint(pm, c)
        end
            
        _PMACDC.constraint_converter_losses(pm, c)
        _PMACDC.constraint_converter_current(pm, c)
    end
end




function run_acdcopf_droop(file::String, model_type::Type, solver; kwargs...)
    data = _PM.parse_file(file)
    PowerModelsACDC.process_additional_data!(data)
    return run_acdcopf_droop(data, model_type, solver; ref_extensions = [add_ref_dcgrid!], kwargs...)
end


function run_acdcopf_droop(data::Dict{String,Any}, model_type::Type, solver; kwargs...)
    return _PM.solve_model(data, model_type, solver, build_acdcopf_droop; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end


function build_acdcopf_droop(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)

    _PMACDC.variable_active_dcbranch_flow(pm)
    _PMACDC.variable_dcbranch_current(pm)
    _PMACDC.variable_dc_converter(pm)
    _PMACDC.variable_dcgrid_voltage_magnitude(pm)

    variable_dc_droop_control(pm)

    _PM.objective_min_fuel_cost(pm)

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
        _PM.constraint_voltage_angle_difference(pm, i) #angle difference across transformer and reactor - useful for LPAC if available?
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
        constraint_dc_droop_control(pm, i) 
    end
end



