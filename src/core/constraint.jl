############## acp.jl ###################################################################################################################################################################################
function constraint_power_balance_ac_shunt_dispatch_soft(pm::_PM.AbstractACPModel, n::Int,i::Int, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, bus_shunts_var, pd, qd, gs, bs)
    vm = _PM.var(pm, n,  :vm, i)
    p = _PM.var(pm, n,  :p)
    q = _PM.var(pm, n,  :q)
    pg = _PM.var(pm, n,  :pg)
    qg = _PM.var(pm, n,  :qg)
    pconv_grid_ac = _PM.var(pm, n,  :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n,  :qconv_tf_fr)

    pb_ac_pos_vio = _PM.var(pm, n, :pb_ac_pos_vio, i)
    qb_ac_pos_vio = _PM.var(pm, n, :qb_ac_pos_vio, i)
    pb_ac_neg_vio = _PM.var(pm, n, :pb_ac_neg_vio, i)
    qb_ac_neg_vio = _PM.var(pm, n, :qb_ac_neg_vio, i)

    bs_var = get(_PM.var(pm, n), :bs, Dict()); #_PM._check_var_keys(bs, bus_shunts_var, "reactive power", "shunt")

    JuMP.@NLconstraint(pm.model, pb_ac_pos_vio - pb_ac_neg_vio  + sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens)   - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*vm^2)
    JuMP.@NLconstraint(pm.model, qb_ac_pos_vio - qb_ac_neg_vio + sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac)  == sum(qg[g] for g in bus_gens)  - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*vm^2 + sum(bs_var[s] for s in bus_shunts_var)*vm^2)
end

function constraint_power_balance_ac_shunt_dispatch(pm::_PM.AbstractACPModel, n::Int,i::Int, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts, bus_shunts_var, pd, qd, gs, bs)
    vm = _PM.var(pm, n,  :vm, i)
    p = _PM.var(pm, n,  :p)
    q = _PM.var(pm, n,  :q)
    pg = _PM.var(pm, n,  :pg)
    qg = _PM.var(pm, n,  :qg)
    pconv_grid_ac = _PM.var(pm, n,  :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n,  :qconv_tf_fr)

    bs_var = get(_PM.var(pm, n), :bs, Dict()); #_PM._check_var_keys(bs, bus_shunts_var, "reactive power", "shunt")

    JuMP.@NLconstraint(pm.model, sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac)  == sum(pg[g] for g in bus_gens)   - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*vm^2)
    JuMP.@NLconstraint(pm.model, sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac)  == sum(qg[g] for g in bus_gens)  - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*vm^2 + sum(bs_var[s] for s in bus_shunts_var)*vm^2)
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

function constraint_power_balance_dc_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, bus_arcs_dcgrid, bus_convs_dc, pd)
    p_dcgrid = _PM.var(pm, n, :p_dcgrid)
    pconv_dc = _PM.var(pm, n, :pconv_dc)
    pb_dc_pos_vio = _PM.var(pm, n, :pb_dc_pos_vio, i)
   
    JuMP.@constraint(pm.model, pb_dc_pos_vio + sum(p_dcgrid[a] for a in bus_arcs_dcgrid) + sum(pconv_dc[c] for c in bus_convs_dc) == (-pd))
end



##################### acp.jl ############################################################################################################################################################################
# function constraint_ohms_dc_branch_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
#     branch = _PM.ref(pm, nw, :branchdc, i)
#     f_bus = branch["fbusdc"]
#     t_bus = branch["tbusdc"]
#     rate = branch["rateA"]
#     f_idx = (i, f_bus, t_bus)
#     t_idx = (i, t_bus, f_bus)

#     p = _PM.ref(pm, nw, :dcpol)

#     constraint_ohms_dc_branch_soft(pm, nw, i, f_bus, t_bus, f_idx, t_idx, branch["r"], p, rate)
# end
function constraint_ohms_dc_branch_soft(pm::_PM.AbstractACPModel, n::Int, i::Int, f_bus, t_bus, f_idx, t_idx, r, p, rate)
    p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
    vmdc_fr = _PM.var(pm, n,  :vdcm, f_bus)
    vmdc_to = _PM.var(pm, n,  :vdcm, t_bus)
    bdcf_vio_fr = _PM.var(pm, n,  :bdcf_vio_fr, i)
    bdcf_vio_to = _PM.var(pm, n,  :bdcf_vio_to, i)

    # soft bounds
    JuMP.@constraint(pm.model, p_dc_fr <= rate + bdcf_vio_fr)
    JuMP.@constraint(pm.model, p_dc_fr >= -rate - bdcf_vio_fr)

    JuMP.@constraint(pm.model, p_dc_to <= rate + bdcf_vio_to)
    JuMP.@constraint(pm.model, p_dc_to >= -rate - bdcf_vio_to)
    if r == 0
        JuMP.@constraint(pm.model, p_dc_fr  + p_dc_to  == 0)
    else
        g = 1 / r
        JuMP.@NLconstraint(pm.model, p_dc_fr  == p * g * vmdc_fr * (vmdc_fr - vmdc_to))
        JuMP.@NLconstraint(pm.model, p_dc_to  == p * g * vmdc_to * (vmdc_to - vmdc_fr))
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
#####################  ############################################################################################################################################################################
"links the generator power of two networks together, with an approximated projection response function"
function constraint_gen_power_real_response_smooth(pm::_PM.AbstractPowerModel, i::Int; nw_1::Int=_PM.nw_id_default, nw_2::Int=_PM.nw_id_default)
    gen = _PM.ref(pm, nw_2, :gen, i)
    constraint_gen_power_real_response_smooth(pm, nw_1, nw_2, i, gen["alpha"], gen["ep"])
