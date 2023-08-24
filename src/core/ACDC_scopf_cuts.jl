
"""
An academic SCOPF formulation inspired by the ARPA-e GOC Challenge 1 specification.
Power balance and line flow constraints are strictly enforced in the first
stage and contingency stages. Contingency branch flow constraints are enforced
by PTDF cuts using the DC power flow approximation.

This formulation is used in conjunction with the contingency filters that
generate PTDF cuts.
"""
function run_acdc_scopf_cuts(file, model_constructor, solver; kwargs...)
    return _PM.solve_model(file, model_constructor, solver, build_acdc_scopf_cuts; ref_extensions = [_PMSC.ref_c1!, _PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function build_acdc_scopf_cuts(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_branch_transform(pm) 
    _PMSC.variable_c1_shunt_admittance_imaginary(pm)

    _PMACDC.variable_active_dcbranch_flow(pm)      
    _PMACDC.variable_dcbranch_current(pm)
    _PMACDC.variable_dc_converter(pm)           
    _PMACDC.variable_dcgrid_voltage_magnitude(pm)
         
    for i in _PM.ids(pm, :bus)
        _PMSC.expression_c1_bus_generation(pm, i)
        _PMSC.expression_c1_bus_withdrawal(pm, i)
    end

    _PM.constraint_model_voltage(pm)
    _PMACDC.constraint_voltage_dc(pm)  

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

        #rate = branch["rate_a"]
        rate = branch["rate_c"]
        branchdc_p_fr = _PM.var(pm, :branchdc_p_fr)
        branchdc_p_to = _PM.var(pm, :branchdc_p_to)

        JuMP.@constraint(pm.model,  sum( weight_ac * (cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut.ptdf_branch) + sum(weight_dc * branchdc_p_fr[branchdc_id] for (branchdc_id, weight_dc) in cut.dcdf_branch) <= rate)
        JuMP.@constraint(pm.model, -sum( weight_ac * (cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut.ptdf_branch) + sum(weight_dc * _PM.var(pm, :p_dcgrid, to_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut.dcdf_branch) <= rate)
        #JuMP.@constraint(pm.model,  sum( weight_ac * (cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut.ptdf_branch) <= rate)
        #JuMP.@constraint(pm.model, -sum( weight_ac * (cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut.ptdf_branch) <= rate)
        
    end
    #sum(p_dcgrid[a] for a in bus_arcs_dcgrid) + sum(pconv_dc[c] for c in bus_convs_dc) == pd

    ##### Setup Objective #####
    _PM.objective_variable_pg_cost(pm)
    # explicit network id needed because of conductor-less
    pg_cost = _PM.var(pm, :pg_cost)

    JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i,gen) in _PM.ref(pm, :gen) )
    )
end





"""
An SCOPF formulation conforming to the ARPA-e GOC Challenge 1 specification.
A DC power flow approximation is used. Power balance and line flow constraints
are strictly enforced in the first stage.  Contingency branch flow constraints
are enforced by PTDF cuts and penalized based on a conservative linear
approximation of the formulation's specification.
This formulation is used in conjunction with the contingency filters that
generate PTDF cuts.
"""
function run_acdc_scopf_cuts_soft(file, model_constructor, solver; kwargs...)
    return _PM.run_model(file, model_constructor, solver, build_acdc_scopf_cuts_soft; ref_extensions=[_PMSC.ref_c1!], kwargs...)
end

""
function build_acdc_scopf_cuts_soft(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PMSC.variable_c1_shunt_admittance_imaginary(pm)

    _PMACDC.variable_active_dcbranch_flow(pm)      
    _PMACDC.variable_dcbranch_current(pm)           
    _PMACDC.variable_dcgrid_voltage_magnitude(pm)

    variable_dc_converter_soft(pm) 

    _PMSC.variable_c1_branch_contigency_power_violation(pm)
    _PMSC.variable_c1_gen_contigency_power_violation(pm)
    _PMSC.variable_c1_gen_contigency_capacity_violation(pm)

    variable_converter_current_violation(pm)

    for i in _PM.ids(pm, :bus)
        _PMSC.expression_c1_bus_generation(pm, i)
        _PMSC.expression_c1_bus_withdrawal(pm, i)
    end

    _PM.constraint_model_voltage(pm)
    _PMACDC.constraint_voltage_dc(pm)

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        constraint_power_balance_ac_shunt_dispatch(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        _PMSC.constraint_goc_ohms_yt_from(pm, i)
        _PM.constraint_ohms_yt_to(pm, i)

        # constraint_ohms_y_oltc_pst_from(pm, i, nw=0)
        # constraint_ohms_y_oltc_pst_to(pm, i, nw=0)

        _PM.constraint_voltage_angle_difference(pm, i)

        _PM.constraint_thermal_limit_from(pm, i)
        _PM.constraint_thermal_limit_to(pm, i)
    end

    for i in _PM.ids(pm, :busdc)                                                
        constraint_power_balance_dc_soft(pm, i)      #                                
    end                                                                                
    for i in _PM.ids(pm, :branchdc)                                             
        constraint_ohms_dc_branch_soft(pm, i)                                 
    end                                                                                
    for i in _PM.ids(pm, :convdc)                                                
        _PMACDC.constraint_converter_losses(pm, i)                               
        constraint_converter_current(pm, i)                              
        _PMACDC.constraint_conv_transformer(pm, i)                               
        _PMACDC.constraint_conv_reactor(pm, i)                                 
        _PMACDC.constraint_conv_filter(pm, i)                                    
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1                
            _PMACDC.constraint_conv_firing_angle(pm, i)                                     
        end                                                                         
    end


    for (i,cut) in enumerate(_PM.ref(pm, :branch_flow_cuts))
        _PMSC.constraint_c1_branch_contingency_ptdf_thermal_limit_from_soft(pm, i)
        _PMSC.constraint_c1_branch_contingency_ptdf_thermal_limit_to_soft(pm, i)
    end

    bus_withdrawal = _PM.var(pm, :bus_wdp)

    for (i,cut) in enumerate(_PM.ref(pm, :gen_flow_cuts))
        branch = _PM.ref(pm, :branch, cut.branch_id)
        gen = _PM.ref(pm, :gen, cut.gen_id)
        gen_bus = _PM.ref(pm, :bus, gen["gen_bus"])
        gen_set = _PM.ref(pm, :area_gens)[gen_bus["area"]]
        alpha_total = sum(gen["alpha"] for (i,gen) in _PM.ref(pm, :gen) if gen["index"] != cut.gen_id && i in gen_set)

        cont_bus_injection = Dict{Int,Any}()
        for (i, bus) in _PM.ref(pm, :bus)
            inj = 0.0
            for g in _PM.ref(pm, :bus_gens, i)
                if g != cut.gen_id
                    if g in gen_set
                        inj += _PM.var(pm, :pg, g) + gen["alpha"]*_PM.var(pm, :pg, cut.gen_id)/alpha_total
                    else
                        inj += _PM.var(pm, :pg, g)
                    end
                end
            end
            cont_bus_injection[i] = inj
        end

        #rate = branch["rate_a"]
        rate = branch["rate_c"]
        JuMP.@constraint(pm.model,  sum( weight*(cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight) in cut.bus_injection) <= rate + _PM.var(pm, :gen_cont_flow_vio, i))
        JuMP.@constraint(pm.model, -sum( weight*(cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight) in cut.bus_injection) <= rate + _PM.var(pm, :gen_cont_flow_vio, i))
    end

    for (i,gen_cont) in enumerate(_PM.ref(pm, :gen_contingencies))
        #println(gen_cont)
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
    _PMSC.objective_c1_variable_pg_cost(pm)
    # explicit network id needed because of conductor-less
    pg_cost = _PM.var(pm, :pg_cost)
    branch_cont_flow_vio = _PM.var(pm, :branch_cont_flow_vio)
    gen_cont_flow_vio = _PM.var(pm, :gen_cont_flow_vio)
    gen_cont_cap_vio = _PM.var(pm, :gen_cont_cap_vio)
    i_conv_vio = _PM.var(pm, :i_conv_vio, i)

    JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i,gen) in _PM.ref(pm, :gen) ) +
        sum( 5e5*branch_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :branch_flow_cuts)) ) +
        sum( 5e5*gen_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :gen_flow_cuts)) ) + 
        sum( 5e5*gen_cont_cap_vio[i] for i in 1:length(_PM.ref(pm, :gen_contingencies)) )
    )
end
# 