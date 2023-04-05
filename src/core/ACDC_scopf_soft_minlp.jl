"""
An SCOPF multi-period soft formulation for integrated HVAC and HVDC grid. It includes
slack variables for AC and DC grid power balance and line thermal limit constraints, 
which are minimized in the objective function.

This formulation is best used in conjunction with the contingency filters that find
violated contingencies in integrated HVAC and HVDC grid.

"""

function run_scopf_soft_minlp(data, model_constructor, solver; kwargs...)
    # _PMACDC.process_additional_data!(data)
    return _PM.run_model(data, model_constructor, solver, build_scopf_soft_minlp; ref_extensions = [_PM.ref_add_on_off_va_bounds!, _PMACDC.add_ref_dcgrid!], multinetwork=true, kwargs...)
end


# enables support for v[1], required for objective_variable_pg_cost when pg is an expression
Base.getindex(v::JuMP.GenericAffExpr, i::Int64) = v

""
function build_scopf_soft_minlp(pm::_PM.AbstractPowerModel)
    
    _PM.variable_bus_voltage(pm, nw=0)
    _PM.variable_gen_power(pm, nw=0)
    _PM.variable_branch_power(pm, nw=0)
    _PM.variable_branch_transform(pm, nw=0)    
    _PMACDC.variable_active_dcbranch_flow(pm, nw=0)       
    _PMACDC.variable_dcbranch_current(pm, nw=0)           
    variable_dc_converter_n(pm, nw=0)               
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=0)   

        
    variable_branch_thermal_limit_violation(pm, nw=0)         
    variable_branchdc_thermal_limit_violation(pm, nw=0)         
    variable_power_balance_ac_positive_violation(pm, nw=0)
    variable_power_balance_ac_negative_violation(pm, nw=0)        
    variable_power_balance_dc_positive_violation(pm, nw=0)
    variable_converter_current_violation(pm, nw=0) 
         
    
    variable_dc_droop_control(pm, nw=0)
    variable_conv_droop_binary(pm, nw=0)

    _PM.constraint_model_voltage(pm, nw=0)
    _PMACDC.constraint_voltage_dc(pm, nw=0)               
    
    for i in _PM.ids(pm, nw=0, :ref_buses)                  
        _PM.constraint_theta_ref(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :bus)                        
        constraint_power_balance_ac_soft(pm, i, nw=0)
    end

    for i in _PM.ids(pm, nw=0, :branch)                     
        # _PM.constraint_ohms_yt_from(pm, i, nw=0)
        # _PM.constraint_ohms_yt_to(pm, i, nw=0)

        constraint_ohms_y_oltc_pst_from(pm, i, nw=0)
        constraint_ohms_y_oltc_pst_to(pm, i, nw=0)

        _PM.constraint_voltage_angle_difference(pm, i, nw=0)

        constraint_thermal_limit_from_soft(pm, i, nw=0)
        constraint_thermal_limit_to_soft(pm, i, nw=0)
    end


    for i in _PM.ids(pm, nw=0, :busdc)                                                # now nw=0, otherwise if nw for loop
        constraint_power_balance_dc_soft(pm, i, nw=0)                                      
    end                                                                                
    for i in _PM.ids(pm, nw=0, :branchdc)                                             
        constraint_ohms_dc_branch_soft(pm, i, nw=0)                                 
    end                                                                                
    for i in _PM.ids(pm, nw=0, :convdc)                                                
        _PMACDC.constraint_converter_losses(pm, i, nw=0)                               
        constraint_converter_current(pm, i, nw=0)                              
        _PMACDC.constraint_conv_transformer(pm, i, nw=0)                               
        _PMACDC.constraint_conv_reactor(pm, i, nw=0)                                 
        _PMACDC.constraint_conv_filter(pm, i, nw=0)                                    
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1                
            _PMACDC.constraint_conv_firing_angle(pm, i, nw=0)                                     
        end
        constraint_dc_droop_control_binary(pm, i, nw=0)                                                                           
    end
                                                                                  

    contigency_ids = [id for id in _PM.nw_ids(pm) if id != 0]         
    
    for nw in contigency_ids

        _PM.variable_bus_voltage(pm, nw=nw, bounded=true)
        _PM.variable_gen_power(pm, nw=nw, bounded=true)
        _PM.variable_branch_power(pm, nw=nw)
        _PM.variable_branch_transform(pm, nw=nw)
        _PMACDC.variable_active_dcbranch_flow(pm, nw=nw, bounded=false)       
        _PMACDC.variable_dcbranch_current(pm, nw=nw)           
        variable_dc_converter_n(pm, nw=nw)               
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nw)
        variable_c1_voltage_response(pm, nw=nw)   

        variable_branch_thermal_limit_violation(pm, nw=nw)         
        variable_branchdc_thermal_limit_violation(pm, nw=nw)         
        variable_power_balance_ac_positive_violation(pm, nw=nw) 
        variable_power_balance_ac_negative_violation(pm, nw=nw)          
        variable_power_balance_dc_positive_violation(pm, nw=nw) 
        variable_converter_current_violation(pm, nw=nw) 

        variable_dc_droop_control(pm, nw=nw)
        variable_generator_reactive_power_bounds(pm, nw=nw)

        variable_gen_response_binary(pm, nw=nw)
        variable_conv_droop_binary(pm, nw=nw)

        _PMACDC.constraint_voltage_dc(pm, nw=nw)

        _PMSC.variable_c1_response_delta(pm, nw=nw)
        variable_conv_response_delta(pm, nw=nw)

        _PM.constraint_model_voltage(pm, nw=nw)

        for i in _PM.ids(pm, nw=nw, :ref_buses)           
            _PM.constraint_theta_ref(pm, i, nw=nw)
        end

        gen_buses = _PM.ref(pm, nw=nw, :gen_buses)
        for i in _PM.ids(pm, nw=nw, :bus)                 
            constraint_power_balance_ac_soft(pm, i, nw=nw)       

            # if a bus has active generators, fix the voltage magnitude to the base case
            if i in gen_buses
                #_PMSC.constraint_c1_voltage_magnitude_link(pm, i, nw_1=0, nw_2=nw)
                constraint_gen_power_reactive_response_binary(pm, i, nw_1=0, nw_2=nw)
            end
        end


        response_gens = _PM.ref(pm, :response_gens, nw=nw)
        for (i,gen) in _PM.ref(pm, :gen, nw=nw)
            pg_base = _PM.var(pm, :pg, i, nw=0)

            # setup the linear response function or fix value to base case
            if i in response_gens
                # _PMSC.constraint_c1_gen_power_real_response(pm, i, nw_1=0, nw_2=nw)
                constraint_gen_power_real_response_binary(pm, i, nw_1=0, nw_2=nw)
            else
                _PMSC.constraint_c1_gen_power_real_link(pm, i, nw_1=0, nw_2=nw)
            end
        end

        #conv_buses = Dict(con_id => conv["busac_i"] for (con_id, conv) in _PM.ref(pm, nw=0, :convdc))
        bus_convs = Dict(conv["busac_i"] => con_id  for (con_id, conv) in _PM.ref(pm, nw=0, :convdc))
        

        for (i, bus_conv_ac_i) in bus_convs
            #constraint_conv_power_real_response_ap(pm, bus_conv_ac_i, nw_1=0, nw_2=nw)
        end

        for i in _PM.ids(pm, nw=nw, :branch)                     
            # _PM.constraint_ohms_yt_from(pm, i, nw=nw)
            # _PM.constraint_ohms_yt_to(pm, i, nw=nw)

            constraint_ohms_y_oltc_pst_from(pm, i, nw=nw)
            constraint_ohms_y_oltc_pst_to(pm, i, nw=nw)

            _PM.constraint_voltage_angle_difference(pm, i, nw=nw)

            constraint_thermal_limit_from_soft(pm, i, nw=nw)
            constraint_thermal_limit_to_soft(pm, i, nw=nw)
        end


        for i in _PM.ids(pm, nw=nw, :busdc)                                                # now nw=0, otherwise if nw for loop
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
            constraint_dc_droop_control_binary(pm, i, nw=nw)                                                                             
        end
 
    end
    objective_min_fuel_cost_scopf_soft(pm)

    
    ##### Setup Objective #####
    # _PMSC.objective_c1_variable_pg_cost_basecase(pm)
    # # explicit network id needed because of conductor-less
    # pg_cost = _PMSC.var(pm, 0, :pg_cost)

    # JuMP.@objective(pm.model, Min,
    #     sum( pg_cost[i] for (i, gen) in _PMSC.ref(pm, 0, :gen) ) +
    #     sum(
    #         sum( 5e5*_PM.var(pm, n, :bf_vio_fr, i) for i in _PM.ids(pm, n, :branch) ) +
    #         sum( 5e5*_PM.var(pm, n, :bf_vio_to, i) for i in _PM.ids(pm, n, :branch) ) + 
    #         sum( 5e5*_PM.var(pm, n, :bdcf_vio_fr, i) for i in _PM.ids(pm, n, :branchdc) ) +
    #         sum( 5e5*_PM.var(pm, n, :bdcf_vio_to, i) for i in _PM.ids(pm, n, :branchdc) ) +
    #         sum( 5e5*_PM.var(pm, n, :pb_ac_pos_vio, i) for i in 1:length(_PM.ref(pm, n, :bus)) ) +
    #         sum( 5e5*_PM.var(pm, n, :qb_ac_pos_vio, i) for i in 1:length(_PM.ref(pm, n, :bus)) ) +
    #         sum( 5e5*_PM.var(pm, n, :pb_dc_pos_vio, i) for i in 1:length(_PM.ref(pm, n, :busdc)) )
    #         for (n, nw_ref) in _PM.nws(pm) )
    # )
    
