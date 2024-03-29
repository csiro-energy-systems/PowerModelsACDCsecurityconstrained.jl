
"""
This formulation is used in conjunction with the contingency filters that
generate PTDF and DCFD cuts.
"""
function run_acdc_scopf_cuts(file, model_constructor, solver; kwargs...)
    return _PM.solve_model(file, model_constructor, solver, build_acdc_scopf_cuts; ref_extensions = [_PMSC.ref_c1!, _PMACDC.add_ref_dcgrid!], kwargs...)
end


function build_acdc_scopf_cuts(pm::_PM.AbstractPowerModel)

    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_branch_transform(pm)
    _PM.constraint_model_voltage(pm) 

    _PMACDC.variable_active_dcbranch_flow(pm)      
    _PMACDC.variable_dcbranch_current(pm)
    _PMACDC.variable_dc_converter(pm)           
    _PMACDC.variable_dcgrid_voltage_magnitude(pm)
    _PMACDC.constraint_voltage_dc(pm) 

    _PMSC.variable_c1_shunt_admittance_imaginary(pm)
         
    for i in _PM.ids(pm, :bus)
        _PMSC.expression_c1_bus_generation(pm, i)
        _PMSC.expression_c1_bus_withdrawal(pm, i)
    end

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        constraint_power_balance_ac_shunt_dispatch(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        expression_branch_powerflow(pm,i)
        _PMSC.constraint_goc_ohms_yt_from(pm, i)
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
        expression_branchdc_powerflow(pm, i)                                 
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
        constraint_pvdc_droop_control_linear(pm, i)                                                                           
    end

    for (i,cut) in enumerate(_PM.ref(pm, :branch_flow_cuts))
        constraint_branch_contingency_ptdf_dcdf_thermal_limit_from(pm, i)
        constraint_branch_contingency_ptdf_dcdf_thermal_limit_to(pm, i)
    end

    for (i,cut) in enumerate(_PM.ref(pm, :branchdc_flow_cuts))
        constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from(pm, i)
        constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to(pm, i)
    end

    bus_withdrawal = _PM.var(pm, :bus_wdp)
    branch_dc = _PM.ref(pm, :branchdc)
    fr_idx = [(i, branchdc["fbusdc"], branchdc["tbusdc"]) for (i,branchdc) in branch_dc] 
    to_idx = [(i, branchdc["tbusdc"], branchdc["fbusdc"]) for (i,branchdc) in branch_dc]

    for (i,cut) in enumerate(_PM.ref(pm, :gen_flow_cuts))
        branch = _PM.ref(pm, :branch, cut.branch_id)
        ploss = _PM.ref(pm, :ploss)
        ploss_df = _PM.ref(pm, :ploss_df, i)
        gen = _PM.ref(pm, :gen, cut.gen_cont_id)
        gen_bus = _PM.ref(pm, :bus, gen["gen_bus"])
        gen_set = _PM.ref(pm, :area_gens)[gen_bus["area"]]
        alpha_total = sum(gen["alpha"] for (i,gen) in _PM.ref(pm, :gen) if gen["index"] != cut.gen_cont_id && i in gen_set)

        cont_bus_injection = Dict{Int,Any}()
        for (i, bus) in _PM.ref(pm, :bus)
            inj = 0.0
            for g in _PM.ref(pm, :bus_gens, i)
                if g != cut.gen_cont_id
                    if g in gen_set
                        inj += _PM.var(pm, :pg, g) + gen["alpha"]*_PM.var(pm, :pg, cut.gen_cont_id)/alpha_total
                    else
                        inj += _PM.var(pm, :pg, g)
                    end
                end
            end
            cont_bus_injection[i] = inj
        end
        
        rate = branch["rate_c"]

        JuMP.@constraint(pm.model,  sum( weight_ac * (cont_bus_injection[bus_id] - (bus_withdrawal[bus_id] + ploss_df*ploss)) for (bus_id, weight_ac) in cut.ptdf_branch) + sum(weight_dc * _PM.var(pm, :p_dcgrid, fr_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut.dcdf_branch) <= rate)
        JuMP.@constraint(pm.model, -sum( weight_ac * (cont_bus_injection[bus_id] - (bus_withdrawal[bus_id] + ploss_df*ploss)) for (bus_id, weight_ac) in cut.ptdf_branch) + sum(weight_dc * _PM.var(pm, :p_dcgrid, to_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut.dcdf_branch) <= rate)
     
    end

    ##### Setup Objective #####
    objective_min_fuel_cost_scopf_cuts(pm)

end



"""
This formulation is used in conjunction with the contingency filters that
generate PTDF and DCDF cuts.
"""
function run_acdc_scopf_cuts_soft(file, model_constructor, solver; kwargs...)
    return _PM.solve_model(file, model_constructor, solver, build_acdc_scopf_cuts_soft; ref_extensions = [_PMSC.ref_c1!, _PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function build_acdc_scopf_cuts_soft(pm::_PM.AbstractPowerModel)
    
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_branch_transform(pm)
    _PM.constraint_model_voltage(pm)

    _PMACDC.variable_active_dcbranch_flow(pm)     
    _PMACDC.variable_dcbranch_current(pm)    
    _PMACDC.variable_dc_converter(pm)       
    _PMACDC.variable_dcgrid_voltage_magnitude(pm)
    _PMACDC.constraint_voltage_dc(pm)

    _PMSC.variable_c1_shunt_admittance_imaginary(pm)
    _PMSC.variable_c1_branch_contigency_power_violation(pm)
    _PMSC.variable_c1_gen_contigency_power_violation(pm)
    _PMSC.variable_c1_gen_contigency_capacity_violation(pm)
 
    variable_branchdc_contigency_power_violation(pm)
    
    for i in _PM.ids(pm, :bus)
        _PMSC.expression_c1_bus_generation(pm, i)
        _PMSC.expression_c1_bus_withdrawal(pm, i)
    end

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        constraint_power_balance_ac_shunt_dispatch(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        expression_branch_powerflow(pm,i)
        _PMSC.constraint_goc_ohms_yt_from(pm, i)
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
        constraint_pvdc_droop_control_linear(pm, i)                                                                         
    end

    for (i,cut) in enumerate(_PM.ref(pm, :branch_flow_cuts))
        constraint_branch_contingency_ptdf_dcdf_thermal_limit_from_soft(pm, i)
        constraint_branch_contingency_ptdf_dcdf_thermal_limit_to_soft(pm, i)
    end

    for (i,cut) in enumerate(_PM.ref(pm, :branchdc_flow_cuts))
        constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from_soft(pm, i)
        constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to_soft(pm, i)
    end

    bus_withdrawal = _PM.var(pm, :bus_wdp)
    branch_dc = _PM.ref(pm, :branchdc)
    fr_idx = [(i, branchdc["fbusdc"], branchdc["tbusdc"]) for (i,branchdc) in branch_dc] 
    to_idx = [(i, branchdc["tbusdc"], branchdc["fbusdc"]) for (i,branchdc) in branch_dc]

    for (i,cut) in enumerate(_PM.ref(pm, :gen_flow_cuts))
        branch = _PM.ref(pm, :branch, cut.branch_id)
        ploss = _PM.ref(pm, :ploss)
        ploss_df = _PM.ref(pm, :ploss_df, i)
        gen = _PM.ref(pm, :gen, cut.gen_cont_id)
        gen_bus = _PM.ref(pm, :bus, gen["gen_bus"])
        gen_set = _PM.ref(pm, :area_gens)[gen_bus["area"]]
        alpha_total = sum(gen["alpha"] for (i,gen) in _PM.ref(pm, :gen) if gen["index"] != cut.gen_cont_id && i in gen_set)

        cont_bus_injection = Dict{Int,Any}()
        for (i, bus) in _PM.ref(pm, :bus)
            inj = 0.0
            for g in _PM.ref(pm, :bus_gens, i)
                if g != cut.gen_cont_id
                    if g in gen_set
                        inj += _PM.var(pm, :pg, g) + gen["alpha"]*_PM.var(pm, :pg, cut.gen_cont_id)/alpha_total
                    else
                        inj += _PM.var(pm, :pg, g)
                    end
                end
            end
            cont_bus_injection[i] = inj
        end
        
        rate = branch["rate_c"]

        JuMP.@constraint(pm.model,  sum( weight_ac * (cont_bus_injection[bus_id] - (bus_withdrawal[bus_id] + ploss_df*ploss)) for (bus_id, weight_ac) in cut.ptdf_branch) + sum(weight_dc * _PM.var(pm, :p_dcgrid, fr_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut.dcdf_branch) <= rate + _PM.var(pm, :gen_cont_flow_vio, i))
        JuMP.@constraint(pm.model, -sum( weight_ac * (cont_bus_injection[bus_id] - (bus_withdrawal[bus_id] + ploss_df*ploss)) for (bus_id, weight_ac) in cut.ptdf_branch) + sum(weight_dc * _PM.var(pm, :p_dcgrid, to_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut.dcdf_branch) <= rate + _PM.var(pm, :gen_cont_flow_vio, i))
       
    end

    for (i,gen_cont) in enumerate(_PM.ref(pm, :gen_contingencies))
        gen = _PM.ref(pm, :gen, gen_cont.idx)
        gen_bus = _PM.ref(pm, :bus, gen["gen_bus"])
        gen_set = _PM.ref(pm, :area_gens)[gen_bus["area"]]
        response_gens = Dict(g => _PM.ref(pm, :gen, g) for g in gen_set if g != gen_cont.idx)

        # factor of 1.2 accounts for losses in a DC model
        #JuMP.@constraint(pm.model, sum(gen["pmax"] - var(pm, :pg, g) for (g,gen) in response_gens) >= 1.2*var(pm, :pg, gen_cont.idx))
        JuMP.@constraint(pm.model, _PM.var(pm, :gen_cont_cap_vio, i) + sum(gen["pmax"] - _PM.var(pm, :pg, g) for (g,gen) in response_gens) >= _PM.var(pm, :pg, gen_cont.idx))
        #JuMP.@constraint(pm.model, sum(gen["pmin"] - var(pm, :pg, g) for (g,gen) in response_gens) <= var(pm, :pg, gen_cont.idx))
    end

    ##### Setup Objective #####
    objective_min_fuel_cost_scopf_cuts_soft(pm)

end