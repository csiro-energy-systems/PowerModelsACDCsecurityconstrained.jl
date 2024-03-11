"""
This formulation is best used in conjunction with the contingency filters that find
violated contingencies in integrated ACDC grid.

"""

function run_scopf(data, model_constructor, solver; kwargs...)
    # _PMACDC.process_additional_data!(data)
    return _PM.solve_model(data, model_constructor, solver, build_scopf; ref_extensions = [_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!, _PMSC.ref_c1!], multinetwork=true, kwargs...)
end


function build_scopf(pm::_PM.AbstractPowerModel)
    
    _PM.variable_bus_voltage(pm, nw=0)
    _PM.variable_gen_power(pm, nw=0)
    _PM.variable_branch_power(pm, nw=0)
    _PM.variable_branch_transform(pm, nw=0)
    _PM.constraint_model_voltage(pm, nw=0)

    _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=0)

    _PMACDC.variable_active_dcbranch_flow(pm, nw=0)
    _PMACDC.variable_dcbranch_current(pm, nw=0)
    _PMACDC.variable_dc_converter(pm, nw=0)
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=0)
    _PMACDC.constraint_voltage_dc(pm, nw=0)

   
    for i in _PM.ids(pm, nw=0, :ref_buses)
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :bus)
        _PMACDC.constraint_power_balance_ac(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :branch)
        constraint_ohms_y_oltc_pst_from(pm, i, nw=0)
        constraint_ohms_y_oltc_pst_to(pm, i, nw=0)
        _PM.constraint_voltage_angle_difference(pm, i, nw=0)
        _PM.constraint_thermal_limit_from(pm, i, nw=0)
        _PM.constraint_thermal_limit_to(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :busdc)                          
        _PMACDC.constraint_power_balance_dc(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :branchdc)
        _PMACDC.constraint_ohms_dc_branch(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :convdc)
        _PMACDC.constraint_converter_losses(pm, i, nw=0)
        _PMACDC.constraint_converter_current(pm, i, nw=0)
        _PMACDC.constraint_conv_transformer(pm, i, nw=0)
        _PMACDC.constraint_conv_reactor(pm, i, nw=0)
        _PMACDC.constraint_conv_filter(pm, i, nw=0)
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1
            _PMACDC.constraint_conv_firing_angle(pm, i, nw=0)
        end
        constraint_pvdc_droop_control_linear(pm, i, nw=0)
    end                                                                             

    contigency_ids = [id for id in _PM.nw_ids(pm) if id != 0]
    
    for nw in contigency_ids
        _PM.variable_bus_voltage(pm, nw=nw, bounded=false)    
        _PM.variable_gen_power(pm, nw=nw, bounded=false)       
        _PM.variable_branch_power(pm, nw=nw)
        _PM.variable_branch_transform(pm, nw=nw)
        _PM.constraint_model_voltage(pm, nw=nw)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nw)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nw)
        _PMACDC.variable_dcbranch_current(pm, nw=nw)
        _PMACDC.variable_dc_converter(pm, nw=nw)
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nw)
        _PMACDC.constraint_voltage_dc(pm, nw=nw)

        _PMSC.variable_c1_response_delta(pm, nw=nw)

        for i in _PM.ids(pm, nw=nw, :ref_buses)
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = _PM.ref(pm, :gen_buses, nw=nw)
        for i in _PM.ids(pm, :bus, nw=nw)
            _PMACDC.constraint_power_balance_ac(pm, i, nw=nw)

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

        for i in _PM.ids(pm,  nw=nw, :branch)
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nw)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nw)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)
            _PM.constraint_thermal_limit_from(pm, i, nw=nw)
            _PM.constraint_thermal_limit_to(pm, i, nw=nw)
        end

        for i in _PM.ids(pm, nw=nw, :busdc)                        
            _PMACDC.constraint_power_balance_dc(pm, i, nw=nw)
        end                                          
        for i in _PM.ids(pm, nw=nw, :branchdc)
            _PMACDC.constraint_ohms_dc_branch(pm, i, nw=nw)
        end                                          
        for i in _PM.ids(pm, nw=nw, :convdc)          
            _PMACDC.constraint_converter_losses(pm, i, nw=nw)
            _PMACDC.constraint_converter_current(pm, i, nw=nw)
            _PMACDC.constraint_conv_transformer(pm, i, nw=nw)
            _PMACDC.constraint_conv_reactor(pm, i, nw=nw)
            _PMACDC.constraint_conv_filter(pm, i, nw=nw)
            if pm.ref[:it][:pm][:nw][nw][:convdc][i]["islcc"] == 1
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nw)
            end
            constraint_pvdc_droop_control_linear(pm, i, nw=nw)                                      
        end
 
    end

    objective_min_fuel_cost_scopf(pm)
    
