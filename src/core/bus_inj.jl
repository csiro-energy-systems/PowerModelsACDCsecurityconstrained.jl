"returns a sorted list of branchdc flow violations"
function branchdc_c1_violations_sorted(network::Dict{String,<:Any}, solution::Dict{String,<:Any}; rate_keydc="rateC")
    branchdc_violations = []

    if haskey(solution, "branchdc")
        for (i,branchdc) in network["branchdc"]
            if branchdc["status"] != 0
                branchdc_sol = solution["branchdc"][i]

                s_fr = abs(branchdc_sol["pf"])
                s_to = abs(branchdc_sol["pt"])

                #if !isnan(branch_sol["qf"]) && !isnan(branch_sol["qt"])
                #    s_fr = sqrt(branch_sol["pf"]^2 + branch_sol["qf"]^2)
                #    s_to = sqrt(branch_sol["pt"]^2 + branch_sol["qt"]^2)
                #end

                smdc_vio = 0.0

                rating = branchdc[rate_keydc]
                if s_fr > rating
                    smdc_vio = s_fr - rating
                end
                if s_to > rating && s_to - rating > smdc_vio
                    smdc_vio = s_to - rating
                end

                if smdc_vio > 0.0
                    push!(branchdc_violations, (branchdc_id=branchdc["index"], smdc_vio=smdc_vio))
                end
            end
        end
    end

    sort!(branchdc_violations, by=(x) -> -x.smdc_vio)

    return branchdc_violations
end

#################################################################################################################################################################################################
#################################################################################################################################################################################################
##############################  New Soft Variables
#################################################################################################################################################################################################
function variable_branch_thermal_limit_violation(pm::_PM.AbstractPowerModel; kwargs...)
    variable_branch_thermal_limit_violation_from(pm::_PM.AbstractPowerModel; kwargs...)
    variable_branch_thermal_limit_violation_to(pm::_PM.AbstractPowerModel; kwargs...)
end
function variable_branch_thermal_limit_violation_from(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    bf_vio_fr = _PM.var(pm, nw)[:bf_vio_fr] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :branch)], base_name="$(nw)_bf_vio_fr",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )                                                                                                 #[i in 1:length(_PM.ref(pm, nw, :branch))]   

    if bounded
        for i in _PM.ids(pm, nw, :branch)
            JuMP.set_lower_bound(bf_vio_fr[i], 0.0)
            JuMP.set_upper_bound(bf_vio_fr[i], 1e1)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :branch, :branch_flow_vio, branch_flow_vio)
end
function variable_branch_thermal_limit_violation_to(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    bf_vio_to = _PM.var(pm, nw)[:bf_vio_to] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :branch)], base_name="$(nw)_bf_vio_to",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in _PM.ids(pm, nw, :branch)
            JuMP.set_lower_bound(bf_vio_to[i], 0.0)
            JuMP.set_upper_bound(bf_vio_to[i], 1e1)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :branch, :branch_flow_vio, branch_flow_vio)
end
#################################################################################################################################################################################################
function variable_branchdc_thermal_limit_violation(pm::_PM.AbstractPowerModel; kwargs...)
    variable_branchdc_thermal_limit_violation_from(pm::_PM.AbstractPowerModel; kwargs...)
    variable_branchdc_thermal_limit_violation_to(pm::_PM.AbstractPowerModel; kwargs...)
end
function variable_branchdc_thermal_limit_violation_from(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    bdcf_vio_fr = _PM.var(pm, nw)[:bdcf_vio_fr] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :branchdc)], base_name="$(nw)_bdcf_vio_fr",
    )

    if bounded
        for i in _PM.ids(pm, nw, :branchdc)
            JuMP.set_lower_bound(bdcf_vio_fr[i], 0.0)
            JuMP.set_upper_bound(bdcf_vio_fr[i], 1e1)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :branchdc, :branchdc_flow_vio, branchdc_flow_vio)
end 
function variable_branchdc_thermal_limit_violation_to(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    bdcf_vio_to = _PM.var(pm, nw)[:bdcf_vio_to] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :branchdc)], base_name="$(nw)_bdcf_vio_to",
    )

    if bounded
        for i in _PM.ids(pm, nw, :branchdc)
            JuMP.set_lower_bound(bdcf_vio_to[i], 0.0)
            JuMP.set_upper_bound(bdcf_vio_to[i], 1e1)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :branchdc, :branchdc_flow_vio, branchdc_flow_vio)
