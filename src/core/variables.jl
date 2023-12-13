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
    pb_ac_pos_vio = _PM.var(pm, nw)[:pb_ac_pos_vio] = JuMP.@variable(pm.model, [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_pb_ac_pos_vio",
    )

    if bounded
        for i in _PM.ids(pm, nw, :bus)
            JuMP.set_lower_bound(pb_ac_pos_vio[i], 0.0)
            JuMP.set_upper_bound(pb_ac_pos_vio[i], 1e1)
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :pb_ac_pos_vio, _PM.ids(pm, nw, :bus), pb_ac_pos_vio)
end 

function variable_power_balance_ac_positive_violation_imag(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    qb_ac_pos_vio = _PM.var(pm, nw)[:qb_ac_pos_vio] = JuMP.@variable(pm.model, [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_qb_ac_pos_vio",
    )

    if bounded
        for i in _PM.ids(pm, nw, :bus)
            JuMP.set_lower_bound(qb_ac_pos_vio[i], 0.0)
            JuMP.set_upper_bound(qb_ac_pos_vio[i], 1e1)
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :qb_ac_pos_vio, _PM.ids(pm, nw, :bus), qb_ac_pos_vio)
end

function variable_power_balance_ac_negative_violation(pm::_PM.AbstractPowerModel; kwargs...)
    variable_power_balance_ac_negative_violation_real(pm::_PM.AbstractPowerModel; kwargs...)
    variable_power_balance_ac_negative_violation_imag(pm::_PM.AbstractPowerModel; kwargs...) 
end   

function variable_power_balance_ac_negative_violation_real(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pb_ac_neg_vio = _PM.var(pm, nw)[:pb_ac_neg_vio] = JuMP.@variable(pm.model, [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_pb_ac_neg_vio",
    )

    if bounded
        for i in _PM.ids(pm, nw, :bus)
            JuMP.set_lower_bound(pb_ac_neg_vio[i], 0.0)
            JuMP.set_upper_bound(pb_ac_neg_vio[i], 1e1)
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :pb_ac_neg_vio, _PM.ids(pm, nw, :bus), pb_ac_neg_vio)
end 

function variable_power_balance_ac_negative_violation_imag(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    qb_ac_neg_vio = _PM.var(pm, nw)[:qb_ac_neg_vio] = JuMP.@variable(pm.model, [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_qb_ac_neg_vio",
    )

    if bounded
        for i in _PM.ids(pm, nw, :bus)
            JuMP.set_lower_bound(qb_ac_neg_vio[i], 0.0)
            JuMP.set_upper_bound(qb_ac_neg_vio[i], 1e1)
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :qb_ac_neg_vio, _PM.ids(pm, nw, :bus), qb_ac_neg_vio)
end



function variable_power_balance_dc_positive_violation(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pb_dc_pos_vio = _PM.var(pm, nw)[:pb_dc_pos_vio] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :busdc)], base_name="$(nw)_pb_dc_pos_vio",
    )

    if bounded
        for i in _PM.ids(pm, nw, :busdc)
            JuMP.set_lower_bound(pb_dc_pos_vio[i], 0.0)
            JuMP.set_upper_bound(pb_dc_pos_vio[i], 1e1)
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :busdc, :pb_dc_pos_vio, _PM.ids(pm, nw, :busdc), pb_dc_pos_vio)
end 

function variable_converter_current_violation(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    i_conv_vio = _PM.var(pm, nw)[:i_conv_vio] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_i_conv_vio",
    )

    if bounded
        for i in _PM.ids(pm, nw, :convdc)
            JuMP.set_lower_bound(i_conv_vio[i], 0.0)
            JuMP.set_upper_bound(i_conv_vio[i], 1e1)
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :i_conv_vio, _PM.ids(pm, nw, :convdc), i_conv_vio)
end 


# function variable_c1_voltage_response(pm::_PM.AbstractPowerModel; kwargs...)
#     variable_c1_voltage_response_positive(pm::_PM.AbstractPowerModel; kwargs...)
#     variable_c1_voltage_response_negative(pm::_PM.AbstractPowerModel; kwargs...) 
# end 
# function variable_c1_voltage_response_positive(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
#     vg_pos = _PM.var(pm, nw)[:vg_pos] = JuMP.@variable(pm.model,
#         [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_vg_pos",
#     )             
    
#     if bounded
#         for i in _PM.ids(pm, nw, :bus)        
#             JuMP.set_lower_bound(vg_pos[i], 0.0)   
#             #JuMP.set_upper_bound(vg_pos[i], JuMP.upper_bound(_PM.var(pm, nw, :vm, i)) - JuMP.lower_bound(_PM.var(pm, nw, :vm, i)))
#         end
#     end