end


""
function constraint_gen_power_real_response_smooth(pm::_PM.AbstractPowerModel, nw_1::Int, nw_2::Int, i::Int, alpha, ep)
    pg_base = _PM.var(pm, :pg, i, nw=nw_1)
    pg = _PM.var(pm, :pg, i, nw=nw_2)
    pgub = JuMP.upper_bound(_PM.var(pm, :pg, i, nw=nw_1))
    pglb = JuMP.lower_bound(_PM.var(pm, :pg, i, nw=nw_1))
    delta = _PM.var(pm, :delta, nw=nw_2)

    #JuMP.@NLconstraint(pm.model, pg == pglb + ep*log(     1 + ( exp((pgub-pglb)/ep) / (1 + exp((pgub - pg_base - alpha*delta)/ep)) )      ))
    JuMP.@NLconstraint(pm.model, pg == pgub - ep*log(     1 + exp( (pgub - pg_base - alpha*delta)/ep )     ))
end

"links the voltage voltage_magnitude of two networks together"
function constraint_gen_power_reactive_response_smooth(pm::_PM.AbstractPowerModel, i::Int; nw_1::Int=_PM.nw_id_default, nw_2::Int=_PM.nw_id_default)
    gen_id = _PM.ref(pm, :bus_gens, nw=nw_2, i)
    if haskey(_PM.ref(pm, nw_2, :gen), gen_id[1])
        gen = _PM.ref(pm, nw_2, :gen, _PM.ref(pm, :bus_gens, nw=nw_2, i)[1])
        constraint_gen_power_reactive_response_smooth(pm, nw_1, nw_2, i, gen["ep"])
    end
end

function constraint_gen_power_reactive_response_smooth(pm::_PM.AbstractACPModel, n_1::Int, n_2::Int, i::Int, ep)
    vm_1 = _PM.var(pm, n_1, :vm, i)
    vm_2 = _PM.var(pm, n_2, :vm, i)

    vmub = JuMP.upper_bound(_PM.var(pm, :vm, i, nw=n_1))
    vmlb = JuMP.lower_bound(_PM.var(pm, :vm, i, nw=n_1))
    gen_id = _PM.ref(pm, :bus_gens, nw=n_2, i)[1]
    qg = _PM.var(pm, :qg, gen_id, nw=n_2)
   
    qgub = JuMP.upper_bound(_PM.var(pm, :qg, gen_id, nw=n_1))
    qglb = JuMP.lower_bound(_PM.var(pm, :qg, gen_id, nw=n_1))
    
    JuMP.set_upper_bound(qg, qgub)
    JuMP.set_lower_bound(qg, qglb)

    JuMP.set_upper_bound(_PM.var(pm, n_2, :vm, i), JuMP.upper_bound(_PM.var(pm, n_1, :vm, i)))
    JuMP.set_lower_bound(_PM.var(pm, n_2, :vm, i), JuMP.lower_bound(_PM.var(pm, n_1, :vm, i)))
    
    JuMP.@NLconstraint(pm.model, vm_2 ==  vm_1 + ep*log(1 + exp(((vmub-vm_1) - qg + qglb)/(ep))) - ep*log(1 + exp(((vm_1-vmlb) + qg - qgub)/(ep))) )
end




#################################################################################################################################################################################################
######################################################### DROOP CONTROL ########################################################################################################################################
##
# function constraint_pvdc_droop_control(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
#     conv = _PM.ref(pm, nw, :convdc, i)

#     if conv["type_dc"] == 3
#         if conv["lp"] == 1
#             constraint_pvdc_droop_control_linear(pm, nw, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"])
#         elseif conv["milp"] == 1
#             constraint_pvdc_droop_control_milp(pm, nw, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"], conv["Vmmin"], conv["Vmmax"], conv["Vdclow"], conv["Vdchigh"])
#         elseif conv["nlp"] == 1
#             if conv["Pdcset"] >= 0.0
#                 constraint_pvdc_droop_control_nlp_positive(pm, nw, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"], conv["Vmmin"], conv["Vmmax"], conv["Vdclow"], conv["Vdchigh"], conv["ep"])
#             elseif conv["Pdcset"] < 0.0
#                 constraint_pvdc_droop_control_nlp_negative(pm, nw, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"], conv["Vmmin"], conv["Vmmax"], conv["Vdclow"], conv["Vdchigh"], conv["ep"])
#             end
#         end
#     end
# end