end
#################################################################################################################################################################################################
function variable_power_balance_ac_positive_violation(pm::_PM.AbstractPowerModel; kwargs...)
    variable_power_balance_ac_positive_violation_real(pm::_PM.AbstractPowerModel; kwargs...)
    variable_power_balance_ac_positive_violation_imag(pm::_PM.AbstractPowerModel; kwargs...) 
end   
function variable_power_balance_ac_positive_violation_real(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pb_ac_pos_vio = _PM.var(pm, nw)[:pb_ac_pos_vio] = JuMP.@variable(pm.model, [i in 1:length(_PM.ref(pm, nw, :bus))], base_name="$(nw)_pb_ac_pos_vio",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :bus))
        JuMP.set_lower_bound(pb_ac_pos_vio[i], 0.0)
        JuMP.set_upper_bound(pb_ac_pos_vio[i], 1e1)
        end
    end

end 
function variable_power_balance_ac_positive_violation_imag(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    qb_ac_pos_vio = _PM.var(pm, nw)[:qb_ac_pos_vio] = JuMP.@variable(pm.model, [i in 1:length(_PM.ref(pm, nw, :bus))], base_name="$(nw)_qb_ac_pos_vio",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :bus))
        JuMP.set_lower_bound(qb_ac_pos_vio[i], 0.0)
        JuMP.set_upper_bound(qb_ac_pos_vio[i], 1e1)
        end
    end

end
#################################################################################################################################################################################################
function variable_power_balance_dc_positive_violation(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pb_dc_pos_vio = _PM.var(pm, nw)[:pb_dc_pos_vio] = JuMP.@variable(pm.model,
        [i in 1:length(_PM.ref(pm, nw, :busdc))], base_name="$(nw)_pb_dc_pos_vio",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :busdc))
            JuMP.set_lower_bound(pb_dc_pos_vio[i], 0.0)
            JuMP.set_upper_bound(pb_dc_pos_vio[i], 1e1)
        end
    end

end 
#################################################################################################################################################################################################
############################## New Soft Constraints
#################################################################################################################################################################################################
function constraint_power_balance_ac_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    bus = _PM.ref(pm, nw, :bus, i)
    bus_arcs = _PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = _PM.ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = _PM.ref(pm, nw, :bus_gens, i)
    bus_convs_ac = _PM.ref(pm, nw, :bus_convs_ac, i)
    bus_loads = _PM.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PM.ref(pm, nw, :bus_shunts, i)

    pd = Dict(k => _PM.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => _PM.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_power_balance_ac_soft(pm, nw, i, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
end
############## acp.jl ###################################################################################################################################################################################
function constraint_power_balance_ac_soft(pm::_PM.AbstractACPModel, n::Int,  i::Int, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
    vm = _PM.var(pm, n,  :vm, i)
    p = _PM.var(pm, n,  :p)
    q = _PM.var(pm, n,  :q)
    pg = _PM.var(pm, n,  :pg)
    qg = _PM.var(pm, n,  :qg)
    pconv_grid_ac = _PM.var(pm, n,  :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n,  :qconv_tf_fr)
    pb_ac_pos_vio = _PM.var(pm, n, :pb_ac_pos_vio, i)
    qb_ac_pos_vio = _PM.var(pm, n, :qb_ac_pos_vio, i)

    JuMP.@NLconstraint(pm.model, pb_ac_pos_vio  + sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens)   - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*vm^2)
    JuMP.@NLconstraint(pm.model, qb_ac_pos_vio  + sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac)  == sum(qg[g] for g in bus_gens)  - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*vm^2)
end
############## dcp.jl ###################################################################################################################################################################################
function constraint_power_balance_ac_soft(pm::_PM.AbstractDCPModel, n::Int,  i::Int, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
    p = _PM.var(pm, n, :p)
    pg = _PM.var(pm, n, :pg)
    pconv_ac = _PM.var(pm, n, :pconv_ac)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    v = 1
    pb_ac_pos_vio = _PM.var(pm, n, :pb_ac_pos_vio, i)

    JuMP.@constraint(pm.model, pb_ac_pos_vio + sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
end
############## lpac.jl ###################################################################################################################################################################################
function constraint_power_balance_ac_soft(pm::_PM.AbstractLPACModel, n::Int,  i::Int, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
    phi = _PM.var(pm, n, :phi, i)
    p = _PM.var(pm, n, :p)
    q = _PM.var(pm, n, :q)
    pg = _PM.var(pm, n, :pg)
    qg = _PM.var(pm, n, :qg)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n, :qconv_tf_fr)
    pb_ac_pos_vio = _PM.var(pm, n, :pb_ac_pos_vio, i)
    qb_ac_pos_vio = _PM.var(pm, n, :qb_ac_pos_vio, i)

    JuMP.@constraint(pm.model, pb_ac_pos_vio + sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens)   - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*(1.0 + 2*phi))
    JuMP.@constraint(pm.model, qb_ac_pos_vio + sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac)  == sum(qg[g] for g in bus_gens)   - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*(1.0 + 2*phi))
end
############## shared.jl ###################################################################################################################################################################################
function constraint_power_balance_ac_soft(pm::_PM.AbstractWModels, n::Int,  i::Int, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, pd, qd, gs, bs)
    w = _PM.var(pm, n, :w, i)
    p = _PM.var(pm, n, :p)
    q = _PM.var(pm, n, :q)
    pg = _PM.var(pm, n, :pg)
    qg = _PM.var(pm, n, :qg)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n, :qconv_tf_fr)
    pb_ac_pos_vio = _PM.var(pm, n, :pb_ac_pos_vio, i)
    qb_ac_pos_vio = _PM.var(pm, n, :qb_ac_pos_vio, i)

    JuMP.@constraint(pm.model, pb_ac_pos_vio + sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens)  - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*w)
    JuMP.@constraint(pm.model, qb_ac_pos_vio + sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac)  == sum(qg[g] for g in bus_gens)  - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*w)