end

function objective_min_fuel_cost_scopf_soft(pm::_PM.AbstractPowerModel; kwargs...)
    model = _PM.check_gen_cost_models(pm)

    if model == 1
        return objective_min_fuel_cost_scopf_soft_pwl(pm; kwargs...)
    elseif model == 2
        return objective_min_fuel_cost_scopf_soft_polynomial(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end

end

function objective_min_fuel_cost_scopf_soft_pwl(pm::_PM.AbstractPowerModel; kwargs...)

    _PMSC.objective_c1_variable_pg_cost_basecase(pm)
    # explicit network id needed because of conductor-less
    pg_cost = _PM.var(pm, 0, :pg_cost)
    
    return JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i, gen) in _PM.ref(pm, 0, :gen) ) +
        sum(
            sum( 5e5*_PM.var(pm, n, :bf_vio_fr, i) for i in _PM.ids(pm, n, :branch) ) +
            sum( 5e5*_PM.var(pm, n, :bf_vio_to, i) for i in _PM.ids(pm, n, :branch) ) + 
            sum( 5e5*_PM.var(pm, n, :bdcf_vio_fr, i) for i in _PM.ids(pm, n, :branchdc) ) +
            sum( 5e5*_PM.var(pm, n, :bdcf_vio_to, i) for i in _PM.ids(pm, n, :branchdc) ) +
            sum( 5e5*_PM.var(pm, n, :pb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus) ) +
            sum( 5e5*_PM.var(pm, n, :pb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus) ) +
            sum( 5e5*_PM.var(pm, n, :qb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus) ) +
            sum( 5e5*_PM.var(pm, n, :qb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus) ) +
            sum( 5e5*_PM.var(pm, n, :pb_dc_pos_vio, i) for i in _PM.ids(pm, n, :busdc) ) +
            sum( 5e5*_PM.var(pm, n, :i_conv_vio, i) for i in _PM.ids(pm, n, :convdc) ) 
            for (n, nw_ref) in _PM.nws(pm) )
    )