function constraint_pvdc_droop_control_milp(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)

    if conv["type_dc"] == 3
        constraint_pvdc_droop_control_milp(pm, nw, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"], conv["Vmmin"], conv["Vmmax"], conv["Vdclow"], conv["Vdchigh"])
    end 
end

function constraint_pvdc_droop_control_milp(pm::_PM.AbstractACPModel, n::Int, i::Int, busdc_i, vref_dc, pref_dc, k_droop, vdcmin, vdcmax, vdclow, vdchigh)
    pconv_dc = _PM.var(pm, n, :pconv_dc, i)
    vdc = _PM.var(pm, n, :vdcm, busdc_i)
    xd_a = _PM.var(pm, n, :xd_a, i)
    xd_b = _PM.var(pm, n, :xd_b, i)
    xd_c = _PM.var(pm, n, :xd_c, i)
    xd_d = _PM.var(pm, n, :xd_d, i)
    xd_e = _PM.var(pm, n, :xd_e, i)
    epsilon = 1E-12

    JuMP.@constraint(pm.model, pconv_dc == pref_dc
                                            - sign(pref_dc) * xd_a * (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) )
                                            - sign(pref_dc) * xd_b * (1 / k_droop * (vdchigh - vdc)) 
                                            - sign(pref_dc) * xd_c * 0
                                            - sign(pref_dc) * xd_d * (1 / k_droop * (vdclow - vdc))
                                            - sign(pref_dc) * xd_e * (1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin))
                                            )
    JuMP.@constraint(pm.model, xd_a + xd_b + xd_c + xd_d + xd_e == 1)
    JuMP.@constraint(pm.model, vdc >= vdcmax * xd_a + (vdchigh + epsilon) * xd_b + vdclow * xd_c + (vdcmin + epsilon) *xd_d)
    JuMP.@constraint(pm.model, vdc <= (vdcmax - epsilon) * xd_b + vdchigh * xd_c + (vdclow - epsilon) * xd_d + vdcmin * xd_e)
end