end



"""
An SCOPF multi-period soft formulation for integrated HVAC and HVDC grid. It includes
slack variables for AC and DC grid power balance and line thermal limit constraints, 
which are minimized in the objective function.

This formulation is best used in conjunction with the contingency filters that find
violated contingencies in integrated HVAC and HVDC grid.

"""

function run_scopf_soft(data, model_constructor, solver; kwargs...)
    # _PMACDC.process_additional_data!(data)
    return _PM.solve_model(data, model_constructor, solver, build_scopf_soft; ref_extensions = [_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!, _PMSC.ref_c1!], multinetwork=true, kwargs...) 
end

function build_scopf_soft(pm::_PM.AbstractPowerModel)
    
    _PM.variable_bus_voltage(pm, nw=0)
    _PM.variable_gen_power(pm, nw=0)
    _PM.variable_branch_power(pm, nw=0)
    _PM.variable_branch_transform(pm, nw=0)
    _PM.constraint_model_voltage(pm, nw=0)

    _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=0)

    _PMACDC.variable_active_dcbranch_flow(pm, nw=0)       
    _PMACDC.variable_dcbranch_current(pm, nw=0)
    _PMACDC.variable_dc_converter(pm, nw=0)                        
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=0) 
    _PMACDC.constraint_voltage_dc(pm, nw=0)    
   
    variables_slacks(pm, nw=0)

    for i in _PM.ids(pm, nw=0, :ref_buses)                  
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :bus)                        
        constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :branch)                     
        constraint_ohms_y_oltc_pst_from(pm, i, nw=0)
        constraint_ohms_y_oltc_pst_to(pm, i, nw=0)
        _PM.constraint_voltage_angle_difference(pm, i, nw=0)
        constraint_thermal_limit_from_soft(pm, i, nw=0)
        constraint_thermal_limit_to_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :busdc)                                        
        constraint_power_balance_dc_soft(pm, i, nw=0)                                      
    end

    for i in _PM.ids(pm, nw=0, :branchdc)                                             
        constraint_ohms_dc_branch_soft(pm, i, nw=0)                                 
    end 

    for i in _PM.ids(pm, nw=0, :convdc)                                                
        _PMACDC.constraint_converter_losses(pm, i, nw=0)                                                            
        _PMACDC.constraint_conv_transformer(pm, i, nw=0)                               
        _PMACDC.constraint_conv_reactor(pm, i, nw=0)                                 
        _PMACDC.constraint_conv_filter(pm, i, nw=0)
        constraint_converter_current(pm, i, nw=0)                                     
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1                
            _PMACDC.constraint_conv_firing_angle(pm, i, nw=0)                                     
        end
        constraint_pvdc_droop_control_linear(pm, i, nw=0)                                                                        
    end                                                 

    contigency_ids = [id for id in _PM.nw_ids(pm) if id != 0]         
    
    for nw in contigency_ids

        _PM.variable_bus_voltage(pm, nw=nw, bounded=false)
        _PM.variable_gen_power(pm, nw=nw, bounded=false)
        _PM.variable_branch_power(pm, nw=nw)
        _PM.variable_branch_transform(pm, nw=nw)
        _PM.constraint_model_voltage(pm, nw=nw)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nw)
        _PMSC.variable_c1_response_delta(pm, nw=nw)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nw, bounded=false)       
        _PMACDC.variable_dcbranch_current(pm, nw=nw)
        _PMACDC.variable_dc_converter(pm, nw=nw)                        
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nw)
        _PMACDC.constraint_voltage_dc(pm, nw=nw)

        variables_slacks(pm, nw=nw)

        for i in _PM.ids(pm, nw=nw, :ref_buses)           
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = _PM.ref(pm, nw=nw, :gen_buses)
        for i in _PM.ids(pm, nw=nw, :bus)                 
            constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=nw)       

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
  
        for i in _PM.ids(pm, nw=nw, :branch)                     
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nw)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nw)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)
            constraint_thermal_limit_from_soft(pm, i, nw=nw)
            constraint_thermal_limit_to_soft(pm, i, nw=nw)
        end

        for i in _PM.ids(pm, nw=nw, :busdc)                                               
            constraint_power_balance_dc_soft(pm, i, nw=nw)                                     
        end                                                                               
        for i in _PM.ids(pm, nw=nw, :branchdc)                                             
            constraint_ohms_dc_branch_soft(pm, i, nw=nw)                                
        end                                                                                
        for i in _PM.ids(pm, nw=nw, :convdc)                                               
            _PMACDC.constraint_converter_losses(pm, i, nw=nw)                              
            constraint_converter_current(pm, i, nw=nw)                             
            _PMACDC.constraint_conv_transformer(pm, i, nw=nw)                              
            _PMACDC.constraint_conv_reactor(pm, i, nw=nw)                                  
            _PMACDC.constraint_conv_filter(pm, i, nw=nw)                                   
            if pm.ref[:it][:pm][:nw][nw][:convdc][i]["islcc"] == 1            
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nw)                                    
            end
            constraint_pvdc_droop_control_linear(pm, i, nw=nw)                                                                            
        end
 
    end
    objective_min_fuel_cost_scopf_soft(pm)
       
