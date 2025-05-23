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

function constraint_power_balance_ac_shunt_strg_dispatch_soft(pm::_PM.AbstractPowerModel,i::Int; nw::Int=_PM.nw_id_default)
    bus = _PM.ref(pm, nw, :bus, i)
    bus_arcs = _PM.ref(pm, nw, :bus_arcs, i)
    bus_arcs_dc = _PM.ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = _PM.ref(pm, nw, :bus_gens, i)
    bus_convs_ac = _PM.ref(pm, nw, :bus_convs_ac, i)
    bus_loads = _PM.ref(pm, nw, :bus_loads, i)
    bus_storage = _PM.ref(pm, nw, :bus_storage, i)
   

    bus_shunts_const = _PMSC.ref(pm, nw, :bus_shunts_const, i)
    bus_shunts_var = _PMSC.ref(pm, nw, :bus_shunts_var, i)

    bus_pd = Dict(k => _PM.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => _PM.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs_const = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts_const)
    bus_bs_const = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts_const) 

    constraint_power_balance_ac_shunt_strg_dispatch_soft(pm, nw, i, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_storage, bus_convs_ac, bus_loads, bus_shunts_const, bus_shunts_var, bus_pd, bus_qd, bus_gs_const, bus_bs_const) 
end

function constraint_power_balance_ac_shunt_dispatch(pm::_PM.AbstractPowerModel,i::Int; nw::Int=_PM.nw_id_default)
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

    constraint_power_balance_ac_shunt_dispatch(pm, nw, i, bus, bus_arcs, bus_arcs_dc, bus_gens, bus_convs_ac, bus_loads, bus_shunts_const, bus_shunts_var, bus_pd, bus_qd, bus_gs_const, bus_bs_const)
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
    rate = branch["rateA"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p = _PM.ref(pm, nw, :dcpol)

    constraint_ohms_dc_branch_soft(pm, nw, i, f_bus, t_bus, f_idx, t_idx, branch["r"], p, rate)
end

function constraint_generator_ramping(pm::_PM.AbstractPowerModel, i::Int, nw::Int =_PM.nw_id_default)
    if nw == 1
        nothing
    else
        previous_hour_network_id = get_previous_hour_network_id(pm, nw)
        gen = _PM.ref(pm, nw, :gen, i)
        Δt = _PM.ref(pm, nw, :time_interval)
        ΔPg_up = gen["Ramp_Up_Rate(MW/h)"] * Δt 
        ΔPg_down = gen["Ramp_Down_Rate(MW/h)"] * Δt
        
        constraint_generator_ramping(pm, nw, i, previous_hour_network_id, ΔPg_up, ΔPg_down)
    end 
end


"links the voltage voltage_magnitude of two networks together"
function constraint_storage_power_real_link(pm::_PM.AbstractPowerModel, i::Int; nw_1::Int=_PM.nw_id_default, nw_2::Int=_PM.nw_id_default)
    constraint_storage_power_real_link(pm, nw_1, nw_2, i) 
end

"links the generator power of two networks together, with a linear response function"
function constraint_storage_power_real_response(pm::_PM.AbstractPowerModel, i::Int; nw_1::Int=_PM.nw_id_default, nw_2::Int=_PM.nw_id_default)
    storage = _PM.ref(pm, nw_2, :storage, i)
    constraint_storage_power_real_response(pm, nw_1, nw_2, i, storage["alpha"])
end