function constraint_pvdc_droop_control_linear(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)

    if conv["type_dc"] == 3
        constraint_pvdc_droop_control_linear(pm, nw, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"])
    end 
end

function constraint_pvdc_droop_control_linear(pm::_PM.AbstractACPModel, n::Int, i::Int, busdc_i, vref_dc, pref_dc, k_droop)
    pconv_dc = _PM.var(pm, n, :pconv_dc, i)
    vdc = _PM.var(pm, n, :vdcm, busdc_i)

    JuMP.@constraint(pm.model, pconv_dc == pref_dc - sign(pref_dc) * 1 / k_droop * (vdc - vref_dc))
end


function constraint_pvdc_droop_control_smooth(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)

    if conv["type_dc"] == 3
        if conv["Pdcset"] >= 0.0
            constraint_pvdc_droop_control_nlp_positive(pm, nw, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"], conv["Vmmin"], conv["Vmmax"], conv["Vdclow"], conv["Vdchigh"], conv["ep"])
        elseif conv["Pdcset"] < 0.0
            constraint_pvdc_droop_control_nlp_negative(pm, nw, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"], conv["Vmmin"], conv["Vmmax"], conv["Vdclow"], conv["Vdchigh"], conv["ep"])
        end 
    end
end
function constraint_pvdc_droop_control_nlp_positive(pm::_PM.AbstractACPModel, n::Int, i::Int, busdc_i, vref_dc, pref_dc, k_droop, vdcmin, vdcmax, vdclow, vdchigh, ep)
    pconv_dc = _PM.var(pm, n, :pconv_dc, i)
    vdc = _PM.var(pm, n, :vdcm, busdc_i)

    JuMP.@NLconstraint(pm.model, pconv_dc == pref_dc + (   -((1 /  k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
        -(-(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
        -((1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - vdc + vdcmin)/ep)))
        -(-((1 / k_droop * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep)))   ))
        )
end

function constraint_pvdc_droop_control_nlp_negative(pm::_PM.AbstractACPModel, n::Int, i::Int, busdc_i, vref_dc, pref_dc, k_droop, vdcmin, vdcmax, vdclow, vdchigh, ep)
    pconv_dc = _PM.var(pm, n, :pconv_dc, i)
    vdc = _PM.var(pm, n, :vdcm, busdc_i)
 
    JuMP.@NLconstraint(pm.model, pconv_dc == pref_dc -  (   -((1 /  k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
        -(-(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
        -((1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - vdc + vdcmin)/ep)))
        -(-((1 / k_droop * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep)))   ))
        )
end




function constraint_dc_droop_control_sos(pm::_PM.AbstractPowerModel, i::Int; nw_1::Int=_PM.nw_id_default, nw_2::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw_2, :convdc, i)
    bus = _PM.ref(pm, nw_2, :busdc, conv["busdc_i"])

    if conv["type_dc"] == 2
       # _PMACDC.constraint_dc_voltage_magnitude_setpoint(pm, i)
       # _PMACDC.constraint_reactive_conv_setpoint(pm, i)
    elseif conv["type_dc"] == 3
        constraint_dc_droop_control_sos(pm, nw_1, nw_2, i, conv["busdc_i"], conv["Vdcset"], conv["Pdcset"], conv["droop"], conv["Vmmin"], conv["Vmmax"], conv["Vdclow"], conv["Vdchigh"], conv["ep"])
    end 
end
function constraint_dc_droop_control_sos(pm::_PM.AbstractACPModel, n_1::Int, n_2::Int, i::Int, busdc_i, vref_dc, pref_dc, k_droop, vdcmin, vdcmax, vdclow, vdchigh, ep)
    pconv_dc = _PM.var(pm, n_2, :pconv_dc, i)
    vdc = _PM.var(pm, n_2, :vdcm, busdc_i)
    x1 = _PM.var(pm, n_2, :x1, i)
    x2 = _PM.var(pm, n_2, :x2, i)
    x3 = _PM.var(pm, n_2, :x3, i)
    x4 = _PM.var(pm, n_2, :x4, i)
    x5 = _PM.var(pm, n_2, :x5, i)
    epsilon = 1E-12
    x=([x1, x2, x3, x4, x5])

    JuMP.@constraint(pm.model, x in JuMP.SOS1())
    JuMP.@constraint(pm.model, vdcmax*x[1] + (vdchigh + epsilon)*x[2] + (vdclow + epsilon)*x[3] + vdcmin*x[4] <= vdc )
    JuMP.@constraint(pm.model, (vdcmax - epsilon)*x[2] + (vdchigh - epsilon)*x[3] + (vdclow - epsilon)*x[4] + vdcmin*x[5] >= vdc )
    JuMP.@constraint(pm.model, x1 + x2 + x3 + x4 + x5 == 1)
    JuMP.@constraint(pm.model, pconv_dc == (1 / k_droop * (vdcmax - vdc) + pref_dc)*x[1] + (1 / k_droop * (vdchigh - vdc) + pref_dc)*x[2] + pref_dc*x[3] + (1 / k_droop * (vdclow - vdc) + pref_dc)*x[4] + (1 / k_droop * (vdcmin - vdc) + pref_dc)*x[5])
end

#####################  ############################################################################################################################################################################

""
function constraint_ohms_y_oltc_pst_from(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    

    # vad_min = _PM.ref(pm, nw, :off_angmin)
    # vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_ohms_y_oltc_pst_from(pm, nw, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti)
end


""
function constraint_ohms_y_oltc_pst_to(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    
    # vad_min = _PM.ref(pm, nw, :off_angmin)
    # vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_ohms_y_oltc_pst_to(pm, nw, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti)
end

"""
Branch - On/Off Ohm's Law Constraints + Creates Ohms constraints with variables for complex transformation ratio (y post fix indicates  Y is in rectangular form)
```
p[f_idx] == z*(g/tm*v[f_bus]^2 + (-g*tr+b*ti)/tm^2*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus]-ta)) + (-b*tr-g*ti)/tm^2*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]-ta)))
q[f_idx] == z*(-(b+c/2)/tm*v[f_bus]^2 - (-b*tr-g*ti)/tm^2*(v[f_bus]*v[t_bus]*cos(t[f_bus]-t[t_bus]-ta)) + (-g*tr+b*ti)/tm^2*(v[f_bus]*v[t_bus]*sin(t[f_bus]-t[t_bus]-ta)))
```
"""
function constraint_ohms_y_oltc_pst_from(pm::_PM.AbstractACPModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti)
    p_fr  = _PM.var(pm, n,  :p, f_idx)
    q_fr  = _PM.var(pm, n,  :q, f_idx)
    vm_fr = _PM.var(pm, n, :vm, f_bus)
    vm_to = _PM.var(pm, n, :vm, t_bus)
    va_fr = _PM.var(pm, n, :va, f_bus)
    va_to = _PM.var(pm, n, :va, t_bus)
    tm = _PM.var(pm, n, :tm, f_idx[1])
    ta = _PM.var(pm, n, :ta, f_idx[1])
    

    JuMP.@NLconstraint(pm.model, p_fr == ( (g+g_fr)/tm^2*vm_fr^2 + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to-ta)) + (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to-ta))) )
    JuMP.@NLconstraint(pm.model, q_fr == (-(b+b_fr)/tm^2*vm_fr^2 - (-b*tr-g*ti)/tm^2*(vm_fr*vm_to*cos(va_fr-va_to-ta)) + (-g*tr+b*ti)/tm^2*(vm_fr*vm_to*sin(va_fr-va_to-ta))) )

 
end

"""
```
p[t_idx] == z*(g*v[t_bus]^2 + (-g*tr-b*ti)/tm^2*(v[t_bus]*v[f_bus]*cos(t[t_bus]-t[f_bus]+ta)) + (-b*tr+g*ti)/tm^2*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]+ta)))
q[t_idx] == z*(-(b+c/2)*v[t_bus]^2 - (-b*tr+g*ti)/tm^2*(v[t_bus]*v[f_bus]*cos(t[f_bus]-t[t_bus]+ta)) + (-g*tr-b*ti)/tm^2*(v[t_bus]*v[f_bus]*sin(t[t_bus]-t[f_bus]+ta)))
```
"""
function constraint_ohms_y_oltc_pst_to(pm::_PM.AbstractACPModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti)
    p_to  = _PM.var(pm, n,  :p, t_idx)
    q_to  = _PM.var(pm, n,  :q, t_idx)
    vm_fr = _PM.var(pm, n, :vm, f_bus)
    vm_to = _PM.var(pm, n, :vm, t_bus)
    va_fr = _PM.var(pm, n, :va, f_bus)
    va_to = _PM.var(pm, n, :va, t_bus)
    tm = _PM.var(pm, n, :tm, f_idx[1])
    ta = _PM.var(pm, n, :ta, f_idx[1])
    
    JuMP.@NLconstraint(pm.model, p_to == ( (g+g_to)*vm_to^2 + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr+ta)) + (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr+ta))) )
    JuMP.@NLconstraint(pm.model, q_to == (-(b+b_to)*vm_to^2 - (-b*tr+g*ti)/tm^2*(vm_to*vm_fr*cos(va_to-va_fr+ta)) + (-g*tr-b*ti)/tm^2*(vm_to*vm_fr*sin(va_to-va_fr+ta))) )

    
end

function constraint_converter_current(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    Vmax = conv["Vmmax"]
    Imax = conv["Imax"]
    constraint_converter_current(pm, nw, i, Vmax, Imax)
end

function constraint_converter_current(pm::_PM.AbstractACPModel, n::Int, i::Int, Umax, Imax)
    vmc = _PM.var(pm, n, :vmc, i)
    pconv_ac = _PM.var(pm, n, :pconv_ac, i)
    qconv_ac = _PM.var(pm, n, :qconv_ac, i)
    iconv = _PM.var(pm, n, :iconv_ac, i)
    i_conv_vio = _PM.var(pm, n, :i_conv_vio, i)

    JuMP.set_lower_bound(iconv, 0)
    JuMP.@constraint(pm.model, iconv <= Imax + i_conv_vio)
    JuMP.@NLconstraint(pm.model, pconv_ac^2 + qconv_ac^2 == vmc^2 * iconv^2)
end

###### MINLP Validation ########
###### MINLP Validation ########
###### MINLP Validation ########






function constraint_gen_power_real_response_milp(pm::_PM.AbstractPowerModel, i::Int; nw_1::Int=_PM.nw_id_default, nw_2::Int=_PM.nw_id_default)
    gen = _PM.ref(pm, nw_2, :gen, i)
    constraint_gen_power_real_response_milp(pm, nw_1, nw_2, i, gen["alpha"])
end

function constraint_gen_power_real_response_milp(pm::_PM.AbstractPowerModel, nw_1::Int, nw_2::Int, i::Int, alpha)
    pg_base = _PM.var(pm, :pg, i, nw=nw_1)
    pg = _PM.var(pm, :pg, i, nw=nw_2)
    pgub = JuMP.upper_bound(_PM.var(pm, :pg, i, nw=nw_1))
    pglb = JuMP.lower_bound(_PM.var(pm, :pg, i, nw=nw_1))
    delta = _PM.var(pm, :delta, nw=nw_2)
    xp_u = _PM.var(pm, :xp_u, i, nw=nw_2)
    xp_l = _PM.var(pm, :xp_l, i, nw=nw_2)
    bigM_u = 1E3
    bigM_l = 1E3

    JuMP.@constraint(pm.model, pgub - pg <= bigM_u * xp_u)
    JuMP.@constraint(pm.model, pg - pglb <= bigM_u * xp_l)
    JuMP.@constraint(pm.model, pg_base + alpha * delta - pg <= bigM_l * (1 - xp_u))
    JuMP.@constraint(pm.model, pg - pg_base - alpha * delta <= bigM_l * (1 - xp_l))
end


function constraint_gen_power_reactive_response_milp(pm::_PM.AbstractPowerModel, i::Int; nw_1::Int=_PM.nw_id_default, nw_2::Int=_PM.nw_id_default)
    gen_id = _PM.ref(pm, :bus_gens, nw=nw_2, i)
    if haskey(_PM.ref(pm, nw_2, :gen), gen_id[1])
        gen = _PM.ref(pm, nw_2, :gen, _PM.ref(pm, :bus_gens, nw=nw_2, i)[1])
        constraint_gen_power_reactive_response_milp(pm, nw_1, nw_2, i)
    end
end


""
function constraint_gen_power_reactive_response_milp(pm::_PM.AbstractACPModel, n_1::Int, n_2::Int, i::Int)
    vm_1 = _PM.var(pm, n_1, :vm, i)
    vm_2 = _PM.var(pm, n_2, :vm, i)
    gen_id = _PM.ref(pm, :bus_gens, nw=n_2, i)[1]
    qg = _PM.var(pm, :qg, gen_id, nw=n_2)
    qgub = JuMP.upper_bound(_PM.var(pm, :qg, gen_id, nw=n_1))
    qglb = JuMP.lower_bound(_PM.var(pm, :qg, gen_id, nw=n_1))
    xq_u = _PM.var(pm, :xp_u, i, nw=n_2)
    xq_l = _PM.var(pm, :xp_l, i, nw=n_2)
    bigM_u = 1E3
    bigM_l = 1E3
    
    JuMP.@constraint(pm.model, qgub - qg <= bigM_u * xq_u)
    JuMP.@constraint(pm.model, qg - qglb <= bigM_u * xq_l)
    JuMP.@constraint(pm.model, vm_1 - vm_2 <= bigM_l * (1 - xq_u))
    JuMP.@constraint(pm.model, vm_2 - vm_1 <= bigM_l * (1 - xq_l))
end


























# constraints for ptdf dcdf cuts soft

function constraint_branch_contingency_ptdf_dcdf_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    cut = _PM.ref(pm, :branch_flow_cuts, i)
    branch =  _PM.ref(pm, nw, :branch, cut.branch_id)
    branch_dc = _PM.ref(pm, :branchdc)
    fr_idx = [(i, branchdc["fbusdc"], branchdc["tbusdc"]) for (i,branchdc) in branch_dc] 
    # f_idx = (i, f_bus, t_bus)
    ploss = _PM.ref(pm, nw, :ploss)
    ploss_df = _PM.ref(pm, nw, :ploss_df)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    if haskey(branch, "rate_c")
        constraint_branch_contingency_ptdf_dcdf_thermal_limit_from_soft(pm, nw, i, cut.ptdf_branch, cut.dcdf_branch, cut.p_dc_fr, branch["rate_c"], fr_idx, f_idx, t_idx, ploss, ploss_df)
    end
end

function constraint_branch_contingency_ptdf_dcdf_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_map_ac, cut_map_dc, cut_p_dc_fr, rate, fr_idx, f_idx, t_idx, ploss, ploss_df)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    branch_cont_flow_vio = _PM.var(pm, :branch_cont_flow_vio, i)
    # p_dc_fr = _PM.var(pm, n, :p_dcgrid, fr_idx)

    # p_fr  = _PM.var(pm, n,  :p, f_idx)
    # p_to  = _PM.var(pm, n,  :p, t_idx)
    
    JuMP.@constraint(pm.model,  sum(weight_ac * (bus_injection[bus_id] - (bus_withdrawal[bus_id] + ploss_df[bus_id]*ploss)) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id])  for (branchdc_id, weight_dc) in cut_map_dc)  <= rate + branch_cont_flow_vio)
    JuMP.@constraint(pm.model, -sum(weight_ac * (bus_injection[bus_id] - (bus_withdrawal[bus_id] + ploss_df[bus_id]*ploss)) for (bus_id, weight_ac) in cut_map_ac) - sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id])  for (branchdc_id, weight_dc) in cut_map_dc)  <= rate + branch_cont_flow_vio)
    
    # JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - (bus_withdrawal[bus_id] + p_fr-p_to)) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id])  for (branchdc_id, weight_dc) in cut_map_dc)  <= rate + branch_cont_flow_vio)
    # JuMP.@constraint(pm.model, -sum(weight_ac * (bus_injection[bus_id] - (bus_withdrawal[bus_id] - p_fr+p_to)) for (bus_id, weight_ac) in cut_map_ac) - sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id])  for (branchdc_id, weight_dc) in cut_map_dc)  <= rate + branch_cont_flow_vio)
    
    
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end

