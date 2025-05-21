


function run_mn_scopf_soft(data, model_constructor, solver; kwargs...)
    # _PMACDC.process_additional_data!(data)
    return _PM.solve_model(data, model_constructor, solver, build_mn_scopf_soft; ref_extensions = [_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!, _PMSC.ref_c1!], multinetwork=true, kwargs...) 
end

function build_mn_scopf_soft(pm::_PM.AbstractPowerModel)
   

    for nh in pm.ref[:it][:pm][:hour_ids]    
        _PM.variable_bus_voltage(pm, nw=nh)
        _PM.variable_gen_power(pm, nw=nh)
        _PM.variable_branch_power(pm, nw=nh)
        _PM.variable_branch_transform(pm, nw=nh)
        _PM.constraint_model_voltage(pm, nw=nh)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nh)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nh)       
        _PMACDC.variable_dcbranch_current(pm, nw=nh)
        _PMACDC.variable_dc_converter(pm, nw=nh)                        
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nh) 
        _PMACDC.constraint_voltage_dc(pm, nw=nh)    
    
        variables_slacks(pm, nw=nh)

        objective_variable_pg_cost_pwl(pm, nw=nh)

        for i in _PM.ids(pm, nw=nh, :ref_buses)                  
            _PM.constraint_theta_ref(pm, i, nw=nh)
        end

        for i in _PM.ids(pm, :gen, nw=nh)
            constraint_generator_ramping(pm, i, nh)
        end

        for i in _PM.ids(pm, nw=nh, :bus)                        
            constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=nh)
        end

        for i in _PM.ids(pm, nw=nh, :branch)                     
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nh)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nh)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nh)
            constraint_thermal_limit_from_soft(pm, i, nw=nh)
            constraint_thermal_limit_to_soft(pm, i, nw=nh)
        end

        for i in _PM.ids(pm, nw=nh, :busdc)                                        
            constraint_power_balance_dc_soft(pm, i, nw=nh)                                      
        end

        for i in _PM.ids(pm, nw=nh, :branchdc)                                             
            constraint_ohms_dc_branch_soft(pm, i, nw=nh)                                 
        end 

        for i in _PM.ids(pm, nw=nh, :convdc)                                                
            _PMACDC.constraint_converter_losses(pm, i, nw=nh)                                                            
            _PMACDC.constraint_conv_transformer(pm, i, nw=nh)                               
            _PMACDC.constraint_conv_reactor(pm, i, nw=nh)                                 
            _PMACDC.constraint_conv_filter(pm, i, nw=nh)
            constraint_converter_current(pm, i, nw=nh)                                     
            if pm.ref[:it][:pm][:nw][nh][:convdc][i]["islcc"] == 1                
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nh)                                     
            end
            constraint_pvdc_droop_control_linear(pm, i, nw=nh)                                                                        
        end 
    end
           
    for nc in pm.ref[:it][:pm][:cont_ids]
        _PM.variable_bus_voltage(pm, nw=nc, bounded=false)
        _PM.variable_gen_power(pm, nw=nc, bounded=false)
        _PM.variable_branch_power(pm, nw=nc)
        _PM.variable_branch_transform(pm, nw=nc)
        _PM.constraint_model_voltage(pm, nw=nc)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nc)
        _PMSC.variable_c1_response_delta(pm, nw=nc)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nc, bounded=false)       
        _PMACDC.variable_dcbranch_current(pm, nw=nc)
        _PMACDC.variable_dc_converter(pm, nw=nc)                        
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nc)
        _PMACDC.constraint_voltage_dc(pm, nw=nc)

        variables_slacks(pm, nw=nc)

        for i in _PM.ids(pm, nw=nc, :ref_buses)           
            _PM.constraint_theta_ref(pm, i, nw=nc)
        end

        gen_buses = _PM.ref(pm, nw=nc, :gen_buses)
        for i in _PM.ids(pm, nw=nc, :bus)                 
            constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=nc)       

            # if a bus has active generators, fix the voltage magnitude to the base case
            if i in gen_buses
                _PMSC.constraint_c1_voltage_magnitude_link(pm, i, nw_1=pm.ref[:it][:pm][:cont_hour_id][nc], nw_2=nc)
            end
        end

        response_gens = _PM.ref(pm, :response_gens, nw=nc)
        for (i,gen) in _PM.ref(pm, :gen, nw=nc)
            pg_base = _PM.var(pm, :pg, i, nw=pm.ref[:it][:pm][:cont_hour_id][nc])

            # setup the linear response function or fix value to base case
            if i in response_gens
                _PMSC.constraint_c1_gen_power_real_response(pm, i, nw_1=pm.ref[:it][:pm][:cont_hour_id][nc], nw_2=nc)
            else
                _PMSC.constraint_c1_gen_power_real_link(pm, i, nw_1=pm.ref[:it][:pm][:cont_hour_id][nc], nw_2=nc)
            end
        end

        for i in _PM.ids(pm, nw=nc, :branch)                     
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nc)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nc)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nc)
            constraint_thermal_limit_from_soft(pm, i, nw=nc)
            constraint_thermal_limit_to_soft(pm, i, nw=nc)
        end

        for i in _PM.ids(pm, nw=nc, :busdc)                                               
            constraint_power_balance_dc_soft(pm, i, nw=nc)                                     
        end                                                                               
        for i in _PM.ids(pm, nw=nc, :branchdc)                                             
            constraint_ohms_dc_branch_soft(pm, i, nw=nc)                                
        end                                                                                
        for i in _PM.ids(pm, nw=nc, :convdc)                                               
            _PMACDC.constraint_converter_losses(pm, i, nw=nc)                              
            constraint_converter_current(pm, i, nw=nc)                             
            _PMACDC.constraint_conv_transformer(pm, i, nw=nc)                              
            _PMACDC.constraint_conv_reactor(pm, i, nw=nc)                                  
            _PMACDC.constraint_conv_filter(pm, i, nw=nc)                                   
            if pm.ref[:it][:pm][:nw][nc][:convdc][i]["islcc"] == 1            
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nc)                                    
            end
            constraint_pvdc_droop_control_linear(pm, i, nw=nc)                                                                            
        end    
    end

    objective_min_fuel_cost_mn_scopf_soft(pm)
       