end


function objective_min_fuel_cost_scopf_soft_polynomial(pm::_PM.AbstractPowerModel; kwargs...)
    order = _PM.calc_max_cost_index(pm.data)-1

    if order <= 2
        return objective_min_fuel_cost_scopf_soft_polynomial_linquad(pm; kwargs...)
    else
        return objective_min_fuel_cost_scopf_soft_polynomial_nl(pm; kwargs...)
    end
end


function objective_min_fuel_cost_scopf_soft_polynomial_linquad(pm::_PM.AbstractPowerModel; report::Bool=true)
    gen_cost = Dict()
    for (n, nw_ref) in _PM.nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( _PM.var(pm, n, :pg, i)[c] for c in _PM.conductor_ids(pm, n) )

            if length(gen["cost"]) == 1
                gen_cost[(n,i)] = gen["cost"][1]
            elseif length(gen["cost"]) == 2
                gen_cost[(n,i)] = gen["cost"][1]*pg + gen["cost"][2]
            elseif length(gen["cost"]) == 3
                gen_cost[(n,i)] = gen["cost"][1]*pg^2 + gen["cost"][2]*pg + gen["cost"][3]
            else
                gen_cost[(n,i)] = 0.0
            end
        end
    end

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( gen_cost[(0,i)] for (i,gen) in _PM.ref(pm, 0, :gen) )) +
        sum(
            sum( 5e5*_PM.var(pm, n, :bf_vio_fr, i) for i in _PM.ids(pm, n, :branch) ) +
            sum( 5e5*_PM.var(pm, n, :bf_vio_to, i) for i in _PM.ids(pm, n, :branch) ) + 
            sum( 5e5*_PM.var(pm, n, :bdcf_vio_fr, i) for i in _PM.ids(pm, n, :branchdc) ) +
            sum( 5e5*_PM.var(pm, n, :bdcf_vio_to, i) for i in _PM.ids(pm, n, :branchdc) ) +
            sum( 5e5*_PM.var(pm, n, :pb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus))  +
            sum( 5e5*_PM.var(pm, n, :pb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus))  +
            sum( 5e5*_PM.var(pm, n, :qb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus))  +
            sum( 5e5*_PM.var(pm, n, :qb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus))  +
            sum( 5e5*_PM.var(pm, n, :pb_dc_pos_vio, i) for i in _PM.ids(pm, n, :busdc) ) +
            sum( 5e5*_PM.var(pm, n, :i_conv_vio, i) for i in _PM.ids(pm, n, :convdc) ) 
        for (n, nw_ref) in _PM.nws(pm))
    )