##################### ##################### ##################### 

function constraint_branch_contingency_ptdf_dcdf_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    cut = _PM.ref(pm, :branch_flow_cuts, i)
    branch = _PM.ref(pm, nw, :branch, cut.branch_id)
    branch_dc = _PM.ref(pm, :branchdc)
    to_idx = [(i, branchdc["tbusdc"], branchdc["fbusdc"]) for (i,branchdc) in branch_dc] 
    # t_idx = (i, t_bus, f_bus)
    
    if haskey(branch, "rate_c")
        constraint_branch_contingency_ptdf_dcdf_thermal_limit_to_soft(pm, nw, i, cut.ptdf_branch, cut.dcdf_branch, cut.p_dc_to, branch["rate_c"], to_idx)
    end
end

function constraint_branch_contingency_ptdf_dcdf_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_map_ac, cut_map_dc, cut_p_dc_to, rate, to_idx)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    branch_cont_flow_vio = _PM.var(pm, :branch_cont_flow_vio, i)
    p_dc_to = _PM.var(pm, n, :p_dcgrid, to_idx)

    #JuMP.@constraint(pm.model, sum(-weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * cut_p_dc_to["$branchdc_id"]  for (branchdc_id, weight_dc) in cut_map_dc) <= rate + branch_cont_flow_vio)
    #JuMP.@constraint(pm.model, sum(-weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, to_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut_map_dc) <= rate + branch_cont_flow_vio)
    #JuMP.@constraint(pm.model, -sum(weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end

