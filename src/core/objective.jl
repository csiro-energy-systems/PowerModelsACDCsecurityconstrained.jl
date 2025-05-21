function objective_min_fuel_cost_scopf(pm::_PM.AbstractPowerModel; kwargs...)
    model = check_gen_cost_models(pm)

    if model == 1
        return objective_min_fuel_cost_scopf_pwl(pm; kwargs...)
    elseif model == 2
        return objective_min_fuel_cost_scopf_polynomial(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end
end

function objective_min_fuel_cost_scopf_pwl(pm::_PM.AbstractPowerModel; kwargs...)

    _PMSC.objective_c1_variable_pg_cost_basecase(pm)
    
    pg_cost = _PM.var(pm, 0, :pg_cost)

    return JuMP.@objective(pm.model, Min,
    sum( pg_cost[i] for (i, gen) in _PM.ref(pm, 0, :gen) ) )

end


function objective_min_fuel_cost_scopf_polynomial(pm::_PM.AbstractPowerModel; kwargs...)
    order = _PM.calc_max_cost_index(pm.data)-1

    if order <= 2
        return objective_min_fuel_cost_scopf_polynomial_linquad(pm; kwargs...)
    else
        return objective_min_fuel_cost_scopf_polynomial_nl(pm; kwargs...)
    end
end


function objective_min_fuel_cost_scopf_polynomial_linquad(pm::_PM.AbstractPowerModel; report::Bool=true)
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
            sum( gen_cost[(0,i)] for (i,gen) in _PM.ref(pm, 0, :gen) )) )
end



function objective_min_fuel_cost_scopf_polynomial_nl(pm::_PM.AbstractPowerModel; report::Bool=true)
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

    return JuMP.@NLobjective(pm.model, Min,
        sum(
            sum( gen_cost[(0,i)] for (i,gen) in _PM.ref(pm, 0, :gen) )) )
end





function objective_min_fuel_cost_scopf_soft(pm::_PM.AbstractPowerModel; kwargs...)
    model = check_gen_cost_models(pm)

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
    
    pg_cost = _PM.var(pm, 0, :pg_cost)

    return JuMP.@objective(pm.model, Min,
    sum( pg_cost[i] for (i, gen) in _PM.ref(pm, 0, :gen) ) +
    sum(
        sum( 5E5*_PM.var(pm, n, :bf_vio_fr, i) for i in _PM.ids(pm, n, :branch) ) +
        sum( 5E5*_PM.var(pm, n, :bf_vio_to, i) for i in _PM.ids(pm, n, :branch) ) + 
        sum( 5E5*_PM.var(pm, n, :bdcf_vio_fr, i) for i in _PM.ids(pm, n, :branchdc) ) +
        sum( 5E5*_PM.var(pm, n, :bdcf_vio_to, i) for i in _PM.ids(pm, n, :branchdc) ) +
        sum( 5E5*_PM.var(pm, n, :pb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus) ) +
        sum( 5E5*_PM.var(pm, n, :pb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus) ) +
        sum( 5E5*_PM.var(pm, n, :qb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus) ) +
        sum( 5E5*_PM.var(pm, n, :qb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus) ) +
        sum( 5E5*_PM.var(pm, n, :pb_dc_pos_vio, i) for i in _PM.ids(pm, n, :busdc) ) +
        sum( 5E5*_PM.var(pm, n, :i_conv_vio, i) for i in _PM.ids(pm, n, :convdc) ) 
        for (n, nw_ref) in _PM.nws(pm) )
    )

