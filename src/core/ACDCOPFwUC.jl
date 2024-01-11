"opf with unit commitment, tests constraint_current_limit"
function _solve_ucopf(file, model_type::Type, solver; kwargs...)
    return solve_model(file, model_type, solver, _build_ucopf; kwargs...)
end

""
function _build_ucopf(pm::AbstractPowerModel)
    variable_bus_voltage(pm)

    variable_gen_indicator(pm)
    variable_gen_power_on_off(pm)

    variable_storage_indicator(pm)
    variable_storage_power_mi_on_off(pm)

    variable_branch_power(pm)
    variable_dcline_power(pm)

    objective_min_fuel_and_flow_cost(pm)

    constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :gen)
        constraint_gen_power_on_off(pm, i)
    end

    for i in ids(pm, :storage)
        constraint_storage_on_off(pm, i)
    end

    for i in ids(pm, :bus)
        constraint_power_balance(pm, i)
    end

    for i in ids(pm, :storage)
        constraint_storage_state(pm, i)
        constraint_storage_complementarity_mi(pm, i)
        constraint_storage_losses(pm, i)
        constraint_storage_thermal_limit(pm, i)
    end

    for i in ids(pm, :branch)
        constraint_ohms_yt_from(pm, i)
        constraint_ohms_yt_to(pm, i)

        constraint_voltage_angle_difference(pm, i)

        constraint_thermal_limit_from(pm, i)
        constraint_thermal_limit_to(pm, i)
    end

    for i in ids(pm, :dcline)
        constraint_dcline_power_losses(pm, i)
    end
end