#     report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :vg_pos, _PM.ids(pm, nw, :bus), vg_pos)
# end
# function variable_c1_voltage_response_negative(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
#     vg_neg = _PM.var(pm, nw)[:vg_neg] = JuMP.@variable(pm.model,
#         [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_vg_neg",
#     )
    
#     if bounded
#         for i in _PM.ids(pm, nw, :bus)
#             JuMP.set_lower_bound(vg_neg[i], 0.0)   
#             #JuMP.set_upper_bound(vg_neg[i], JuMP.upper_bound(_PM.var(pm, nw, :vm, i)) - JuMP.lower_bound(_PM.var(pm, nw, :vm, i)))
#         end
#     end
#     report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :vg_neg, _PM.ids(pm, nw, :bus), vg_neg)
# end 

# "variable controling a linear converter responce "
# function variable_conv_response_delta(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, report::Bool=true)
#     delta_conv = _PM.var(pm, nw)[:delta_conv] = JuMP.@variable(pm.model,
#         base_name="$(nw)_delta_conv",
#         start = 0.0
#     )

#     if report
#         _PM.sol(pm, nw)[:delta_conv] = delta_conv
#     end
# end


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

    droopv1 = _PM.var(pm, nw)[:droopv1] = JuMP.@variable(pm.model,
    [i in 1:length(_PM.ref(pm, nw, :convdc))], base_name="$(nw)_droopv1",
    )

    if bounded
        for i in 1:length(_PM.ref(pm, nw, :convdc))
            JuMP.set_lower_bound(droopv1[i], 0.005)
            JuMP.set_upper_bound(droopv1[i], 0.01)
        end
    end

    droopv2 = _PM.var(pm, nw)[:droopv2] = JuMP.@variable(pm.model,
    [i in 1:length(_PM.ref(pm, nw, :convdc))], base_name="$(nw)_droopv2",
    )

    # if bounded
    #     for i in 1:length(_PM.ref(pm, nw, :convdc))
    #         JuMP.set_lower_bound(droopv2[i], 0.00001)
    #         JuMP.set_upper_bound(droopv2[i], 0.01)
    #     end
    # end
    

    # report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x1, _PM.ids(pm, nw, :convdc), x1)
    # report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x2, _PM.ids(pm, nw, :convdc), x2)
    # report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x3, _PM.ids(pm, nw, :convdc), x3)
    # report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x4, _PM.ids(pm, nw, :convdc), x4)
    # report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :x5, _PM.ids(pm, nw, :convdc), x5)
    # report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :droopv1, _PM.ids(pm, nw, :convdc), droopv1)
    # report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :droopv2, _PM.ids(pm, nw, :convdc), droopv2)
end 

# function variable_gen_power(pm::_PM.AbstractPowerModel; kwargs...)
#     _PM.variable_gen_power_real(pm; kwargs...)
#     variable_gen_power_imaginary(pm; kwargs...)
# end



# "variable: `qq[j]` for `j` in `gen`"
# function variable_gen_power_imaginary(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
#     qg = _PM.var(pm, nw)[:qg] = JuMP.@variable(pm.model,
#         [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_qg",
#         start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "qg_start")
#     )
#     bounded=true
#     if bounded
#         for (i, gen) in _PM.ref(pm, nw, :gen)
#             JuMP.set_lower_bound(qg[i], gen["qmin"])
#             JuMP.set_upper_bound(qg[i], gen["qmax"])
#         end
#     end

#     report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :qg, _PM.ids(pm, nw, :gen), qg)
# end
function variable_generator_reactive_power_bounds(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    qglb = _PM.var(pm, nw)[:qglb] = JuMP.@variable(pm.model,
        [i in 1:length(_PM.ref(pm, nw, :gen))], base_name="$(nw)_qglb",
    )
    
    # if bounded
    #     for i in 1:length(_PM.ref(pm, nw, :gen))
    #         JuMP.set_lower_bound(qglb[i], 0.0)   
    #         JuMP.set_upper_bound(qglb[i], 10.0)
    #     end
    # end
    #report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :qglb, _PM.ids(pm, nw, :gen), qglb)
end

function variable_dc_converter_soft(pm::_PM.AbstractPowerModel; kwargs...)
    _PMACDC.variable_conv_tranformer_flow(pm; kwargs...)
    _PMACDC.variable_conv_reactor_flow(pm; kwargs...)

    _PMACDC.variable_converter_active_power(pm; kwargs...)
    _PMACDC.variable_converter_reactive_power(pm; kwargs...)
    variable_acside_current(pm; kwargs...)
    _PMACDC.variable_dcside_power(pm; kwargs...)
    _PMACDC.variable_converter_firing_angle(pm; kwargs...)

    _PMACDC.variable_converter_filter_voltage(pm; kwargs...)
    _PMACDC.variable_converter_internal_voltage(pm; kwargs...)

    _PMACDC.variable_converter_to_grid_active_power(pm; kwargs...)
    _PMACDC.variable_converter_to_grid_reactive_power(pm; kwargs...)
end

"variable: `iconv_ac[j]` for `j` in `convdc`"
function variable_acside_current(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool = false, report::Bool=true)
    ic = _PM.var(pm, nw)[:iconv_ac] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_iconv_ac",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "P_g", 1.0)
    )
    if bounded
        for (c, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(ic[c],  0)
            JuMP.set_upper_bound(ic[c],  convdc["Imax"])
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :iconv, _PM.ids(pm, nw, :convdc), ic)
end


