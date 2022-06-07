########################################################################################################################################################################
function run_c1_scopf_GM(data, model_constructor, solver; kwargs...)                                         # Update_GM
    # _PMACDC.process_additional_data!(data)                                                                 # Update_GM
    return _PM.run_model(data, model_constructor, solver, build_c1_scopf_GM; ref_extensions = [_PMACDC.add_ref_dcgrid!], multinetwork=true, kwargs...)   # Update_GM
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

    for i in _PM.ids(pm, nw=0, :ref_buses)                  # Update_GM_PMSC
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :bus)                        # Update_GM_PMSC
        _PMACDC.constraint_power_balance_ac(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :branch)                     # Update_GM_PMSC
        _PM.constraint_ohms_yt_from(pm, i, nw=0)
        _PM.constraint_ohms_yt_to(pm, i, nw=0)

        _PM.constraint_voltage_angle_difference(pm, i, nw=0)

        _PM.constraint_thermal_limit_from(pm, i, nw=0)
        _PM.constraint_thermal_limit_to(pm, i, nw=0)
    end

    # Update_GM

    for i in _PM.ids(pm, nw=0, :busdc)                                                # Update_GM now nw=0, otherwise if nw for loop
        _PMACDC.constraint_power_balance_dc(pm, i, nw=0)                                      # Update_GM
    end                                                                                # Update_GM
    for i in _PM.ids(pm, nw=0, :branchdc)                                              # Update_GM
        _PMACDC.constraint_ohms_dc_branch(pm, i, nw=0)                                 # Update_GM
    end                                                                                # Update_GM
    for i in _PM.ids(pm, nw=0, :convdc)                                                # Update_GM
        _PMACDC.constraint_converter_losses(pm, i, nw=0)                               # Update_GM
        _PMACDC.constraint_converter_current(pm, i, nw=0)                              # Update_GM
        _PMACDC.constraint_conv_transformer(pm, i, nw=0)                               # Update_GM
        _PMACDC.constraint_conv_reactor(pm, i, nw=0)                                   # Update_GM
        _PMACDC.constraint_conv_filter(pm, i, nw=0)                                    # Update_GM
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1          # Update_GM      
            _PMACDC.constraint_conv_firing_angle(pm, i, nw=0)                                     # Update_GM
        end                                                                            # Update_GM
    end
                                                                                  
    # Update_GM

    contigency_ids = [id for id in _PM.nw_ids(pm) if id != 0]         # Update_GM_PMSC
    @show contigency_ids
    for nw in contigency_ids
        
        _PM.variable_bus_voltage(pm, nw=nw, bounded=false)
        _PM.variable_gen_power(pm, nw=nw, bounded=false)
        _PM.variable_branch_power(pm, nw=nw)
        _PMACDC.variable_active_dcbranch_flow(pm, nw=nw)       # Update_GM
        _PMACDC.variable_dcbranch_current(pm, nw=nw)           # Update_GM
        _PMACDC.variable_dc_converter(pm, nw=nw)               # Update_GM
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nw)   # Update_GM
        _PMACDC.constraint_voltage_dc(pm, nw=nw)

        _PMSC.variable_c1_response_delta(pm, nw=nw)


        _PM.constraint_model_voltage(pm, nw=nw)

        for i in _PM.ids(pm, nw=nw, :ref_buses)           # Update_GM_PMSC
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = _PM.ref(pm, :gen_buses, nw=nw)
        for i in _PM.ids(pm, :bus, nw=nw)                 # Update_GM_PMSC
            _PMACDC.constraint_power_balance_ac(pm, i, nw=nw)       # Update_GM

            # if a bus has active generators, fix the voltage magnitude to the base case
            if i in gen_buses
                _PMSC.constraint_c1_voltage_magnitude_link(pm, i, nw_1=0, nw_2=nw)
            end
        end


        response_gens = _PM.ref(pm, :response_gens, nw=nw)
        for (i,gen) in _PM.ref(pm, :gen, nw=nw)
            pg_base = _PM.var(pm, :pg, i, nw=0)

            # setup the linear response function or fix value to base case
            if i in response_gens
                _PMSC.constraint_c1_gen_power_real_response(pm, i, nw_1=0, nw_2=nw)
            else
                _PMSC.constraint_c1_gen_power_real_link(pm, i, nw_1=0, nw_2=nw)
            end
        end


        for i in _PM.ids(pm, :branch, nw=nw)                      # Update_GM_PMSC
            _PM.constraint_ohms_yt_from(pm, i, nw=nw)
            _PM.constraint_ohms_yt_to(pm, i, nw=nw)

            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)

            _PM.constraint_thermal_limit_from(pm, i, nw=nw)
            _PM.constraint_thermal_limit_to(pm, i, nw=nw)
        end

        # Update_GM


        for i in _PM.ids(pm, nw=nw, :busdc)                                                # Update_GM now nw=0, otherwise if nw for loop
            _PMACDC.constraint_power_balance_dc(pm, i, nw=nw)                                      # Update_GM
        end                                                                                # Update_GM
        for i in _PM.ids(pm, nw=nw, :branchdc)                                              # Update_GM
            _PMACDC.constraint_ohms_dc_branch(pm, i, nw=nw)                                 # Update_GM
        end                                                                                # Update_GM
        for i in _PM.ids(pm, nw=nw, :convdc)                                                # Update_GM
            _PMACDC.constraint_converter_losses(pm, i, nw=nw)                               # Update_GM
            _PMACDC.constraint_converter_current(pm, i, nw=nw)                              # Update_GM
            _PMACDC.constraint_conv_transformer(pm, i, nw=nw)                               # Update_GM
            _PMACDC.constraint_conv_reactor(pm, i, nw=nw)                                   # Update_GM
            _PMACDC.constraint_conv_filter(pm, i, nw=nw)                                    # Update_GM
            if pm.ref[:it][:pm][:nw][nw][:convdc][i]["islcc"] == 1          # Update_GM      
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nw)                                     # Update_GM
            end                                                                            # Update_GM
        end

    end

# Update_GM

    ##### Setup Objective #####
    _PMSC.objective_c1_variable_pg_cost_basecase(pm)

    # explicit network id needed because of conductor-less
    pg_cost = _PMSC.var(pm, 0, :pg_cost)

    JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i,gen) in _PMSC.ref(pm, 0, :gen) )
    )
    #_PM.objective_min_fuel_cost(pm)
end