end



function objective_min_fuel_cost_scopf_soft_polynomial_nl(pm::_PM.AbstractPowerModel; report::Bool=true)
    gen_cost = Dict()
    for (n, nw_ref) in _PM.nws(pm)
        for (i,gen) in nw_ref[:gen]
            pg = sum( _PM.var(pm, n, :pg, i)[c] for c in _PM.conductor_ids(pm, n))

            cost_rev = reverse(gen["cost"])
            if length(cost_rev) == 1
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1])
            elseif length(cost_rev) == 2
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg)
            elseif length(cost_rev) == 3
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2)
            elseif length(cost_rev) >= 4
                cost_rev_nl = cost_rev[4:end]
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, cost_rev[1] + cost_rev[2]*pg + cost_rev[3]*pg^2 + sum( v*pg^(d+3) for (d,v) in enumerate(cost_rev_nl)) )
            else
                gen_cost[(n,i)] = JuMP.@NLexpression(pm.model, 0.0)
            end
        end
    end

    bf_vio_fr = _PM.var(pm, :bf_vio_fr) 
    bf_vio_to = _PM.var(pm, :bf_vio_to)  
    bdcf_vio_fr = _PM.var(pm, :bdcf_vio_fr) 
    bdcf_vio_to = _PM.var(pm, :bdcf_vio_to) 
    pb_ac_pos_vio = _PM.var(pm, :pb_ac_pos_vio) 
    pb_ac_neg_vio = _PM.var(pm, :pb_ac_neg_vio) 
    qb_ac_pos_vio = _PM.var(pm, :qb_ac_pos_vio) 
    qb_ac_neg_vio = _PM.var(pm, :qb_ac_neg_vio) 
    pb_dc_pos_vio = _PM.var(pm, :pb_dc_pos_vio) 
    i_conv_vio = _PM.var(pm, :i_conv_vio)

    return JuMP.@NLobjective(pm.model, Min,
        sum(
            sum( gen_cost[(0,i)] for (i,gen) in _PM.ref(pm, 0, :gen) )) +
            sum(
                sum( 5e5*bf_vio_fr[(n,i)] for i in _PM.ids(pm, n, :branch) ) +
                sum( 5e5*bf_vio_to[(n,i)] for i in _PM.ids(pm, n, :branch) ) + 
                sum( 5e5*bdcf_vio_fr[(n,i)] for i in _PM.ids(pm, n, :branchdc) ) +
                sum( 5e5*bdcf_vio_to[(n,i)] for i in _PM.ids(pm, n, :branchdc) ) +
                sum( 5e5*pb_ac_pos_vio[(n,i)] for i in 1:length(_PM.ref(pm, n, :bus)) ) +
                sum( 5e5*pb_ac_neg_vio[(n,i)] for i in 1:length(_PM.ref(pm, n, :bus)) ) +
                sum( 5e5*qb_ac_pos_vio[(n,i)] for i in 1:length(_PM.ref(pm, n, :bus)) ) +
                sum( 5e5*qb_ac_neg_vio[(n,i)] for i in 1:length(_PM.ref(pm, n, :bus)) ) +
                sum( 5e5*pb_dc_pos_vio[(n,i)] for i in 1:length(_PM.ref(pm, n, :busdc)) ) +
                sum( 5e5*i_conv_vio[(n,i)] for i in _PM.ids(pm, n, :convdc) ) 
        for (n, nw_ref) in _PM.nws(pm))
    )