######## MINLP validation #############

function variable_gen_response_binary(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, report::Bool=true)
    
        xp_u = _PM.var(pm, nw)[:xp_u] = JuMP.@variable(pm.model,
            [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_xp_u",
            binary = true,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "xp_u_start", 1.0)
        )

        xp_l = _PM.var(pm, nw)[:xp_l] = JuMP.@variable(pm.model,
            [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_xp_l",
            binary = true,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "xp_l_start", 1.0)
        )

        xq_u = _PM.var(pm, nw)[:xq_u] = JuMP.@variable(pm.model,
            [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_xq_u",
            binary = true,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "xq_u_start", 1.0)
        )

        xq_l = _PM.var(pm, nw)[:xq_l] = JuMP.@variable(pm.model,
            [i in _PM.ids(pm, nw, :gen)], base_name="$(nw)_xq_l",
            binary = true,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "xq_l_start", 1.0)
        )

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :xp_u, _PM.ids(pm, nw, :gen), xp_u)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :xp_l, _PM.ids(pm, nw, :gen), xp_l)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :xq_u, _PM.ids(pm, nw, :gen), xq_u)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :xq_l, _PM.ids(pm, nw, :gen), xq_l)

end

function variable_conv_droop_binary(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, report::Bool=true)
    
    xd_a = _PM.var(pm, nw)[:xd_a] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_xd_a",
        binary = true,
        start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "xd_a_start", 1.0)
    )

    xd_b = _PM.var(pm, nw)[:xd_b] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_xd_b",
        binary = true,
        start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "xd_b_start", 1.0)
    )

    xd_c = _PM.var(pm, nw)[:xd_c] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_xd_c",
        binary = true,
        start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "xd_c_start", 1.0)
    )

    xd_d = _PM.var(pm, nw)[:xd_d] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_xd_d",
        binary = true,
        start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "xd_d_start", 1.0)
    )

    xd_e = _PM.var(pm, nw)[:xd_e] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_xd_e",
        binary = true,
        start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "xd_e_start", 1.0)
    )

report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :xd_a, _PM.ids(pm, nw, :convdc), xd_a)
report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :xd_b, _PM.ids(pm, nw, :convdc), xd_b)
report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :xd_c, _PM.ids(pm, nw, :convdc), xd_c)
report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :xd_d, _PM.ids(pm, nw, :convdc), xd_d)
report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :xd_e, _PM.ids(pm, nw, :convdc), xd_e)

end

# function variable_shunt_admittance_imaginary(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
#     bs_var = _PM.var(pm, nw)[:bs_var] = JuMP.@variable(pm.model,
#         [i in _PM.ids(pm, nw, :bus)], base_name="$(nw)_bs_var",
#         start = _PM.comp_start_value(_PM.ref(pm, nw, :bus, i), "bs_var_start")
#     )

#     # if bounded
#     #     for i in _PM.ids(pm, nw, :bus)
#     #         if haskey(pm.ref[:it][:pm][:nw][nw][:shunt], i) 
#     #             shunt = _PM.ref(pm, nw, :shunt, i)
#     #             JuMP.set_lower_bound(bs_var[i], shunt["bmin"])
#     #             JuMP.set_upper_bound(bs_var[i], shunt["bmax"])
#     #         else
#     #             JuMP.set_lower_bound(bs_var[i], 0)
#     #             JuMP.set_upper_bound(bs_var[i], 0)
#     #         end
#     #     end
#     # end

#     report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :bs_var, _PM.ids(pm, nw, :bus), bs_var)
# end

# dc branch violation slack for scopf ptdf dcdf cuts
function variable_branchdc_contigency_power_violation(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    branchdc_cont_flow_vio = _PM.var(pm, nw)[:branchdc_cont_flow_vio] = JuMP.@variable(pm.model,
        [i in 1:length(_PM.ref(pm, :branchdc_flow_cuts))], base_name="$(nw)_branchdc_cont_flow_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in 1:length(_PM.ref(pm, :branchdc_flow_cuts))
            JuMP.set_lower_bound(branchdc_cont_flow_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :gen, :pg_delta, ids(pm, nw, :gen), pg_delta)
end