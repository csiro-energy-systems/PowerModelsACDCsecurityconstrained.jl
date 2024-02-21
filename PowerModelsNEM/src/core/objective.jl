function objective_min_cost(pm::_PM.AbstractPowerModel; kwargs...)
    model = _PM.check_gen_cost_models(pm)

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



