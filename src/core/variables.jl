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

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branch, :bf_vio_fr, _PM.ids(pm, nw, :branch), bf_vio_fr)
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

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branch, :bf_vio_to, _PM.ids(pm, nw, :branch), bf_vio_to)
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

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branchdc, :bdcf_vio_fr, _PM.ids(pm, nw, :branchdc), bdcf_vio_fr)
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

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branchdc, :bdcf_vio_to, _PM.ids(pm, nw, :branchdc), bdcf_vio_to)
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

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :pb_ac_pos_vio, _PM.ids(pm, nw, :bus), pb_ac_pos_vio)
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

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :qb_ac_pos_vio, _PM.ids(pm, nw, :bus), qb_ac_pos_vio)
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

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :busdc, :pb_dc_pos_vio, _PM.ids(pm, nw, :busdc), pb_dc_pos_vio)
end 


function variable_c1_voltage_response(pm::_PM.AbstractPowerModel; kwargs...)
    variable_c1_voltage_response_positive(pm::_PM.AbstractPowerModel; kwargs...)
    variable_c1_voltage_response_negative(pm::_PM.AbstractPowerModel; kwargs...) 
end 
function variable_c1_voltage_response_positive(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    vg_pos = _PM.var(pm, nw)[:vg_pos] = JuMP.@variable(pm.model,
        [i in 1:length(_PM.ref(pm, nw, :bus))], base_name="$(nw)_vg_pos",
    )             
    
    if bounded
        for i in 1:length(_PM.ref(pm, nw, :bus))        
            JuMP.set_lower_bound(vg_pos[i], 0.0)   
            #JuMP.set_upper_bound(vg_pos[i], JuMP.upper_bound(_PM.var(pm, nw, :vm, i)) - JuMP.lower_bound(_PM.var(pm, nw, :vm, i)))
        end
    end

#    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen_buses, :vg_pos, _PM.ref(pm, nw, :gen_buses), vg_pos)
end
function variable_c1_voltage_response_negative(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    vg_neg = _PM.var(pm, nw)[:vg_neg] = JuMP.@variable(pm.model,
        [i in 1:length(_PM.ref(pm, nw, :bus))], base_name="$(nw)_vg_neg",
    )
    
    if bounded
        for i in 1:length(_PM.ref(pm, nw, :bus))
            JuMP.set_lower_bound(vg_neg[i], 0.0)   
            #JuMP.set_upper_bound(vg_neg[i], JuMP.upper_bound(_PM.var(pm, nw, :vm, i)) - JuMP.lower_bound(_PM.var(pm, nw, :vm, i)))
        end
    end

#    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen_buses, :vg_neg, _PM.ref(pm, nw, :gen_buses), vg_neg)
end 

"variable controling a linear converter responce "
function variable_conv_response_delta(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, report::Bool=true)
    delta_conv = _PM.var(pm, nw)[:delta_conv] = JuMP.@variable(pm.model,
        base_name="$(nw)_delta_conv",
        start = 0.0
    )

    if report
        _PM.sol(pm, nw)[:delta_conv] = delta_conv
    end
end


# function variable_dc_droop_control(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
#    ax = _PM.var(pm, nw)[:ax] = JuMP.@variable(pm.model,
#         [i in _PM.ids(pm, nw, :convdc), j=1:5], base_name="$(nw)_ax",
#         lower_bound=0,
#         upper_bound=1
#     )
    
#     # if bounded
#     #     for i in 1:length(_PM.ref(pm, nw, :bus))
#     #         JuMP.set_lower_bound(vg_neg[i], 0.0)   
#     #         #JuMP.set_upper_bound(vg_neg[i], JuMP.upper_bound(_PM.var(pm, nw, :vm, i)) - JuMP.lower_bound(_PM.var(pm, nw, :vm, i)))
#     #     end
#     # end

#     report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :ax, _PM.ids(pm, nw, :convdc), ax)
# end 
function variable_dc_droop_control(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    x1 = _PM.var(pm, nw)[:x1] = JuMP.@variable(pm.model,
        [i in 1:length(_PM.ref(pm, nw, :convdc))], base_name="$(nw)_x1",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :convdc))
            JuMP.set_lower_bound(x1[i], 0)
            JuMP.set_upper_bound(x1[i], 1)
        end
    end

    x2 = _PM.var(pm, nw)[:x2] = JuMP.@variable(pm.model,
    [i in 1:length(_PM.ref(pm, nw, :convdc))], base_name="$(nw)_x2",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :convdc))
            JuMP.set_lower_bound(x2[i], 0)
            JuMP.set_upper_bound(x2[i], 1)
        end
    end

    x3 = _PM.var(pm, nw)[:x3] = JuMP.@variable(pm.model,
    [i in 1:length(_PM.ref(pm, nw, :convdc))], base_name="$(nw)_x3",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :convdc))
            JuMP.set_lower_bound(x3[i], 0)
            JuMP.set_upper_bound(x3[i], 1)
        end
    end

    x4 = _PM.var(pm, nw)[:x4] = JuMP.@variable(pm.model,
    [i in 1:length(_PM.ref(pm, nw, :convdc))], base_name="$(nw)_x4",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :convdc))
            JuMP.set_lower_bound(x4[i], 0)
            JuMP.set_upper_bound(x4[i], 1)
        end
    end

    x5 = _PM.var(pm, nw)[:x5] = JuMP.@variable(pm.model,
    [i in 1:length(_PM.ref(pm, nw, :convdc))], base_name="$(nw)_x5",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :convdc))
            JuMP.set_lower_bound(x5[i], 0)
            JuMP.set_upper_bound(x5[i], 1)
        end
    end

    droopv = _PM.var(pm, nw)[:droopv] = JuMP.@variable(pm.model,
    [i in 1:length(_PM.ref(pm, nw, :convdc))], base_name="$(nw)_droopv",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :convdc))
            JuMP.set_lower_bound(droopv[i], 0.007)
            JuMP.set_upper_bound(droopv[i], 0.02)
        end
    end


    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x1, _PM.ids(pm, nw, :convdc), x1)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x2, _PM.ids(pm, nw, :convdc), x2)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x3, _PM.ids(pm, nw, :convdc), x3)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x4, _PM.ids(pm, nw, :convdc), x4)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x5, _PM.ids(pm, nw, :convdc), x5)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :droopv, _PM.ids(pm, nw, :convdc), droopv)
end 
