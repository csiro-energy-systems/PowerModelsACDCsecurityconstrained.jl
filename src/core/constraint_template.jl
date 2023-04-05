function constraint_power_balance_ac_shunt_dispatch_soft(pm::_PM.AbstractPowerModel,i::Int; nw::Int=_PM.nw_id_default)
    bus = _PM.ref(pm, nw, :bus, i)
    bus_arcs = _PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = _PM.ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = _PM.ref(pm, nw, :bus_gens, i)
    bus_convs_ac = _PM.ref(pm, nw, :bus_convs_ac, i)
    bus_loads = _PM.ref(pm, nw, :bus_loads, i)
   

    bus_shunts_const = _PMSC.ref(pm, nw, :bus_shunts_const, i)
    bus_shunts_var = _PMSC.ref(pm, nw, :bus_shunts_var, i)

    bus_pd = Dict(k => _PM.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => _PM.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs_const = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts_const)
    bus_bs_const = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts_const)

    constraint_power_balance_ac_shunt_dispatch_soft(pm, nw, i, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts_const, bus_shunts_var, bus_pd, bus_qd, bus_gs_const, bus_bs_const)
end


function constraint_thermal_limit_from_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_from_soft(pm, nw, i, f_idx, branch["rate_a"])
    end
end


function constraint_thermal_limit_to_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    if haskey(branch, "rate_a")
        constraint_thermal_limit_to_soft(pm, nw, i, t_idx, branch["rate_a"])
    end
end


function constraint_power_balance_dc_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    bus_arcs_dcgrid = _PM.ref(pm, nw, :bus_arcs_dcgrid, i)
    bus_convs_dc = _PM.ref(pm, nw, :bus_convs_dc, i)
    pd = _PM.ref(pm, nw, :busdc, i)["Pdc"]
    constraint_power_balance_dc_soft(pm, nw, i, bus_arcs_dcgrid, bus_convs_dc, pd)
end


function constraint_ohms_dc_branch_soft(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branchdc, i)
    f_bus = branch["fbusdc"]
    t_bus = branch["tbusdc"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p = _PM.ref(pm, nw, :dcpol)

    constraint_ohms_dc_branch_soft(pm, nw, i, f_bus, t_bus, f_idx, t_idx, branch["r"], p)
end