##################### ##################### ##################### 
function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    cut = _PM.ref(pm, :branchdc_flow_cuts, i)
    branchdc =  _PM.ref(pm, nw, :branchdc, cut.branchdc_id)  ############################
    branches = _PM.ref(pm, :branch)
    fr_idx = [(i, branch["f_bus"], branch["t_bus"]) for (i,branch) in branches] 
    # f_idx = (i, f_bus, t_bus)
    ploss = _PM.ref(pm, nw, :ploss)
    ploss_df = _PM.ref(pm, nw, :ploss_df)

    if haskey(branchdc, "rateC")
        constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from_soft(pm, nw, i, cut.ptdf, cut.idcdf_branchdc, branchdc["rateC"], fr_idx, ploss, ploss_df)
    end
end

function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_ptdf, cut_idcdf_branchdc, rate, fr_idx, ploss, ploss_df)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    branchdc_cont_flow_vio = _PM.var(pm, :branchdc_cont_flow_vio, i)
    # p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)

    # p_fr = _PM.var(pm, n, :p, fr_idx)

    p_fr = _PM.var(pm, n, :branch_p_fr)

    # JuMP.@constraint(pm.model, sum(p_fr[fr_idx[branch_id]] - sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_ptdf["$branch_id"]) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate)
    JuMP.@constraint(pm.model, sum((p_fr[branch_id] - sum(weight_ac * (bus_injection[bus_id] - (bus_withdrawal[bus_id] + ploss_df[bus_id]*ploss)) for (bus_id, weight_ac) in cut_ptdf["$branch_id"])) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate + branchdc_cont_flow_vio)
   
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut_map_dc) <= rate)
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end



