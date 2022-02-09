
function run_c1_scopf_GM(file, model_constructor, solver; kwargs...)                                         # Update_GM
    return _PM.run_model(file, model_constructor, solver, build_c1_scopf_GM; multinetwork=true, kwargs...)   # Update_GM
end

# enables support for v[1], required for objective_variable_pg_cost when pg is an expression
Base.getindex(v::JuMP.GenericAffExpr, i::Int64) = v

""
function build_c1_scopf_GM(pm::_PM.AbstractPowerModel)
    # base-case network id is 0

    _PM.variable_bus_voltage(pm, nw=0)
    _PM.variable_gen_power(pm, nw=0)
    _PM.variable_branch_power(pm, nw=0)
    # Update_GM
    _PMACDC.variable_active_dcbranch_flow(pm, nw=0)       # Update_GM
    _PMACDC.variable_dcbranch_current(pm, nw=0)           # Update_GM
    _PMACDC.variable_dc_converter(pm, nw=0)               # Update_GM
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=0)   # Update_GM
    # Update_GM
    _PM.constraint_model_voltage(pm, nw=0)
    # Update_GM
    _PMACDC.constraint_voltage_dc(pm, nw=0)               # Update_GM
    # Update_GM

    for i in ids(pm, :ref_buses, nw=0)
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in ids(pm, :bus, nw=0)
        _PM.constraint_power_balance(pm, i, nw=0)
    end

    for i in ids(pm, :branch, nw=0)
        _PM.constraint_ohms_yt_from(pm, i, nw=0)
        _PM.constraint_ohms_yt_to(pm, i, nw=0)

        _PM.constraint_voltage_angle_difference(pm, i, nw=0)

        _PM.constraint_thermal_limit_from(pm, i, nw=0)
        _PM.constraint_thermal_limit_to(pm, i, nw=0)
    end


    contigency_ids = [id for id in nw_ids(pm) if id != 0]
    for nw in contigency_ids
        _PM.variable_bus_voltage(pm, nw=nw, bounded=false)
        _PM.variable_gen_power(pm, nw=nw, bounded=false)
        _PM.variable_branch_power(pm, nw=nw)

        _PMSC.variable_c1_response_delta(pm, nw=nw)


        _PM.constraint_model_voltage(pm, nw=nw)

        for i in ids(pm, :ref_buses, nw=nw)
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = ref(pm, :gen_buses, nw=nw)
        for i in ids(pm, :bus, nw=nw)
            _PM.constraint_power_balance(pm, i, nw=nw)

            # if a bus has active generators, fix the voltage magnitude to the base case
            if i in gen_buses
                _PMSC.constraint_c1_voltage_magnitude_link(pm, i, nw_1=0, nw_2=nw)
            end
        end


        response_gens = ref(pm, :response_gens, nw=nw)
        for (i,gen) in ref(pm, :gen, nw=nw)
            pg_base = var(pm, :pg, i, nw=0)

            # setup the linear response function or fix value to base case
            if i in response_gens
                _PMSC.constraint_c1_gen_power_real_response(pm, i, nw_1=0, nw_2=nw)
            else
                _PMSC.constraint_c1_gen_power_real_link(pm, i, nw_1=0, nw_2=nw)
            end
        end


        for i in ids(pm, :branch, nw=nw)
            _PM.constraint_ohms_yt_from(pm, i, nw=nw)
            _PM.constraint_ohms_yt_to(pm, i, nw=nw)

            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)

            _PM.constraint_thermal_limit_from(pm, i, nw=nw)
            _PM.constraint_thermal_limit_to(pm, i, nw=nw)
        end
    end
# Update_GM
        for i in _PM.ids(pm, :busdc, nw=nw)                                                # Update_GM
            _PMACDC.constraint_power_balance_dc(pm, i, nw=nw)                                      # Update_GM
        end                                                                                # Update_GM
        for i in _PM.ids(pm, :branchdc, nw=nw)                                             # Update_GM
            _PMACDC.constraint_ohms_dc_branch(pm, i, nw=nw)                                        # Update_GM
        end                                                                                # Update_GM
        for i in _PM.ids(pm, :convdc, nw=nw)                                               # Update_GM
            _PMACDC.constraint_converter_losses(pm, i, nw=nw)                                      # Update_GM
            _PMACDC.constraint_converter_current(pm, i, nw=nw)                                     # Update_GM
            _PMACDC.constraint_conv_transformer(pm, i, nw=nw)                                      # Update_GM
            _PMACDC.constraint_conv_reactor(pm, i, nw=nw)                                          # Update_GM
            _PMACDC.constraint_conv_filter(pm, i, nw=nw)                                           # Update_GM
            if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1          # Update_GM
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nw)                                     # Update_GM
            end                                                                            # Update_GM
        end                                                                                # Update_GM
# Update_GM

    ##### Setup Objective #####
    _PMSC.objective_c1_variable_pg_cost_basecase(pm)

    # explicit network id needed because of conductor-less
    pg_cost = var(pm, 0, :pg_cost)

    JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i,gen) in ref(pm, 0, :gen) )
    )
end

