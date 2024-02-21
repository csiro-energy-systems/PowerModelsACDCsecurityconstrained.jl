"""
    objective_variable_pg_cost(pm, report)

Creates generator cost variables required by the model objective function
"""
function objective_variable_pg_cost(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (n, nw_ref) in _PM.nws(pm)
        pg_cost = _PM.var(pm, n)[:pg_cost] = Dict{Int,Any}()

        gens = get_dispatchable_participants(_PM.ref(pm, n, :gen))
        for (i,gen) in gens
            pg_vars = [_PM.var(pm, n, :pg, i)[c] for c in _PM.conductor_ids(pm, n)]
            pmin = sum(JuMP.lower_bound.(pg_vars))
            pmax = sum(JuMP.upper_bound.(pg_vars))
            cost = get_cost_data(pm, gen)

            points = _PM.calc_pwl_points(gen["ncost"], cost, pmin, pmax)

            pg_cost_lambda = JuMP.@variable(pm.model,
                [j in 1:length(points)], base_name="$(n)_$(i)_pg_cost_lambda",
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

        report && _PM.sol_component_value(pm, n, :gen, :pg_cost, keys(gens), pg_cost)
    end
end

"""
    objective_variable_pd_cost(pm, report)

Creates load cost variables required by the model objective function
"""
function objective_variable_pd_cost(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (n, nw_ref) in _PM.nws(pm)
        pd_cost = _PM.var(pm, n)[:pd_cost] = Dict{Int,Any}()
        pd_value = _PM.var(pm, n)[:pd_value] = Dict{Int,Any}()

        loads = get_dispatchable_participants(_PM.ref(pm, n, :load))
        for (i, load) in loads
            pd_vars = [_PM.var(pm, n, :pd, i)[c] for c in _PM.conductor_ids(pm, n)]
            pmin = sum(JuMP.lower_bound.(pd_vars))
            pmax = sum(JuMP.upper_bound.(pd_vars))
            cost = get_cost_data(pm, load)

            points = _PM.calc_pwl_points(load["ncost"], cost, pmin, pmax)

            pd_cost_lambda = JuMP.@variable(pm.model,
                [i in 1:length(points)], base_name = "$(n)_pd_cost_lambda",
                lower_bound = 0.0,
                upper_bound = 1.0
            )
            JuMP.@constraint(pm.model, sum(pd_cost_lambda) == 1.0)

            pd_expr = 0.0
            pd_cost_expr = 0.0
            for (i, point) in enumerate(points)
                pd_expr += point.mw * pd_cost_lambda[i]
                pd_cost_expr += point.cost * pd_cost_lambda[i]
            end
            JuMP.@constraint(pm.model, pd_expr == sum(pd_vars))
            pd_cost[i] = pd_cost_expr
            pd_value[i] = pd_expr
        end

        report && _PM.sol_component_value(pm, n, :load, :pd_cost, keys(loads), pd_cost)
     end
end

function variable_load_power(pm::_PM.AbstractPowerModel; kwargs...)
    variable_load_power_real(pm; kwargs...)
end

"""
    variable_load_power_real(pm; nw, bounded, report)

Creates variables for load real/active power
"""
function variable_load_power_real(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    loads = get_dispatchable_participants(_PM.ref(pm, nw, :load))
    
    pd = _PM.var(pm, nw)[:pd] = JuMP.@variable(pm.model,
        [i in keys(loads)], base_name = "$(nw)_pd",
        start = _PM.comp_start_value(loads[i], "pd_start")
    )

    if bounded
        for (i, load) in loads
            JuMP.set_lower_bound(pd[i], load["pmin"])
            JuMP.set_upper_bound(pd[i], load["pmax"])
        end
    end

    report && _PM.sol_component_value(pm, nw, :load, :pd, keys(loads), pd)
end

"""
    objective_variable_fcas_cost(pm, report)

Creates FCAS cost variables for generators and loads that are required by the model objective function
"""
function objective_variable_fcas_cost(pm::_PM.AbstractPowerModel, report::Bool=true)
    for (n, nw_ref) in _PM.nws(pm)
        for (s, service) in fcas_services
            service_key = service.id
            fcas_gen_cost_vars = _PM.var(pm, n)[Symbol("gen_$(fcas_name(service))_cost")] = Dict{Int,Any}()

            gens = get_fcas_participants(_PM.ref(pm, n, :gen), service)
            for (j, gen) in gens
                if !haskey(gen, "fcas_cost") || !haskey(gen["fcas_cost"], service_key)
                    fcas_gen_cost_vars[j] = 0
                    continue
                end

                fcas_cost = gen["fcas_cost"][service_key]

                fcas_vars = [_PM.var(pm, n, Symbol("gen_$(fcas_name(service))"), j)[c] for c in _PM.conductor_ids(pm, n)]
                pmin = sum(JuMP.lower_bound.(fcas_vars))
                pmax = sum(JuMP.upper_bound.(fcas_vars))

                points = _PM.calc_pwl_points(fcas_cost["ncost"], fcas_cost["cost"], pmin, pmax)

                cost_lambda = JuMP.@variable(pm.model,
                    [i in 1:length(points)], base_name = "$(n)_$(fcas_name(service))_cost_lambda",
                    lower_bound = 0.0,
                    upper_bound = 1.0
                )

                JuMP.@constraint(pm.model, sum(cost_lambda) == 1.0)

                expr = 0.0
                cost_expr = 0.0
                for (i, point) in enumerate(points)
                    expr += point.mw * cost_lambda[i]
                    cost_expr += point.cost * cost_lambda[i]
                end

                JuMP.@constraint(pm.model, expr == sum(fcas_vars))
                fcas_gen_cost_vars[j] = cost_expr
            end

            report && _PM.sol_component_value(pm, n, :gen, Symbol("gen_$(fcas_name(service))_cost"), keys(gens), fcas_gen_cost_vars)

            fcas_load_cost_vars = _PM.var(pm, n)[Symbol("load_$(fcas_name(service))_cost")] = Dict{Int,Any}()

            loads = get_fcas_participants(_PM.ref(pm, n, :load), service)
            for (j, load) in loads
                if !haskey(load, "fcas_cost") || !haskey(load["fcas_cost"], service_key)
                    fcas_load_cost_vars[j] = 0
                    continue
                end

                fcas_cost = load["fcas_cost"][service_key]

                fcas_vars = [_PM.var(pm, n, Symbol("load_$(fcas_name(service))"), j)[c] for c in _PM.conductor_ids(pm, n)]
                pmin = sum(JuMP.lower_bound.(fcas_vars))
                pmax = sum(JuMP.upper_bound.(fcas_vars))

                points = _PM.calc_pwl_points(fcas_cost["ncost"], fcas_cost["cost"], pmin, pmax)

                cost_lambda = JuMP.@variable(pm.model,
                    [i in 1:length(points)], base_name = "$(n)_$(fcas_name(service))_cost_lambda",
                    lower_bound = 0.0,
                    upper_bound = 1.0
                )
                JuMP.@constraint(pm.model, sum(cost_lambda) == 1.0)

                expr = 0.0
                cost_expr = 0.0
                for (i, point) in enumerate(points)
                    expr += point.mw * cost_lambda[i]
                    cost_expr += point.cost * cost_lambda[i]
                end

                JuMP.@constraint(pm.model, expr == sum(fcas_vars))
                fcas_load_cost_vars[j] = cost_expr
            end

            report && _PM.sol_component_value(pm, n, :load, Symbol("load_$(fcas_name(service))_cost"), keys(loads), fcas_load_cost_vars)            
        end
    end
end

"""
    variable_fcas(pm, nw, report)

Creates variables for all enabled FCAS participants
"""
function variable_fcas(pm::_PM.AbstractPowerModel, nw::Int=_PM.nw_id_default, report::Bool=true)
    for  (i, service) in fcas_services
        gens = get_fcas_participants(_PM.ref(pm, nw, :gen), service)
        gen_vars = _PM.var(pm, nw)[Symbol("gen_$(fcas_name(service))")] = JuMP.@variable(pm.model,
            [i in keys(gens)], base_name = "$(nw)_gen_$(fcas_name(service))", lower_bound = 0,
            start = 0.0
        )

        for (n, gen) in gens
            JuMP.set_upper_bound(gen_vars[n], gen["fcas"][service.id]["amax"])
        end

        report && _PM.sol_component_value(pm, nw, :gen, Symbol("gen_$(fcas_name(service))"), keys(gens), gen_vars)

        loads = get_fcas_participants(_PM.ref(pm, nw, :load), service)
        load_vars = _PM.var(pm, nw)[Symbol("load_$(fcas_name(service))")] = JuMP.@variable(pm.model,
            [i in keys(loads)], base_name = "$(nw)_load_$(fcas_name(service))", lower_bound = 0,
            start = 0.0
        )

        for (n, load) in loads
            JuMP.set_upper_bound(load_vars[n], load["fcas"][service.id]["amax"])
        end

        report && _PM.sol_component_value(pm, nw, :load, Symbol("load_$(fcas_name(service))"), keys(loads), load_vars)
    end
end