##################### ##################### ##################### 
function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    cut = _PM.ref(pm, :branchdc_flow_cuts, i)
    branchdc =  _PM.ref(pm, nw, :branchdc, cut.branchdc_id)  ############################
    branches = _PM.ref(pm, :branch)
    to_idx = [(i, branch["t_bus"], branch["f_bus"]) for (i,branch) in branches] 
    # t_idx = (i, t_bus, f_bus)
    ploss = _PM.ref(pm, nw, :ploss)
    ploss_df = _PM.ref(pm, nw, :ploss_df)
    
    if haskey(branchdc, "rateC")
        constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to_soft(pm, nw, i, cut.ptdf, cut.idcdf_branchdc, branchdc["rateC"], to_idx, ploss, ploss_df)
    end
end

function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_ptdf, cut_idcdf_branchdc, rate, to_idx, ploss, ploss_df)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    branchdc_cont_flow_vio = _PM.var(pm, :branchdc_cont_flow_vio, i)
    # p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)

    # p_to = _PM.var(pm, n, :p, to_idx)

    p_to = _PM.var(pm, n, :branch_p_to)
    
    JuMP.@constraint(pm.model, sum((p_to[branch_id] + sum(weight_ac * (bus_injection[bus_id] - (bus_withdrawal[bus_id] + ploss_df[bus_id]*ploss)) for (bus_id, weight_ac) in cut_ptdf["$branch_id"])) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate + branchdc_cont_flow_vio)
   
    # JuMP.@constraint(pm.model, -sum(p_to[to_idx[branch_id]] + sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_ptdf["$branch_id"]) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate)
   
    #JuMP.@constraint(pm.model, -sum(weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) - sum(weight_dc * _PM.var(pm, n, :p_dcgrid, to_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut_map_dc)   <= rate)
    #JuMP.@constraint(pm.model, -sum(weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end


# constraints for ptdf dcdf cuts not-soft

function constraint_branch_contingency_ptdf_dcdf_thermal_limit_from(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    cut = _PM.ref(pm, :branch_flow_cuts, i)
    branch =  _PM.ref(pm, nw, :branch, cut.branch_id)
    branch_dc = _PM.ref(pm, :branchdc)
    fr_idx = [(i, branchdc["fbusdc"], branchdc["tbusdc"]) for (i,branchdc) in branch_dc] 
    # f_idx = (i, f_bus, t_bus)

    if haskey(branch, "rate_c")
        constraint_branch_contingency_ptdf_dcdf_thermal_limit_from(pm, nw, i, cut.ptdf_branch, cut.dcdf_branch, cut.p_dc_fr, branch["rate_c"], fr_idx)
    end
end

function constraint_branch_contingency_ptdf_dcdf_thermal_limit_from(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_map_ac, cut_map_dc, cut_p_dc_fr, rate, fr_idx)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    # p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)
  
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * cut_p_dc_fr["$branchdc_id"]  for (branchdc_id, weight_dc) in cut_map_dc)  <= rate)
    #JuMP.@constraint(pm.model, -sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * cut_p_dc_fr["$branchdc_id"]  for (branchdc_id, weight_dc) in cut_map_dc)  <= rate)
   
    JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id])  for (branchdc_id, weight_dc) in cut_map_dc)  <= rate)
    JuMP.@constraint(pm.model, -sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id])  for (branchdc_id, weight_dc) in cut_map_dc)  <= rate)
    
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end

