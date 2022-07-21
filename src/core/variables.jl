function variable_branch_thermal_limit_violation(pm::_PM.AbstractPowerModel; kwargs...)
    variable_branch_thermal_limit_violation_from(pm::_PM.AbstractPowerModel; kwargs...)
    variable_branch_thermal_limit_violation_to(pm::_PM.AbstractPowerModel; kwargs...)
end

function variable_branch_thermal_limit_violation_from(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    bf_vio_fr = _PM.var(pm, nw)[:bf_vio_fr] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :branch)], base_name="$(nw)_bf_vio_fr",
        # start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )                                                                                                 #[i in 1:length(_PM.ref(pm, nw, :branch))]   

    if bounded
        for i in _PM.ids(pm, nw, :branch)
            JuMP.set_lower_bound(bf_vio_fr[i], 0.0)
            JuMP.set_upper_bound(bf_vio_fr[i], 1e1)
        end
    end

    report && _PM.sol_component_value(pm, nw, :branch, :bf_vio_fr, bf_vio_fr)
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

    report && _PM.sol_component_value(pm, nw, :branch, :bf_vio_to, bf_vio_to)
end



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

    report && _PM.sol_component_value(pm, nw, :branchdc, :bdcf_vio_fr, bdcf_vio_fr)
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

    report && _PM.sol_component_value(pm, nw, :branchdc, :bdcf_vio_to, bdcf_vio_to)
end



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

    report && _PM.sol_component_value(pm, nw, :bus, :pb_ac_pos_vio, pb_ac_pos_vio)
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

    report && _PM.sol_component_value(pm, nw, :bus, :qb_ac_pos_vio, qb_ac_pos_vio)
end



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

    report && _PM.sol_component_value(pm, nw, :busdc, :pb_dc_pos_vio, pb_dc_pos_vio)
end 