end




function run_c1_scopf_cuts_soft_GM1(file, model_constructor, solver; kwargs...)
    return _PM.run_model(file, model_constructor, solver, build_c1_scopf_cuts_soft_GM1; ref_extensions=[_PMSC.ref_c1!], kwargs...)
end


function build_c1_scopf_cuts_soft_GM1(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)

    _PMSC.variable_c1_shunt_admittance_imaginary(pm)

    _PMSC.variable_c1_branch_contigency_power_violation(pm)
    _PMSC.variable_c1_gen_contigency_power_violation(pm)
    _PMSC.variable_c1_gen_contigency_capacity_violation(pm)

    for i in ids(pm, :bus)
        _PMSC.expression_c1_bus_generation(pm, i)
        _PMSC.expression_c1_bus_withdrawal(pm, i)
    end


    _PM.constraint_model_voltage(pm)

    for i in ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in ids(pm, :bus)
        _PMSC.constraint_c1_power_balance_shunt_dispatch(pm, i)
    end

    for i in ids(pm, :branch)
        _PMSC.constraint_goc_ohms_yt_from(pm, i)
        _PM.constraint_ohms_yt_to(pm, i)

        _PM.constraint_voltage_angle_difference(pm, i)

        _PM.constraint_thermal_limit_from(pm, i)
        _PM.constraint_thermal_limit_to(pm, i)
    end


    for (i,cut) in enumerate(ref(pm, :branch_flow_cuts))
        _PMSC.constraint_c1_branch_contingency_ptdf_thermal_limit_from_soft(pm, i)
        _PMSC.constraint_c1_branch_contingency_ptdf_thermal_limit_to_soft(pm, i)
    end

    bus_withdrawal = _PMSC.var(pm, :bus_wdp)

    for (i,cut) in enumerate(_PMSC.ref(pm, :gen_flow_cuts))
        branch = _PMSC.ref(pm, :branch, cut.branch_id)
        gen = _PMSC.ref(pm, :gen, cut.gen_id)
        gen_bus = _PMSC.ref(pm, :bus, gen["gen_bus"])
        gen_set = _PMSC.ref(pm, :area_gens)[gen_bus["area"]]
        alpha_total = sum(gen["alpha"] for (i,gen) in _PMSC.ref(pm, :gen) if gen["index"] != cut.gen_id && i in gen_set)

        cont_bus_injection = Dict{Int,Any}()
        for (i, bus) in _PMSC.ref(pm, :bus)
            inj = 0.0
            for g in _PMSC.ref(pm, :bus_gens, i)
                if g != cut.gen_id
                    if g in gen_set
                        inj += _PMSC.var(pm, :pg, g) + gen["alpha"]*_PMSC.var(pm, :pg, cut.gen_id)/alpha_total
                    else
                        inj += _PMSC.var(pm, :pg, g)
                    end
                end
            end
            cont_bus_injection[i] = inj
        end

        #rate = branch["rate_a"]
        rate = branch["rate_c"]
        JuMP.@constraint(pm.model,  sum( weight*(cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight) in cut.bus_injection) <= rate + _PMSC.var(pm, :gen_cont_flow_vio, i))
        JuMP.@constraint(pm.model, -sum( weight*(cont_bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight) in cut.bus_injection) <= rate + _PMSC.var(pm, :gen_cont_flow_vio, i))
    end

    for (i,gen_cont) in enumerate(_PMSC.ref(pm, :gen_contingencies))
        #println(gen_cont)
        gen = _PMSC.ref(pm, :gen, gen_cont.idx)
        gen_bus = _PMSC.ref(pm, :bus, gen["gen_bus"])
        gen_set = _PMSC.ref(pm, :area_gens)[gen_bus["area"]]
        response_gens = Dict(g => _PMSC.ref(pm, :gen, g) for g in gen_set if g != gen_cont.idx)

        # factor of 1.2 accounts for losses in a DC model
        #@constraint(pm.model, sum(gen["pmax"] - var(pm, :pg, g) for (g,gen) in response_gens) >= 1.2*var(pm, :pg, gen_cont.idx))
        JuMP.@constraint(pm.model, _PMSC.var(pm, :gen_cont_cap_vio, i) + sum(gen["pmax"] - _PMSC.var(pm, :pg, g) for (g,gen) in response_gens) >= _PMSC.var(pm, :pg, gen_cont.idx))
        #@constraint(pm.model, sum(gen["pmin"] - var(pm, :pg, g) for (g,gen) in response_gens) <= var(pm, :pg, gen_cont.idx))
    end

    ##### Setup Objective #####
    _PM.objective_variable_pg_cost(pm)
    # explicit network id needed because of conductor-less
    pg_cost = _PMSC.var(pm, :pg_cost)
    branch_cont_flow_vio = _PMSC.var(pm, :branch_cont_flow_vio)
    gen_cont_flow_vio = _PMSC.var(pm, :gen_cont_flow_vio)
    gen_cont_cap_vio = _PMSC.var(pm, :gen_cont_cap_vio)

    JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i,gen) in _PMSC.ref(pm, :gen) ) +
        sum( 5e5*branch_cont_flow_vio[i] for i in 1:length(_PMSC.ref(pm, :branch_flow_cuts)) ) +
        sum( 5e5*gen_cont_flow_vio[i] for i in 1:length(_PMSC.ref(pm, :gen_flow_cuts)) ) + 
        sum( 5e5*gen_cont_cap_vio[i] for i in 1:length(_PMSC.ref(pm, :gen_contingencies)) )
    )
end