end

function run_scopf_soft_frq(data, model_constructor, solver; kwargs...)
    # _PMACDC.process_additional_data!(data)
    return _PM.solve_model(data, model_constructor, solver, build_scopf_soft_frq; ref_extensions = [_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!, _PMSC.ref_c1!], multinetwork=true, kwargs...) 
end

function build_scopf_soft_frq(pm::_PM.AbstractPowerModel)
    
    _PM.variable_bus_voltage(pm, nw=0)
    _PM.variable_gen_power(pm, nw=0)
    _PM.variable_branch_power(pm, nw=0)
    _PM.variable_branch_transform(pm, nw=0)
    _PM.constraint_model_voltage(pm, nw=0)

    _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=0)

    _PMACDC.variable_active_dcbranch_flow(pm, nw=0)       
    _PMACDC.variable_dcbranch_current(pm, nw=0)
    _PMACDC.variable_dc_converter(pm, nw=0)                        
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=0) 
    _PMACDC.constraint_voltage_dc(pm, nw=0)    
   
    variables_slacks(pm, nw=0)

    # variable_area_frequency(pm, nw=0)

    for i in _PM.ids(pm, nw=0, :ref_buses)                  
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :bus)                        
        constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :branch)                     
        constraint_ohms_y_oltc_pst_from(pm, i, nw=0)
        constraint_ohms_y_oltc_pst_to(pm, i, nw=0)
        _PM.constraint_voltage_angle_difference(pm, i, nw=0)
        constraint_thermal_limit_from_soft(pm, i, nw=0)
        constraint_thermal_limit_to_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :busdc)                                        
        constraint_power_balance_dc_soft(pm, i, nw=0)                                      
    end

    for i in _PM.ids(pm, nw=0, :branchdc)                                             
        constraint_ohms_dc_branch_soft(pm, i, nw=0)                                 
    end 

    for i in _PM.ids(pm, nw=0, :convdc)                                                
        _PMACDC.constraint_converter_losses(pm, i, nw=0)                                                            
        _PMACDC.constraint_conv_transformer(pm, i, nw=0)                               
        _PMACDC.constraint_conv_reactor(pm, i, nw=0)                                 
        _PMACDC.constraint_conv_filter(pm, i, nw=0)
        constraint_converter_current(pm, i, nw=0)                                     
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1                
            _PMACDC.constraint_conv_firing_angle(pm, i, nw=0)                                     
        end
        constraint_pvdc_droop_control_linear(pm, i, nw=0)                                                                        
    end                                                 

    contigency_ids = [id for id in _PM.nw_ids(pm) if id != 0]         
    
    for nw in contigency_ids

        _PM.variable_bus_voltage(pm, nw=nw, bounded=false)
        _PM.variable_gen_power(pm, nw=nw, bounded=false)
        _PM.variable_branch_power(pm, nw=nw)
        _PM.variable_branch_transform(pm, nw=nw)
        _PM.constraint_model_voltage(pm, nw=nw)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nw)
        _PMSC.variable_c1_response_delta(pm, nw=nw)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nw, bounded=false)       
        _PMACDC.variable_dcbranch_current(pm, nw=nw)
        _PMACDC.variable_dc_converter(pm, nw=nw)                        
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nw)
        _PMACDC.constraint_voltage_dc(pm, nw=nw)

        variables_slacks(pm, nw=nw)

        # variable_area_frequency(pm, nw=nw)

        for i in _PM.ids(pm, nw=nw, :ref_buses)           
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = _PM.ref(pm, nw=nw, :gen_buses)
        for i in _PM.ids(pm, nw=nw, :bus)                 
            constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=nw)       

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
  
        for i in _PM.ids(pm, nw=nw, :branch)                     
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nw)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nw)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)
            constraint_thermal_limit_from_soft(pm, i, nw=nw)
            constraint_thermal_limit_to_soft(pm, i, nw=nw)
        end

        for i in _PM.ids(pm, nw=nw, :busdc)                                               
            constraint_power_balance_dc_soft(pm, i, nw=nw)                                     
        end                                                                               
        for i in _PM.ids(pm, nw=nw, :branchdc)                                             
            constraint_ohms_dc_branch_soft(pm, i, nw=nw)                                
        end                                                                                
        for i in _PM.ids(pm, nw=nw, :convdc)                                               
            _PMACDC.constraint_converter_losses(pm, i, nw=nw)                              
            constraint_converter_current(pm, i, nw=nw)                             
            _PMACDC.constraint_conv_transformer(pm, i, nw=nw)                              
            _PMACDC.constraint_conv_reactor(pm, i, nw=nw)                                  
            _PMACDC.constraint_conv_filter(pm, i, nw=nw)                                   
            if pm.ref[:it][:pm][:nw][nw][:convdc][i]["islcc"] == 1            
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nw)                                    
            end
            constraint_pvdc_droop_control_linear(pm, i, nw=nw)                                                                            
        end
 
    end
    objective_min_fuel_cost_scopf_soft(pm)
       