end
#################################################################################################################################################################################################
#################################################################################################################################################################################################
function constraint_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_from_soft(pm, nw, i, f_idx, branch["rate_a"])
    end
end
############## acp.jl ###################################################################################################################################################################################
function constraint_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, f_idx, rate_a)
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)
    bf_vio_fr = _PM.var(pm, n, :bf_vio_fr, i)

    JuMP.@constraint(pm.model, p_fr^2 + q_fr^2 <= rate_a^2 + bf_vio_fr )
end
############## SecondOrderCone ###################################################################################################################################################################################
function constraint_thermal_limit_from_soft(pm::_PM.AbstractConicModels, n::Int, i::Int, f_idx, rate_a)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    bf_vio_fr = _PM.var(pm, n, :bf_vio_fr, i)

    JuMP.@constraint(pm.model, [bf_vio_fr + rate_a, p_fr, q_fr] in JuMP.SecondOrderCone())
end
############## dcp.jl ###################################################################################################################################################################################
function constraint_thermal_limit_from_soft(pm::_PM.AbstractDCPModel, n::Int, i::Int, f_idx, rate_a)     #AbstractActivePowerModel
    p_fr = _PM.var(pm, n, :p, f_idx)
    bf_vio_to = _PM.var(pm, n, :bf_vio_to, i)
    if isa(p_fr, JuMP.VariableRef) && JuMP.has_lower_bound(p_fr)
        cstr = JuMP.LowerBoundRef(p_fr)
        JuMP.lower_bound(p_fr) < -rate_a && JuMP.set_lower_bound(p_fr, -rate_a - bf_vio_to)
        if JuMP.has_upper_bound(p_fr)
            JuMP.upper_bound(p_fr) > rate_a && JuMP.set_upper_bound(p_fr, rate_a + bf_vio_to)
        end
    else
        cstr = JuMP.@constraint(pm.model, p_fr <= rate_a + bf_vio_to)
    end

    if _IM.report_duals(pm)
        sol(pm, n, :branch, f_idx[1])[:mu_sm_fr] = cstr
    end
end
#################################################################################################################################################################################################
function constraint_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_to_soft(pm, nw, i, t_idx, branch["rate_a"])
    end
end
function constraint_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, t_idx, rate_a)
    p_to = _PM.var(pm, n, :p, t_idx)
    q_to = _PM.var(pm, n, :q, t_idx)
    bf_vio_to = _PM.var(pm, n, :bf_vio_to, i)

    JuMP.@constraint(pm.model, p_to^2 + q_to^2 <= rate_a^2 + bf_vio_to)