##################### ##################### ##################### 

function constraint_branch_contingency_ptdf_dcdf_thermal_limit_to(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    cut = _PM.ref(pm, :branch_flow_cuts, i)
    branch = _PM.ref(pm, nw, :branch, cut.branch_id)
    branch_dc = _PM.ref(pm, :branchdc)
    to_idx = [(i, branchdc["tbusdc"], branchdc["fbusdc"]) for (i,branchdc) in branch_dc] 
    # t_idx = (i, t_bus, f_bus)
    
    if haskey(branch, "rate_c")
        constraint_branch_contingency_ptdf_dcdf_thermal_limit_to(pm, nw, i, cut.ptdf_branch, cut.dcdf_branch, cut.p_dc_to, branch["rate_c"], to_idx)
    end
end

function constraint_branch_contingency_ptdf_dcdf_thermal_limit_to(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_map_ac, cut_map_dc, cut_p_dc_to, rate, to_idx)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    # p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)

    #JuMP.@constraint(pm.model, sum(-weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * cut_p_dc_to["$branchdc_id"]  for (branchdc_id, weight_dc) in cut_map_dc) <= rate)
    #JuMP.@constraint(pm.model, sum(-weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, to_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut_map_dc) <= rate)
    #JuMP.@constraint(pm.model, -sum(weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end
 
##################### ##################### ##################### 
function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    cut = _PM.ref(pm, :branchdc_flow_cuts, i)
    branchdc =  _PM.ref(pm, nw, :branchdc, cut.branchdc_id)  ############################
    branches = _PM.ref(pm, :branch)
    fr_idx = [(i, branch["f_bus"], branch["t_bus"]) for (i,branch) in branches] 
    # f_idx = (i, f_bus, t_bus)
    
    if haskey(branchdc, "rateC")
        constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from(pm, nw, i, cut.ptdf, cut.idcdf_branchdc, branchdc["rateC"], fr_idx)
    end
end

function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_ptdf, cut_idcdf_branchdc, rate, fr_idx)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    # p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)

    # p_fr = _PM.var(pm, n, :p, fr_idx)

    p_fr = _PM.var(pm, n, :branch_p_fr)

    # JuMP.@constraint(pm.model, sum(p_fr[fr_idx[branch_id]] - sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_ptdf["$branch_id"]) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate)
    JuMP.@constraint(pm.model, sum(p_fr[branch_id] - sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_ptdf["$branch_id"]) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate)
   
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut_map_dc) <= rate)
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end



##################### ##################### ##################### 
function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    cut = _PM.ref(pm, :branchdc_flow_cuts, i)
    branchdc =  _PM.ref(pm, nw, :branchdc, cut.branchdc_id)  ############################
    branches = _PM.ref(pm, :branch)
    to_idx = [(i, branch["t_bus"], branch["f_bus"]) for (i,branch) in branches] 
    # t_idx = (i, t_bus, f_bus)
    
    if haskey(branchdc, "rateC")
        constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to(pm, nw, i, cut.ptdf, cut.idcdf_branchdc, branchdc["rateC"], to_idx)
    end
end

function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_ptdf, cut_idcdf_branchdc, rate, to_idx)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    # p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)

    # p_to = _PM.var(pm, n, :p, to_idx)

    p_to = _PM.var(pm, n, :branch_p_to)
    
    JuMP.@constraint(pm.model, -sum(p_to[branch_id] + sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_ptdf["$branch_id"]) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate)
   
    # JuMP.@constraint(pm.model, -sum(p_to[to_idx[branch_id]] + sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_ptdf["$branch_id"]) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate)
   
    #JuMP.@constraint(pm.model, -sum(weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) - sum(weight_dc * _PM.var(pm, n, :p_dcgrid, to_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut_map_dc)   <= rate)
    #JuMP.@constraint(pm.model, -sum(weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end




##################### ##################### ##################### 

"variable controling a linear genetor responce for controller "
function variable_c1_response_delta(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, report::Bool=true)
    delta = var(pm, nw)[:delta] = JuMP.@variable(pm.model,
        base_name="$(nw)_delta",
        start = 0.0
    )

    if report
        sol(pm, nw)[:delta] = delta
    end
end




#####################  ############################################################################################################################################################################
## not needed anymore


## not needed anymore