end


"""
An SCOPF multi-period soft formulation for integrated HVAC and HVDC grid. It includes
slack variables for AC and DC grid power balance and line thermal limit constraints, 
which are minimized in the objective function.

This formulation is best used in conjunction with the contingency filters that find
violated contingencies in integrated HVAC and HVDC grid.

"""

function run_scopf_soft_smooth(data, model_constructor, solver; kwargs...)
    # _PMACDC.process_additional_data!(data)
    return _PM.solve_model(data, model_constructor, solver, build_scopf_soft_smooth; ref_extensions = [_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!, _PMSC.ref_c1!], multinetwork=true, kwargs...) 
end

function build_scopf_soft_smooth(pm::_PM.AbstractPowerModel)
    
    _PM.variable_bus_voltage(pm, nw=0)
    _PM.variable_gen_power(pm, nw=0)
    _PM.variable_branch_power(pm, nw=0)
    _PM.variable_branch_transform(pm, nw=0)
    _PM.constraint_model_voltage(pm, nw=0)

    _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=0)

    _PMACDC.variable_active_dcbranch_flow(pm, nw=0)       
    _PMACDC.variable_dcbranch_current(pm, nw=0)
    _PMACDC.variable_dc_converter(pm, nw=0)                        
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=0) 
    _PMACDC.constraint_voltage_dc(pm, nw=0)    
   
    variables_slacks(pm, nw=0)

    for i in _PM.ids(pm, nw=0, :ref_buses)                  
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :bus)                        
        constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :branch)                     
        constraint_ohms_y_oltc_pst_from(pm, i, nw=0)
        constraint_ohms_y_oltc_pst_to(pm, i, nw=0)
        _PM.constraint_voltage_angle_difference(pm, i, nw=0)
        constraint_thermal_limit_from_soft(pm, i, nw=0)
        constraint_thermal_limit_to_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :busdc)                                        
        constraint_power_balance_dc_soft(pm, i, nw=0)                                      
    end

    for i in _PM.ids(pm, nw=0, :branchdc)                                             
        constraint_ohms_dc_branch_soft(pm, i, nw=0)                                 
    end 

    for i in _PM.ids(pm, nw=0, :convdc)                                                
        _PMACDC.constraint_converter_losses(pm, i, nw=0)                                                            
        _PMACDC.constraint_conv_transformer(pm, i, nw=0)                               
        _PMACDC.constraint_conv_reactor(pm, i, nw=0)                                 
        _PMACDC.constraint_conv_filter(pm, i, nw=0)
        constraint_converter_current(pm, i, nw=0)                                     
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1                
            _PMACDC.constraint_conv_firing_angle(pm, i, nw=0)                                     
        end
        constraint_pvdc_droop_control_smooth(pm, i, nw=0)                                                                        
    end                                                 

    contigency_ids = [id for id in _PM.nw_ids(pm) if id != 0]         
    
    for nw in contigency_ids

        _PM.variable_bus_voltage(pm, nw=nw, bounded=false)
        _PM.variable_gen_power(pm, nw=nw, bounded=false)
        _PM.variable_branch_power(pm, nw=nw)
        _PM.variable_branch_transform(pm, nw=nw)
        _PM.constraint_model_voltage(pm, nw=nw)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nw)
        _PMSC.variable_c1_response_delta(pm, nw=nw)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nw, bounded=false)       
        _PMACDC.variable_dcbranch_current(pm, nw=nw)
        _PMACDC.variable_dc_converter(pm, nw=nw)                        
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nw)
        _PMACDC.constraint_voltage_dc(pm, nw=nw)
          
        variables_slacks(pm, nw=nw)

        for i in _PM.ids(pm, nw=nw, :ref_buses)           
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = _PM.ref(pm, nw=nw, :gen_buses)
        for i in _PM.ids(pm, nw=nw, :bus)                 
            constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=nw)       

            # for a bus with active generators, fix voltage magnitude to base case until limits are reached, then switch PV/PQ bus
            if i in gen_buses
                constraint_gen_power_reactive_response_smooth(pm, i, nw_1=0, nw_2=nw)
            end
        end

        response_gens = _PM.ref(pm, :response_gens, nw=nw)
        for (i,gen) in _PM.ref(pm, :gen, nw=nw)
            pg_base = _PM.var(pm, :pg, i, nw=0)

            # setup the smooth response function until limits are reached or fix value to base case
            if i in response_gens
                constraint_gen_power_real_response_smooth(pm, i, nw_1=0, nw_2=nw)
            else
                _PMSC.constraint_c1_gen_power_real_link(pm, i, nw_1=0, nw_2=nw)
            end
        end
  
        for i in _PM.ids(pm, nw=nw, :branch)                     
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nw)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nw)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)
            constraint_thermal_limit_from_soft(pm, i, nw=nw)
            constraint_thermal_limit_to_soft(pm, i, nw=nw)
        end

        for i in _PM.ids(pm, nw=nw, :busdc)                                               
            constraint_power_balance_dc_soft(pm, i, nw=nw)                                     
        end                                                                               
        for i in _PM.ids(pm, nw=nw, :branchdc)                                             
            constraint_ohms_dc_branch_soft(pm, i, nw=nw)                                
        end                                                                                
        for i in _PM.ids(pm, nw=nw, :convdc)                                               
            _PMACDC.constraint_converter_losses(pm, i, nw=nw)                                                          
            _PMACDC.constraint_conv_transformer(pm, i, nw=nw)                              
            _PMACDC.constraint_conv_reactor(pm, i, nw=nw)                                  
            _PMACDC.constraint_conv_filter(pm, i, nw=nw)
            constraint_converter_current(pm, i, nw=nw)                                    
            if pm.ref[:it][:pm][:nw][nw][:convdc][i]["islcc"] == 1            
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nw)                                    
            end
            constraint_pvdc_droop_control_smooth(pm, i, nw=nw)                                                                            
        end
 
    end
    objective_min_fuel_cost_scopf_soft(pm)
       