end
function constraint_thermal_limit_to_soft(pm::_PM.AbstractConicModels, n::Int, i::Int, t_idx, rate_a)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)
    bf_vio_to = _PM.var(pm, n, :bf_vio_to, i)

    JuMP.@constraint(pm.model, [bf_vio_to + rate_a, p_to, q_to] in JuMP.SecondOrderCone())
end
function constraint_thermal_limit_to_soft(pm::_PM.AbstractDCPModel, n::Int, i::Int, t_idx, rate_a)                 #_PM.AbstractDCPModel
    p_to = _PM.var(pm, n, :p, t_idx)
    bf_vio_to = _PM.var(pm, n, :bf_vio_to, i)
    if isa(p_to, JuMP.VariableRef) && JuMP.has_lower_bound(p_to)
        cstr = JuMP.LowerBoundRef(p_to)
        JuMP.lower_bound(p_to) < -rate_a && JuMP.set_lower_bound(p_to, -rate_a - bf_vio_to)
        if JuMP.has_upper_bound(p_to)
            JuMP.upper_bound(p_to) >  rate_a && JuMP.set_upper_bound(p_to,  rate_a + bf_vio_to)
        end
    else
        cstr = JuMP.@constraint(pm.model, p_to <= rate_a + bf_vio_to)
    end

    if _IM.report_duals(pm)
        sol(pm, n, :branch, t_idx[1])[:mu_sm_to] = cstr
    end
end
#################################################################################################################################################################################################
function constraint_power_balance_dc_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    bus_arcs_dcgrid = _PM.ref(pm, nw, :bus_arcs_dcgrid, i)
    bus_convs_dc = _PM.ref(pm, nw, :bus_convs_dc, i)
    pd = _PM.ref(pm, nw, :busdc, i)["Pdc"]
    constraint_power_balance_dc_soft(pm, nw, i, bus_arcs_dcgrid, bus_convs_dc, pd)
end
function constraint_power_balance_dc_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, bus_arcs_dcgrid, bus_convs_dc, pd)
    p_dcgrid = _PM.var(pm, n, :p_dcgrid)
    pconv_dc = _PM.var(pm, n, :pconv_dc)
    pb_dc_pos_vio = _PM.var(pm, n, :pb_dc_pos_vio, i)
   
    JuMP.@constraint(pm.model, pb_dc_pos_vio + sum(p_dcgrid[a] for a in bus_arcs_dcgrid) + sum(pconv_dc[c] for c in bus_convs_dc) == (-pd))
