#Adding new variables for including voilations into the objective function 

function variable_c1_branch_contigency_power_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    branch_cont_flow_vio = var(pm, nw)[:branch_cont_flow_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :branch_flow_cuts))], base_name="$(nw)_branch_cont_flow_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :branch_flow_cuts))
            JuMP.set_lower_bound(branch_cont_flow_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :gen, :pg_delta, ids(pm, nw, :gen), pg_delta)
end


function variable_c1_gen_contigency_power_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    gen_cont_flow_vio = var(pm, nw)[:gen_cont_flow_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :gen_flow_cuts))], base_name="$(nw)_gen_cont_flow_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :gen_flow_cuts))
            JuMP.set_lower_bound(gen_cont_flow_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :gen, :pg_delta, ids(pm, nw, :gen), pg_delta)
end


function variable_c1_gen_contigency_capacity_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    gen_cont_cap_vio = var(pm, nw)[:gen_cont_cap_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :gen_contingencies))], base_name="$(nw)_gen_cont_cap_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :gen_contingencies))
            JuMP.set_lower_bound(gen_cont_cap_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :gen, :pg_delta, ids(pm, nw, :gen), pg_delta)
end


"""
defines power from generators at each bus, varies in contingencies
"""
function expression_c1_bus_generation(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    if !haskey(var(pm, nw), :bus_pg)
        var(pm, nw)[:bus_pg] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw), :bus_qg)
        var(pm, nw)[:bus_qg] = Dict{Int,Any}()
    end

    bus = ref(pm, nw, :bus, i)
    bus_gens = ref(pm, nw, :bus_gens, i)

    expression_c1_bus_generation(pm, nw, i, bus_gens)
end


"""
defines power from non-generator components at each bus, static in contingencies
"""
function expression_c1_bus_withdrawal(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    if !haskey(var(pm, nw), :bus_wdp)
        var(pm, nw)[:bus_wdp] = Dict{Int,Any}()
    end
    if !haskey(var(pm, nw), :bus_wdq)
        var(pm, nw)[:bus_wdq] = Dict{Int,Any}()
    end

    bus = ref(pm, nw, :bus, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)
    bus_storage = ref(pm, nw, :bus_storage, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    expression_c1_bus_withdrawal(pm, nw, i, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
end









function variable_branch_contigency_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    branch_cont_vio = var(pm, nw)[:branch_cont_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :branch_cuts))], base_name="$(nw)_branch_cont_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :branch_cuts))
            JuMP.set_lower_bound(branch_cont_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :branch_cont_vio, :branch_cuts )
end


function variable_gen_contigency_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    gen_cont_vio = var(pm, nw)[:gen_cont_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :gen_cuts))], base_name="$(nw)_gen_cont_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :gen_cuts))
            JuMP.set_lower_bound(gen_cont_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :gen_cont_vio, :gen_cuts)
end


function variable_branchdc_contigency_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    branchdc_cont_vio = var(pm, nw)[:branchdc_cont_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :branchdc_cuts))], base_name="$(nw)_branchdc_cont_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branchdc_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :branchdc_cuts))
            JuMP.set_lower_bound(branchdc_cont_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :branchdc_cont_vio, :branchdc_cuts )
end

""
function variable_c1_shunt_admittance_imaginary(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    bs = var(pm, nw)[:bs] = @variable(pm.model,
        [i in ids(pm, nw, :shunt_var)], base_name="$(nw)_bs",
        start = _PM.comp_start_value(ref(pm, nw, :shunt, i), "bs_start")
    )

    if bounded
        for i in ids(pm, nw, :shunt_var)
            shunt = ref(pm, nw, :shunt, i)
            JuMP.set_lower_bound(bs[i], shunt["bmin"])
            JuMP.set_upper_bound(bs[i], shunt["bmax"])
        end
    end

    report && _PM.sol_component_value(pm, nw, :shunt, :bs, ids(pm, nw, :shunt_var), bs)
end

""
function variable_c1_shunt_admittance_imaginary(pm::_PM.AbstractWModels; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    bs = var(pm, nw)[:bs] = @variable(pm.model,
        [i in ids(pm, nw, :shunt_var)], base_name="$(nw)_bs",
        start = _PM.comp_start_value(ref(pm, nw, :shunt, i), "bs_start")
    )

    wbs = var(pm, nw)[:wbs] = @variable(pm.model,
        [i in ids(pm, nw, :shunt_var)], base_name="$(nw)_wbs",
        start = 0.0
    )

    if bounded
        for i in ids(pm, nw, :shunt_var)
            shunt = ref(pm, nw, :shunt, i)
            JuMP.set_lower_bound(bs[i], shunt["bmin"])
            JuMP.set_upper_bound(bs[i], shunt["bmax"])
        end
    end

    report && _PM.sol_component_value(pm, nw, :shunt, :bs, ids(pm, nw, :shunt_var), bs)
    report && _PM.sol_component_value(pm, nw, :shunt, :wbs, ids(pm, nw, :shunt_var), wbs)
end