end



"""
This formulation is best used in conjunction with the contingency filters that find
violated contingencies in integrated ACDC grid.

"""

function run_scopf_soft_minlp(data, model_constructor, solver; kwargs...)
    # _PMACDC.process_additional_data!(data)
    return _PM.solve_model(data, model_constructor, solver, build_scopf_soft_minlp; ref_extensions = [_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!, _PMSC.ref_c1!], multinetwork=true, kwargs...) 
end

function build_scopf_soft_minlp(pm::_PM.AbstractPowerModel)
    
    _PM.variable_bus_voltage(pm, nw=0)
    _PM.variable_gen_power(pm, nw=0)
    _PM.variable_branch_power(pm, nw=0)
    _PM.variable_branch_transform(pm, nw=0)
    _PM.constraint_model_voltage(pm, nw=0)

    _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=0)

    _PMACDC.variable_active_dcbranch_flow(pm, nw=0)       
    _PMACDC.variable_dcbranch_current(pm, nw=0)
    _PMACDC.variable_dc_converter(pm, nw=0)                        
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=0) 
    _PMACDC.constraint_voltage_dc(pm, nw=0)    
   
    variables_slacks(pm, nw=0)
    variable_converter_droop_binary(pm, nw=0)

    for i in _PM.ids(pm, nw=0, :ref_buses)                  
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :bus)                        
        constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :branch)                     
        constraint_ohms_y_oltc_pst_from(pm, i, nw=0)
        constraint_ohms_y_oltc_pst_to(pm, i, nw=0)
        _PM.constraint_voltage_angle_difference(pm, i, nw=0)
        constraint_thermal_limit_from_soft(pm, i, nw=0)
        constraint_thermal_limit_to_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :busdc)                                        
        constraint_power_balance_dc_soft(pm, i, nw=0)                                      
    end

    for i in _PM.ids(pm, nw=0, :branchdc)                                             
        constraint_ohms_dc_branch_soft(pm, i, nw=0)                                 
    end 

    for i in _PM.ids(pm, nw=0, :convdc)                                                
        _PMACDC.constraint_converter_losses(pm, i, nw=0)                                                            
        _PMACDC.constraint_conv_transformer(pm, i, nw=0)                               
        _PMACDC.constraint_conv_reactor(pm, i, nw=0)                                 
        _PMACDC.constraint_conv_filter(pm, i, nw=0)
        constraint_converter_current(pm, i, nw=0)                                     
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1                
            _PMACDC.constraint_conv_firing_angle(pm, i, nw=0)                                     
        end
        constraint_pvdc_droop_control_milp(pm, i, nw=0)                                                                        
    end                                                 

    contigency_ids = [id for id in _PM.nw_ids(pm) if id != 0]         
    
    for nw in contigency_ids

        _PM.variable_bus_voltage(pm, nw=nw, bounded=false)
        _PM.variable_gen_power(pm, nw=nw, bounded=false)
        _PM.variable_branch_power(pm, nw=nw)
        _PM.variable_branch_transform(pm, nw=nw)
        _PM.constraint_model_voltage(pm, nw=nw)

        _PMSC.variable_c1_shunt_admittance_imaginary(pm, nw=nw)
        _PMSC.variable_c1_response_delta(pm, nw=nw)

        _PMACDC.variable_active_dcbranch_flow(pm, nw=nw, bounded=false)       
        _PMACDC.variable_dcbranch_current(pm, nw=nw)
        _PMACDC.variable_dc_converter(pm, nw=nw)                        
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nw)
        _PMACDC.constraint_voltage_dc(pm, nw=nw)
          
        variables_slacks(pm, nw=nw)
        variable_gen_response_binary(pm, nw=nw)
        variable_converter_droop_binary(pm, nw=nw)

        for i in _PM.ids(pm, nw=nw, :ref_buses)           
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = _PM.ref(pm, nw=nw, :gen_buses)
        for i in _PM.ids(pm, nw=nw, :bus)                 
            constraint_power_balance_ac_shunt_dispatch_soft(pm, i, nw=nw)       

            # for a bus with active generators, fix voltage magnitude to base case until limits are reached, then switch PV/PQ bus
            if i in gen_buses
                constraint_gen_power_reactive_response_milp(pm, i, nw_1=0, nw_2=nw)
            end
        end

        response_gens = _PM.ref(pm, :response_gens, nw=nw)
        for (i,gen) in _PM.ref(pm, :gen, nw=nw)
            pg_base = _PM.var(pm, :pg, i, nw=0)

            # setup the linear response function until limits are reached or fix value to base case
            if i in response_gens
                constraint_gen_power_real_response_milp(pm, i, nw_1=0, nw_2=nw)
            else
                _PMSC.constraint_c1_gen_power_real_link(pm, i, nw_1=0, nw_2=nw)
            end
        end
  
        for i in _PM.ids(pm, nw=nw, :branch)                     
            constraint_ohms_y_oltc_pst_from(pm, i, nw=nw)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nw)
            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)
            constraint_thermal_limit_from_soft(pm, i, nw=nw)
            constraint_thermal_limit_to_soft(pm, i, nw=nw)
        end

        for i in _PM.ids(pm, nw=nw, :busdc)                                               
            constraint_power_balance_dc_soft(pm, i, nw=nw)                                     
        end                                                                               
        for i in _PM.ids(pm, nw=nw, :branchdc)                                             
            constraint_ohms_dc_branch_soft(pm, i, nw=nw)                                
        end                                                                                
        for i in _PM.ids(pm, nw=nw, :convdc)                                               
            _PMACDC.constraint_converter_losses(pm, i, nw=nw)                                                          
            _PMACDC.constraint_conv_transformer(pm, i, nw=nw)                              
            _PMACDC.constraint_conv_reactor(pm, i, nw=nw)                                  
            _PMACDC.constraint_conv_filter(pm, i, nw=nw)
            constraint_converter_current(pm, i, nw=nw)                                    
            if pm.ref[:it][:pm][:nw][nw][:convdc][i]["islcc"] == 1            
                _PMACDC.constraint_conv_firing_angle(pm, i, nw=nw)                                    
            end
            constraint_pvdc_droop_control_milp(pm, i, nw=nw)                                                                            
        end
    end

    objective_min_fuel_cost_scopf_soft(pm)
end