end
function objective_min_fuel_and_slack_cost_scopf_soft_pwl(pm::_PM.AbstractPowerModel; kwargs...)

    _PMSC.objective_c1_variable_pg_cost_basecase(pm)
    pg_cost = _PM.var(pm, 0, :pg_cost)

    objective_variable_slack_cost_pwl(pm)

    return JuMP.@objective(pm.model, Min,
        sum( pg_cost[i] for (i, gen) in _PM.ref(pm, 0, :gen) ) +
        sum(
            sum( _PM.var(pm, :bf_vio_fr_cost, i)*_PM.var(pm, n, :bf_vio_fr, i) for i in _PM.ids(pm, n, :branch) ) +
            sum( _PM.var(pm, n, :bf_vio_to_cost, i)*_PM.var(pm, n, :bf_vio_to, i) for i in _PM.ids(pm, n, :branch) ) + 
            sum( _PM.var(pm, n, :bdcf_vio_fr_cost, i)*_PM.var(pm, n, :bdcf_vio_fr, i) for i in _PM.ids(pm, n, :branchdc) ) +
            sum( _PM.var(pm, n, :bdcf_vio_to_cost, i)*_PM.var(pm, n, :bdcf_vio_to, i) for i in _PM.ids(pm, n, :branchdc) ) +
            sum( _PM.var(pm, n, :pb_ac_pos_vio_cost, i)*_PM.var(pm, n, :pb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus) ) +
            sum( _PM.var(pm, n, :pb_ac_neg_vio_cost, i)*_PM.var(pm, n, :pb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus) ) +
            sum( _PM.var(pm, n, :qb_ac_pos_vio_cost, i)*_PM.var(pm, n, :qb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus) ) +
            sum( _PM.var(pm, n, :qb_ac_neg_vio_cost, i)*_PM.var(pm, n, :qb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus) ) +
            sum( _PM.var(pm, n, :pb_dc_pos_vio_cost, i)*_PM.var(pm, n, :pb_dc_pos_vio, i) for i in _PM.ids(pm, n, :busdc) ) +
            sum( _PM.var(pm, n, :i_conv_vio_cost, i)*_PM.var(pm, n, :i_conv_vio, i) for i in _PM.ids(pm, n, :convdc) ) 
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


"adds slack cost variables and constraints"
function objective_variable_slack_cost_pwl(pm::_PM.AbstractPowerModel)

        objective_variable_branch_flow_slack_fr_cost_pwl(pm)
        objective_variable_branch_flow_slack_to_cost_pwl(pm)
        objective_variable_branchdc_flow_slack_fr_cost_pwl(pm)
        objective_variable_branchdc_flow_slack_to_cost_pwl(pm)
        objective_variable_power_balance_active_ac_slack_pos_cost_pwl(pm)
        objective_variable_power_balance_active_ac_slack_neg_cost_pwl(pm)
        objective_variable_power_balance_reactive_ac_slack_pos_cost_pwl(pm)
        objective_variable_power_balance_reactive_ac_slack_neg_cost_pwl(pm)
        objective_variable_power_balance_dc_slack_pos_cost_pwl(pm)
        objective_variable_converter_current_limit_slack_cost_pwl(pm)

end

function objective_variable_branch_flow_slack_fr_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        bf_vio_fr_cost = _PM.var(pm, nw)[:bf_vio_fr_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :branch)
            slack_vars = [_PM.var(pm, nw, :bf_vio_fr, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            bf_vio_fr_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branch, :bf_vio_fr_cost, _PM.ids(pm, nw, :branch), bf_vio_fr_cost)
    end
end
function objective_variable_branch_flow_slack_to_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        bf_vio_to_cost = _PM.var(pm, nw)[:bf_vio_to_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :branch)
            slack_vars = [_PM.var(pm, nw, :bf_vio_to, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            bf_vio_to_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branch, :bf_vio_to_cost, _PM.ids(pm, nw, :branch), bf_vio_to_cost)
    end
end
function objective_variable_branchdc_flow_slack_fr_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        bdcf_vio_fr_cost = _PM.var(pm, nw)[:bdcf_vio_fr_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :branchdc)
            slack_vars = [_PM.var(pm, nw, :bdcf_vio_fr, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            bdcf_vio_fr_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branchdc, :bdcf_vio_fr_cost, _PM.ids(pm, nw, :branchdc), bdcf_vio_fr_cost)
    end
end
function objective_variable_branchdc_flow_slack_to_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        bdcf_vio_to_cost = _PM.var(pm, nw)[:bdcf_vio_to_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :branchdc)
            slack_vars = [_PM.var(pm, nw, :bdcf_vio_to, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            bdcf_vio_to_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branchdc, :bdcf_vio_to_cost, _PM.ids(pm, nw, :branchdc), bdcf_vio_to_cost)
    end
end
function objective_variable_power_balance_active_ac_slack_pos_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        pb_ac_pos_vio_cost = _PM.var(pm, nw)[:pb_ac_pos_vio_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :bus)
            slack_vars = [_PM.var(pm, nw, :pb_ac_pos_vio, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            pb_ac_pos_vio_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :pb_ac_pos_vio_cost, _PM.ids(pm, nw, :bus), pb_ac_pos_vio_cost)
    end
end
function objective_variable_power_balance_active_ac_slack_neg_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        pb_ac_neg_vio_cost = _PM.var(pm, nw)[:pb_ac_neg_vio_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :bus)
            slack_vars = [_PM.var(pm, nw, :pb_ac_neg_vio, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            pb_ac_neg_vio_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :pb_ac_neg_vio_cost, _PM.ids(pm, nw, :bus), pb_ac_neg_vio_cost)
    end
end
function objective_variable_power_balance_reactive_ac_slack_pos_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        qb_ac_pos_vio_cost = _PM.var(pm, nw)[:qb_ac_pos_vio_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :bus)
            slack_vars = [_PM.var(pm, nw, :qb_ac_pos_vio, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            qb_ac_pos_vio_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :qb_ac_pos_vio_cost, _PM.ids(pm, nw, :bus), qb_ac_pos_vio_cost)
    end
end
function objective_variable_power_balance_reactive_ac_slack_neg_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        qb_ac_neg_vio_cost = _PM.var(pm, nw)[:qb_ac_neg_vio_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :bus)
            slack_vars = [_PM.var(pm, nw, :qb_ac_neg_vio, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            qb_ac_neg_vio_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :qb_ac_neg_vio_cost, _PM.ids(pm, nw, :bus), qb_ac_neg_vio_cost)
    end
end
function objective_variable_power_balance_dc_slack_pos_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        pb_dc_pos_vio_cost = _PM.var(pm, nw)[:pb_dc_pos_vio_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :busdc)
            slack_vars = [_PM.var(pm, nw, :pb_dc_pos_vio, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            pb_dc_pos_vio_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :busdc, :pb_dc_pos_vio_cost, _PM.ids(pm, nw, :busdc), pb_dc_pos_vio_cost)
    end
end
function objective_variable_converter_current_limit_slack_cost_pwl(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (nw, nw_ref) in _PM.nws(pm)
        i_conv_vio_cost = _PM.var(pm, nw)[:i_conv_vio_cost] = Dict{Int,Any}()

        for i in _PM.ids(pm, nw, :convdc)
            slack_vars = [_PM.var(pm, nw, :i_conv_vio, i)[c] for c in _PM.conductor_ids(pm, nw)]
            slackmin = sum(JuMP.lower_bound.(slack_vars))
            slackmax = sum(JuMP.upper_bound.(slack_vars))
            
            # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
            points = _PM.calc_pwl_points( _PM.ref(pm, nw, :slack, 1)["ncost"],  _PM.ref(pm, nw, :slack, 1)["cost"], slackmin, slackmax)

            slack_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name="$(nw)_slack_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(slack_cost_lambda) == 1.0)

            slack_expr = 0.0
            slack_cost_expr = 0.0
            for (i,point) in enumerate(points)
                slack_expr += point.mw*slack_cost_lambda[i]
                slack_cost_expr += point.cost*slack_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, slack_expr == sum(slack_vars))
            i_conv_vio_cost[i] = slack_cost_expr
        end

        report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :i_conv_vio_cost, _PM.ids(pm, nw, :convdc), i_conv_vio_cost)
    end
end


# objective for ac-dc scopf with ptdf and dcdf cuts

function objective_min_fuel_cost_scopf_cuts(pm::_PM.AbstractPowerModel; kwargs...)
    model = check_gen_cost_models(pm)

    if model == 1
        return objective_min_fuel_cost_scopf_cuts_pwl(pm; kwargs...)
    elseif model == 2
        return objective_min_fuel_cost_scopf_cuts_polynomial(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end
end

function objective_min_fuel_cost_scopf_cuts_pwl(pm::_PM.AbstractPowerModel; kwargs...)

    _PMSC.objective_c1_variable_pg_cost_basecase(pm)
    
    pg_cost = _PM.var(pm, 0, :pg_cost)

    return JuMP.@objective(pm.model, Min, sum( pg_cost[i] for (i, gen) in _PM.ref(pm, 0, :gen) ) )
end


function objective_min_fuel_cost_scopf_cuts_polynomial(pm::_PM.AbstractPowerModel; kwargs...)
    order = _PM.calc_max_cost_index(pm.data)-1

    if order <= 2
        return objective_min_fuel_cost_scopf_cuts_polynomial_linquad(pm; kwargs...)
    else
        return objective_min_fuel_cost_scopf_cuts_polynomial_nl(pm; kwargs...)
    end
end


function objective_min_fuel_cost_scopf_cuts_polynomial_linquad(pm::_PM.AbstractPowerModel; report::Bool=true)
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
            sum( gen_cost[(0,i)] for (i,gen) in _PM.ref(pm, 0, :gen) ))
    )
end



function objective_min_fuel_cost_scopf_cuts_polynomial_nl(pm::_PM.AbstractPowerModel; report::Bool=true)
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


    return JuMP.@NLobjective(pm.model, Min,
        sum(
            sum( gen_cost[(0,i)] for (i,gen) in _PM.ref(pm, 0, :gen) )) 
    )
end

# objective for ac-dc scopf with ptdf and dcdf cuts soft

function objective_min_fuel_cost_scopf_cuts_soft(pm::_PM.AbstractPowerModel; kwargs...)
    model = check_gen_cost_models(pm)

    if model == 1
        return objective_min_fuel_cost_scopf_cuts_soft_pwl(pm; kwargs...)
    elseif model == 2
        return objective_min_fuel_cost_scopf_cuts_soft_polynomial(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end
end

function objective_min_fuel_cost_scopf_cuts_soft_pwl(pm::_PM.AbstractPowerModel; kwargs...)

    # _PMSC.objective_c1_variable_pg_cost(pm)
    _PM.objective_variable_pg_cost(pm)
    
    pg_cost = _PM.var(pm, :pg_cost)
    branch_cont_flow_vio = _PM.var(pm, :branch_cont_flow_vio)
    gen_cont_flow_vio = _PM.var(pm, :gen_cont_flow_vio)
    gen_cont_cap_vio = _PM.var(pm, :gen_cont_cap_vio)
    # i_conv_vio = _PM.var(pm, :i_conv_vio)
    branchdc_cont_flow_vio = _PM.var(pm, :branchdc_cont_flow_vio)

    return JuMP.@objective(pm.model, Min,
    sum( pg_cost[i] for (i,gen) in _PM.ref(pm, :gen) ) +
    sum( 5e5*branch_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :branch_flow_cuts)) ) +
    sum( 5e5*gen_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :gen_flow_cuts)) ) + 
    sum( 5e5*gen_cont_cap_vio[i] for i in 1:length(_PM.ref(pm, :gen_contingencies)) ) +
    sum( 5e5*branchdc_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :branchdc_flow_cuts)) )
)
end


function objective_min_fuel_cost_scopf_cuts_soft_polynomial(pm::_PM.AbstractPowerModel; kwargs...)
    order = _PM.calc_max_cost_index(pm.data)-1

    if order <= 2
        return objective_min_fuel_cost_scopf_cuts_soft_polynomial_linquad(pm; kwargs...)
    else
        return objective_min_fuel_cost_scopf_cuts_soft_polynomial_nl(pm; kwargs...)
    end
end


function objective_min_fuel_cost_scopf_cuts_soft_polynomial_linquad(pm::_PM.AbstractPowerModel; report::Bool=true)
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
    branch_cont_flow_vio = _PM.var(pm, :branch_cont_flow_vio)
    gen_cont_flow_vio = _PM.var(pm, :gen_cont_flow_vio)
    gen_cont_cap_vio = _PM.var(pm, :gen_cont_cap_vio)
    # i_conv_vio = _PM.var(pm, :i_conv_vio)
    branchdc_cont_flow_vio = _PM.var(pm, :branchdc_cont_flow_vio)

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( gen_cost[(0,i)] for (i,gen) in _PM.ref(pm, 0, :gen) )) +
        sum( 5e5*branch_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :branch_flow_cuts)) ) +
        sum( 5e5*gen_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :gen_flow_cuts)) ) + 
        sum( 5e5*gen_cont_cap_vio[i] for i in 1:length(_PM.ref(pm, :gen_contingencies)) ) +
        sum( 5e5*branchdc_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :branchdc_flow_cuts)) )
    )