end
######################################################################################################################################################################################################
function constraint_ohms_dc_branch_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branchdc, i)
    f_bus = branch["fbusdc"]
    t_bus = branch["tbusdc"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p = _PM.ref(pm, nw, :dcpol)

    constraint_ohms_dc_branch_soft(pm, nw, i, f_bus, t_bus, f_idx, t_idx, branch["r"], p)
end
##################### acp.jl ############################################################################################################################################################################
function constraint_ohms_dc_branch_soft(pm::_PM.AbstractACPModel, n::Int, i::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
    vmdc_fr = _PM.var(pm, n,  :vdcm, f_bus)
    vmdc_to = _PM.var(pm, n,  :vdcm, t_bus)
    bdcf_vio_fr = _PM.var(pm, n,  :bdcf_vio_fr, i)
    bdcf_vio_to = _PM.var(pm, n,  :bdcf_vio_to, i)

    if r == 0
        JuMP.@constraint(pm.model, p_dc_fr - bdcf_vio_fr + p_dc_to - bdcf_vio_to == 0)
    else
        g = 1 / r
        JuMP.@NLconstraint(pm.model, p_dc_fr - bdcf_vio_fr == p * g * vmdc_fr * (vmdc_fr - vmdc_to))
        JuMP.@NLconstraint(pm.model, p_dc_to - bdcf_vio_to == p * g * vmdc_to * (vmdc_to - vmdc_fr))
    end
end
##################### bf.jl ############################################################################################################################################################################
function constraint_ohms_dc_branch_soft(pm::_PM.AbstractBFQPModel, n::Int, i::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    l = f_idx[1];
    p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
    ccm_dcgrid = _PM.var(pm, n,  :ccm_dcgrid, l)
    wdc_fr = _PM.var(pm, n,  :wdc, f_bus)
    wdc_to = _PM.var(pm, n,  :wdc, t_bus)
    bdcf_vio_fr = _PM.var(pm, n,  :bdcf_vio_fr, i)
    bdcf_vio_to = _PM.var(pm, n,  :bdcf_vio_to, i)

    JuMP.@constraint(pm.model, p_dc_fr - bdcf_vio_fr + p_dc_to - bdcf_vio_to ==  r * p * ccm_dcgrid)
    JuMP.@constraint(pm.model, p_dc_fr^2 <= p^2 * wdc_fr * ccm_dcgrid)
    JuMP.@constraint(pm.model, wdc_to == wdc_fr - 2 * r * (p_dc_fr/p) + (r)^2 * ccm_dcgrid)
end

function constraint_ohms_dc_branch_soft(pm::_PM.AbstractBFConicModel, n::Int, i::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    l = f_idx[1];
    p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
    ccm_dcgrid = _PM.var(pm, n,  :ccm_dcgrid, l)
    wdc_fr = _PM.var(pm, n,  :wdc, f_bus)
    wdc_to = _PM.var(pm, n,  :wdc, t_bus)
    bdcf_vio_fr = _PM.var(pm, n,  :bdcf_vio_fr, i)
    bdcf_vio_to = _PM.var(pm, n,  :bdcf_vio_to, i)

    JuMP.@constraint(pm.model, p_dc_fr - bdcf_vio_fr + p_dc_to - bdcf_vio_to ==  r * p * ccm_dcgrid)
    JuMP.@constraint(pm.model, [p*wdc_fr/sqrt(2), p*ccm_dcgrid/sqrt(2), p_dc_fr/sqrt(2), p_dc_fr/sqrt(2)] in JuMP.RotatedSecondOrderCone())
    JuMP.@constraint(pm.model, wdc_to == wdc_fr - 2 * r * (p_dc_fr/p) + (r)^2 * ccm_dcgrid)
end
##################### dcp.jl ############################################################################################################################################################################
function constraint_ohms_dc_branch_soft(pm::_PM.AbstractDCPModel, n::Int, i::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)
    bdcf_vio_fr = _PM.var(pm, n,  :bdcf_vio_fr, i)
    bdcf_vio_to = _PM.var(pm, n,  :bdcf_vio_to, i)

    JuMP.@constraint(pm.model, p_dc_fr - bdcf_vio_fr + p_dc_to - bdcf_vio_to == 0)
end 
##################### lpac.jl ############################################################################################################################################################################
function constraint_ohms_dc_branch_soft(pm::_PM.AbstractLPACModel, n::Int, i::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)
    phi_fr = _PM.var(pm, n, :phi_vdcm, f_bus)
    phi_to = _PM.var(pm, n, :phi_vdcm, t_bus)
    phi_fr_ub = JuMP.UpperBoundRef(phi_to)
    phi_fr_lb = JuMP.LowerBoundRef(phi_to)
    bdcf_vio_fr = _PM.var(pm, n,  :bdcf_vio_fr, i)
    bdcf_vio_to = _PM.var(pm, n,  :bdcf_vio_to, i)

    if r == 0
        JuMP.@constraint(pm.model, p_dc_fr - bdcf_vio_fr + p_dc_to - bdcf_vio_to == 0)
    else
        g = 1 / r
        JuMP.@constraint(pm.model, p_dc_fr - bdcf_vio_fr == p * g *  (phi_fr - phi_to))
        JuMP.@constraint(pm.model, p_dc_to - bdcf_vio_to == p * g *  (phi_to - phi_fr))
    end
end
##################### shared.jl ############################################################################################################################################################################
function constraint_ohms_dc_branch_soft(pm::_PM.AbstractWRModels, n::Int, i::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)
    wdc_fr = _PM.var(pm, n, :wdc, f_bus)
    wdc_to = _PM.var(pm, n, :wdc, t_bus)
    wdc_frto = _PM.var(pm, n, :wdcr, (f_bus, t_bus))
    bdcf_vio_fr = _PM.var(pm, n,  :bdcf_vio_fr, i)
    bdcf_vio_to = _PM.var(pm, n,  :bdcf_vio_to, i)

    if r == 0
        JuMP.@constraint(pm.model, p_dc_fr - bdcf_vio_fr + p_dc_to - bdcf_vio_to == 0)
    else
        g = 1 / r
        JuMP.@constraint(pm.model, p_dc_fr - bdcf_vio_fr == p * g *  (wdc_fr - wdc_frto))
        JuMP.@constraint(pm.model, p_dc_to - bdcf_vio_to == p * g *  (wdc_to - wdc_frto))
    end
end