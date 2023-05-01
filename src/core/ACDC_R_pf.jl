

""
function run_acdcopf_R(data::Dict{String,Any}, model_type::Type, solver; kwargs...)
    return _PM.run_model(data, model_type, solver, post_acdcopf_R; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end

function post_acdcopf_R(pm::_PM.AbstractPowerModel)

    # variables upper level
    variable_branch_indicator_R(pm) # TODO
    # constraints upper level
    constraint_branch_contingency_limit(pm)
    # variables lower level

    variable_bus_voltage(pm)
    variable_gen_power(pm)
    variable_branch_power(pm)

    #_PMACDC.variable_active_dcbranch_flow(pm)
    #_PMACDC.variable_dcbranch_current(pm)
    #_PMACDC.variable_dc_converter(pm)
    #_PMACDC.variable_dcgrid_voltage_magnitude(pm)

    # constraints lower level

    constraint_model_voltage(pm)
    #_PMACDC.constraint_voltage_dc(pm)

    for i in _PM.ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    #for i in _PM.ids(pm, :bus)
    #    _PMACDC.constraint_power_balance_ac(pm, i)
    #end
    for i in _PM.ids(pm, :bus)
        constraint_power_balance(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)    
        constraint_ohms_yt_to(pm, i)
        constraint_voltage_angle_difference(pm, i) 
        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end
    #for i in _PM.ids(pm, :busdc)
    #    _PMACDC.constraint_power_balance_dc(pm, i)
    #end
    #for i in _PM.ids(pm, :branchdc)
    #    _PMACDC.constraint_ohms_dc_branch(pm, i)
    #end
    #for i in _PM.ids(pm, :convdc)
    #    _PMACDC.constraint_converter_losses(pm, i)
    #    _PMACDC.constraint_converter_current(pm, i)
    #    _PMACDC.constraint_conv_transformer(pm, i)
    #    _PMACDC.constraint_conv_reactor(pm, i)
    #    _PMACDC.constraint_conv_filter(pm, i)
    #    if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1
    #        _PMACDC.constraint_conv_firing_angle(pm, i)
    #    end
    #end

    # objective lower level

    _PM.objective_variable_pg_cost(pm)
    pg_cost = _PM.var(pm, n, :pg_cost)
    
        JuMP.@objective(Lower(pm.model), Min,
            sum( pg_cost[i] for (i, gen) in _PM.ref(pm, :gen) )
        )    
    
    # objective upper level

    JuMP.@objective(Upper(pm.model), Max,
        sum( pg_cost[i] for (i, gen) in _PM.ref(pm, :gen) )
    ) 

 


end