end



function objective_min_fuel_cost_scopf_cuts_soft_polynomial_nl(pm::_PM.AbstractPowerModel; report::Bool=true)
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

    branch_cont_flow_vio = _PM.var(pm, :branch_cont_flow_vio)
    gen_cont_flow_vio = _PM.var(pm, :gen_cont_flow_vio)
    gen_cont_cap_vio = _PM.var(pm, :gen_cont_cap_vio)
    # i_conv_vio = _PM.var(pm, :i_conv_vio)
    branchdc_cont_flow_vio = _PM.var(pm, :branchdc_cont_flow_vio)

    return JuMP.@NLobjective(pm.model, Min,
        sum(
            sum( gen_cost[(0,i)] for (i,gen) in _PM.ref(pm, 0, :gen) )) +
            sum( 5e5*branch_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :branch_flow_cuts)) ) +
            sum( 5e5*gen_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :gen_flow_cuts)) ) + 
            sum( 5e5*gen_cont_cap_vio[i] for i in 1:length(_PM.ref(pm, :gen_contingencies)) ) +
            sum( 5e5*branchdc_cont_flow_vio[i] for i in 1:length(_PM.ref(pm, :branchdc_flow_cuts)) )
    )
end


# FCAS

function objective_min_cost(pm::_PM.AbstractPowerModel; kwargs...)
    model = check_gen_cost_models(pm)

    if model == 1
        return objective_pwl(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 are supported at this time, given cost model type of $(model)")
    end

end

function objective_pwl(pm::_PM.AbstractPowerModel; kwargs...)
    objective_variable_pg_cost(pm; kwargs...)
    objective_variable_pd_cost(pm; kwargs...)
    objective_variable_fcas_cost(pm; kwargs...)

    return JuMP.@objective(pm.model, Max,
        sum(
            sum( _PM.var(pm, n, :pg_cost, i) for (i,gen) in nw_ref[:gen]) +
            sum(_PM.var(pm, n, Symbol("gen_$(fcas_name(fcas_service))_cost"), gen) for fcas_service = values(fcas_services) for gen = keys(get_fcas_participants(nw_ref[:gen], fcas_service))) +
            sum(_PM.var(pm, n, Symbol("load_$(fcas_name(fcas_service))_cost"), load) for fcas_service = values(fcas_services) for load = keys(get_fcas_participants(nw_ref[:load], fcas_service))) -
            sum( _PM.var(pm, n, :pd_cost, i) for (i,load) in get_dispatchable_participants(nw_ref[:load]))
       for (n, nw_ref) in _PM.nws(pm))
    )
end


function objective_min_fuel_cost_mn_scopf_soft(pm::_PM.AbstractPowerModel; kwargs...)
    model = check_gen_cost_models(pm)

    if model == 1
        return objective_min_fuel_cost_mn_scopf_soft_pwl(pm; kwargs...)
    elseif model == 2
        return objective_min_fuel_cost_mn_scopf_soft_polynomial(pm; kwargs...)
    else
        Memento.error(_LOGGER, "Only cost models of types 1 and 2 are supported at this time, given cost model type of $(model)")
    end
end

function objective_min_fuel_cost_mn_scopf_soft_pwl(pm::_PM.AbstractPowerModel; kwargs...)


    return JuMP.@objective(pm.model, Min,
    sum(
    sum( _PM.var(pm, nh, :pg_cost, i) for (i, gen) in _PM.ref(pm, nh, :gen) ) for nh in pm.ref[:it][:pm][:hour_ids] ) +
    sum(
        sum( 5E5*_PM.var(pm, n, :bf_vio_fr, i) for i in _PM.ids(pm, n, :branch) ) +
        sum( 5E5*_PM.var(pm, n, :bf_vio_to, i) for i in _PM.ids(pm, n, :branch) ) + 
        sum( 5E5*_PM.var(pm, n, :bdcf_vio_fr, i) for i in _PM.ids(pm, n, :branchdc) ) +
        sum( 5E5*_PM.var(pm, n, :bdcf_vio_to, i) for i in _PM.ids(pm, n, :branchdc) ) +
        sum( 5E5*_PM.var(pm, n, :pb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus) ) +
        sum( 5E5*_PM.var(pm, n, :pb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus) ) +
        sum( 5E5*_PM.var(pm, n, :qb_ac_pos_vio, i) for i in _PM.ids(pm, n, :bus) ) +
        sum( 5E5*_PM.var(pm, n, :qb_ac_neg_vio, i) for i in _PM.ids(pm, n, :bus) ) +
        sum( 5E5*_PM.var(pm, n, :pb_dc_pos_vio, i) for i in _PM.ids(pm, n, :busdc) ) +
        sum( 5E5*_PM.var(pm, n, :i_conv_vio, i) for i in _PM.ids(pm, n, :convdc) ) 
        for (n, nw_ref) in _PM.nws(pm) )
    )

end


function objective_variable_pg_cost_pwl(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, report::Bool=true)
    pg_cost = _PM.var(pm, nw)[:pg_cost] = Dict{Int,Any}()

    for (i,gen) in _PM.ref(pm, nw, :gen)
        pg_vars = [_PM.var(pm, nw, :pg, i)[c] for c in _PM.conductor_ids(pm, nw)]
        pmin = sum(JuMP.lower_bound.(pg_vars))
        pmax = sum(JuMP.upper_bound.(pg_vars))

        # note pmin/pmax may be different from gen["pmin"]/gen["pmax"] in the on/off case
        points = _PM.calc_pwl_points(gen["ncost"], gen["cost"], pmin, pmax)

        pg_cost_lambda = JuMP.@variable(pm.model,
            [i in 1:length(points)], base_name="$(nw)_pg_cost_lambda",
            lower_bound = 0.0,
            upper_bound = 1.0
        )
        JuMP.@constraint(pm.model, sum(pg_cost_lambda) == 1.0)

        pg_expr = 0.0
        pg_cost_expr = 0.0
        for (i,point) in enumerate(points)
            pg_expr += point.mw*pg_cost_lambda[i]
            pg_cost_expr += point.cost*pg_cost_lambda[i]
        end
        JuMP.@constraint(pm.model, pg_expr == sum(pg_vars))
        pg_cost[i] = pg_cost_expr
    end

    report && _PM.sol_component_value(pm, nw, :gen, :pg_cost, _PM.ids(pm, nw, :gen), pg_cost)
end


"""
Checks that all generator cost models are of the same type
"""
function check_gen_cost_models(pm::_PM.AbstractPowerModel)
    model = nothing

    for (n, nw_ref) in _PM.nws(pm)
        for (i,gen) in nw_ref[:gen]
            if haskey(gen, "cost")
                if model == nothing
                    model = gen["model"]
                else
                    if gen["model"] != model
                        Memento.error(_LOGGER, "cost models are inconsistent, the typical model is $(model) however model $(gen["model"]) is given on generator $(i)")
                    end
                end
            else
                Memento.error(_LOGGER, "no cost given for generator $(i)")
            end
        end
    end

    return model
end