end

# mn_strg

function run_mn_scopf_strg_soft(data, model_constructor, solver; kwargs...)
    # _PMACDC.process_additional_data!(data)
    return _PM.solve_model(data, model_constructor, solver, build_mn_scopf_strg_soft; ref_extensions = [_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!, _PMSC.ref_c1!], multinetwork=true, kwargs...) 
end

function build_mn_scopf_strg_soft(pm::_PM.AbstractPowerModel)
   

    for nh in pm.ref[:it][:pm][:hour_ids]    
        _PM.variable_bus_voltage(pm, nw=nh)
        _PM.variable_gen_power(pm, nw=nh)
        _PM.variable_storage_power(pm, nw=nh)   #_mi
        _PM.variable_branch_power(pm, nw=nh)
        _PM.variable_branch_transform(pm, nw=nh)
        _PM.constraint_model_voltage(pm, nw=nh)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nh)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nh)       
        _PMACDC.variable_dcbranch_current(pm, nw=nh)
        _PMACDC.variable_dc_converter(pm, nw=nh)                        
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nh) 
        _PMACDC.constraint_voltage_dc(pm, nw=nh)    
    
        variables_slacks(pm, nw=nh)

        objective_variable_pg_cost_pwl(pm, nw=nh)

        for i in _PM.ids(pm, nw=nh, :ref_buses)                  
            _PM.constraint_theta_ref(pm, i, nw=nh)
        end

        for i in _PM.ids(pm, :gen, nw=nh)
            constraint_generator_ramping(pm, i, nh)
        end

        for i in _PM.ids(pm, nw=nh, :bus)                        
            constraint_power_balance_ac_shunt_strg_dispatch_soft(pm, i, nw=nh) 
        end
        
        for i in _PM.ids(pm, :storage, nw=nh)
            _PM.constraint_storage_complementarity_nl(pm, i, nw=nh)    #_mi
            _PM.constraint_storage_losses(pm, i, nw=nh)
            _PM.constraint_storage_thermal_limit(pm, i, nw=nh)
        end
        
        for i in _PM.ids(pm, nw=nh, :branch)                     
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nh)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nh)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nh)
            constraint_thermal_limit_from_soft(pm, i, nw=nh)
            constraint_thermal_limit_to_soft(pm, i, nw=nh)
        end

        for i in _PM.ids(pm, nw=nh, :busdc)                                        
            constraint_power_balance_dc_soft(pm, i, nw=nh)                                      
        end

        for i in _PM.ids(pm, nw=nh, :branchdc)                                             
            constraint_ohms_dc_branch_soft(pm, i, nw=nh)                                 
        end 

        for i in _PM.ids(pm, nw=nh, :convdc)                                                
            _PMACDC.constraint_converter_losses(pm, i, nw=nh)                                                            
            _PMACDC.constraint_conv_transformer(pm, i, nw=nh)                               
            _PMACDC.constraint_conv_reactor(pm, i, nw=nh)                                 
            _PMACDC.constraint_conv_filter(pm, i, nw=nh)
            constraint_converter_current(pm, i, nw=nh)                                     
            if pm.ref[:it][:pm][:nw][nh][:convdc][i]["islcc"] == 1                
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nh)                                     
            end
            constraint_pvdc_droop_control_linear(pm, i, nw=nh)                                                                        
        end 
    end

    nh_ids = sort(collect(pm.ref[:it][:pm][:hour_ids]))
    nh_1 = nh_ids[1]
    for i in _PM.ids(pm, :storage, nw=nh_1)
        _PM.constraint_storage_state(pm, i, nw=nh_1)
    end

    for nh_2 in nh_ids[2:end]
        for i in _PM.ids(pm, :storage, nw=nh_2)
            _PM.constraint_storage_state(pm, i, nh_1, nh_2)
        end
        nh_1 = nh_2
    end
           
    for nc in pm.ref[:it][:pm][:cont_ids]
        _PM.variable_bus_voltage(pm, nw=nc, bounded=false)
        _PM.variable_gen_power(pm, nw=nc, bounded=false)
        _PM.variable_storage_power(pm, nw=nc)
        _PM.variable_branch_power(pm, nw=nc)
        _PM.variable_branch_transform(pm, nw=nc)
        _PM.constraint_model_voltage(pm, nw=nc)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nc)
        _PMSC.variable_c1_response_delta(pm, nw=nc)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nc, bounded=false)       
        _PMACDC.variable_dcbranch_current(pm, nw=nc)
        _PMACDC.variable_dc_converter(pm, nw=nc)                        
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nc)
        _PMACDC.constraint_voltage_dc(pm, nw=nc)

        variables_slacks(pm, nw=nc)

        for i in _PM.ids(pm, nw=nc, :ref_buses)           
            _PM.constraint_theta_ref(pm, i, nw=nc)
        end

        gen_buses = _PM.ref(pm, nw=nc, :gen_buses)
        for i in _PM.ids(pm, nw=nc, :bus)                 
            constraint_power_balance_ac_shunt_strg_dispatch_soft(pm, i, nw=nc)       

            # if a bus has active generators, fix the voltage magnitude to the base case
            if i in gen_buses
                _PMSC.constraint_c1_voltage_magnitude_link(pm, i, nw_1=pm.ref[:it][:pm][:cont_hour_id][nc], nw_2=nc)
            end
        end

        response_gens = _PM.ref(pm, :response_gens, nw=nc)
        for (i,gen) in _PM.ref(pm, :gen, nw=nc)
            pg_base = _PM.var(pm, :pg, i, nw=pm.ref[:it][:pm][:cont_hour_id][nc])

            # setup the linear response function or fix value to base case during contingencies
            if i in response_gens
                _PMSC.constraint_c1_gen_power_real_response(pm, i, nw_1=pm.ref[:it][:pm][:cont_hour_id][nc], nw_2=nc)
            else
                _PMSC.constraint_c1_gen_power_real_link(pm, i, nw_1=pm.ref[:it][:pm][:cont_hour_id][nc], nw_2=nc)
            end
        end

        for i in _PM.ids(pm, :storage, nw=nc)
            _PM.constraint_storage_complementarity_nl(pm, i, nw=nc)
            _PM.constraint_storage_losses(pm, i, nw=nc)
            _PM.constraint_storage_thermal_limit(pm, i, nw=nc)

            # setup the linear response function or fix value to base case during contingencies
            # assume all storage responding
            constraint_storage_power_real_response(pm, i, nw_1=pm.ref[:it][:pm][:cont_hour_id][nc], nw_2=nc)
            # if not responding
            # constraint_storage_power_real_link(pm, i, nw_1=pm.ref[:it][:pm][:cont_hour_id][nc], nw_2=nc)
            # can also regulate voltage similar to generator
        end



        for i in _PM.ids(pm, nw=nc, :branch)                     
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nc)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nc)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nc)
            constraint_thermal_limit_from_soft(pm, i, nw=nc)
            constraint_thermal_limit_to_soft(pm, i, nw=nc)
        end

        for i in _PM.ids(pm, nw=nc, :busdc)                                               
            constraint_power_balance_dc_soft(pm, i, nw=nc)                                     
        end                                                                               
        for i in _PM.ids(pm, nw=nc, :branchdc)                                             
            constraint_ohms_dc_branch_soft(pm, i, nw=nc)                                
        end                                                                                
        for i in _PM.ids(pm, nw=nc, :convdc)                                               
            _PMACDC.constraint_converter_losses(pm, i, nw=nc)                              
            constraint_converter_current(pm, i, nw=nc)                             
            _PMACDC.constraint_conv_transformer(pm, i, nw=nc)                              
            _PMACDC.constraint_conv_reactor(pm, i, nw=nc)                                  
            _PMACDC.constraint_conv_filter(pm, i, nw=nc)                                   
            if pm.ref[:it][:pm][:nw][nc][:convdc][i]["islcc"] == 1            
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nc)                                    
            end
            constraint_pvdc_droop_control_linear(pm, i, nw=nc)                                                                            
        end    
    end

    objective_min_fuel_cost_mn_scopf_soft(pm)
       
end