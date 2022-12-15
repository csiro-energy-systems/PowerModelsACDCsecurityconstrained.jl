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
#####################  ############################################################################################################################################################################

""
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
""
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
""
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
""
function constraint_branch_contingency_ptdf_dcdf_thermal_limit_to(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_map_ac, cut_map_dc, cut_p_dc_to, rate, to_idx)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    # p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)

    #JuMP.@constraint(pm.model, sum(-weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * cut_p_dc_to["$branchdc_id"]  for (branchdc_id, weight_dc) in cut_map_dc) <= rate)
    #JuMP.@constraint(pm.model, sum(-weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, to_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut_map_dc) <= rate)
    #JuMP.@constraint(pm.model, -sum(weight_ac*(bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end
"" 
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
""
function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_from(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_ptdf, cut_idcdf_branchdc, rate, fr_idx)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    # p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)
    p_fr = _PM.var(pm, n, :p, fr_idx)
    
    
    JuMP.@constraint(pm.model, sum(p_fr[fr_idx[branch_id]] - sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_ptdf["$branch_id"]) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate)
   
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) + sum(weight_dc * _PM.var(pm, n, :p_dcgrid, fr_idx[branchdc_id]) for (branchdc_id, weight_dc) in cut_map_dc) <= rate)
    #JuMP.@constraint(pm.model, sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_map_ac) <= rate)

end


""
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
""
function constraint_branchdc_contingency_ptdf_dcdf_thermal_limit_to(pm::_PM.AbstractPowerModel, n::Int, i::Int, cut_ptdf, cut_idcdf_branchdc, rate, to_idx)
    bus_injection = _PM.var(pm, :bus_pg)
    bus_withdrawal = _PM.var(pm, :bus_wdp)
    # p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)
    p_to = _PM.var(pm, n, :p, to_idx)
    
    
    JuMP.@constraint(pm.model, -sum(p_to[to_idx[branch_id]] + sum(weight_ac * (bus_injection[bus_id] - bus_withdrawal[bus_id]) for (bus_id, weight_ac) in cut_ptdf["$branch_id"]) * weight_dc for (branch_id, weight_dc) in cut_idcdf_branchdc) <= rate)
   
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

