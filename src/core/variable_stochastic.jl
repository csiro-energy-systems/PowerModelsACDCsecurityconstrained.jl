
"All converter variables"
function variable_dc_converter(pm::_PM.AbstractPowerModel; kwargs...)
    _PMACDC.variable_conv_tranformer_flow(pm; kwargs...)
    _PMACDC.variable_conv_reactor_flow(pm; kwargs...)
    _PMACDC.variable_converter_active_power(pm; kwargs...)
    _PMACDC.variable_converter_reactive_power(pm; kwargs...)

    variable_acside_current(pm; kwargs...)

    _PMACDC.variable_dcside_power(pm; kwargs...)
    _PMACDC.variable_converter_firing_angle(pm; kwargs...)

    variable_converter_filter_voltage(pm; kwargs...)
    variable_converter_internal_voltage(pm; kwargs...)

    _PMACDC.variable_converter_to_grid_active_power(pm; kwargs...)
    _PMACDC.variable_converter_to_grid_reactive_power(pm; kwargs...)
end

##

function variable_converter_filter_voltage(pm::_PM.AbstractACRModel; kwargs...)
    variable_converter_filter_voltage_real(pm; kwargs...)
    variable_converter_filter_voltage_imaginary(pm; kwargs...)
end


"real part of the voltage variable `vrf[j]` for `j` in `convdc`"
function variable_converter_filter_voltage_real(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    bigM = 1.2; # only internal converter voltage is strictly regulated
    vrf = _PM.var(pm, nw)[:vrf] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_vrf",
    start = _PM.ref(pm, nw, :convdc, i, "Vtar")
    )
    if bounded
        for (c, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(vrf[c], -convdc["Vmmax"]* bigM)   # convdc["Vmmin"] / bigM
            JuMP.set_upper_bound(vrf[c],  convdc["Vmmax"]* bigM)   # convdc["Vmmax"] * bigM
        end
    end
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :vrfilt, _PM.ids(pm, nw, :convdc), vrf)
end

"imaginary part of the voltage variable `vif[j]` for `j` in `convdc`"
function variable_converter_filter_voltage_imaginary(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    bigM = 1.2; #2*pi
    vif = _PM.var(pm, nw)[:vif] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_vif",
    start = 0
    )
    if bounded
        for (c, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(vif[c], -convdc["Vmmax"]* bigM)
            JuMP.set_upper_bound(vif[c],  convdc["Vmmax"]* bigM)
        end
    end
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :vifilt, _PM.ids(pm, nw, :convdc), vif)
end

##

function variable_converter_internal_voltage(pm::_PM.AbstractACRModel; kwargs...)
    variable_converter_internal_voltage_real(pm; kwargs...)
    variable_converter_internal_voltage_imaginary(pm; kwargs...)
end


"real part of the voltage variable `vrc[j]` for `j` in `convdc`"
function variable_converter_internal_voltage_real(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    vrc = _PM.var(pm, nw)[:vrc] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_vrc",
    start = _PM.ref(pm, nw, :convdc, i, "Vtar")
    )
    if bounded
        for (c, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(vrc[c], -convdc["Vmmax"])
            JuMP.set_upper_bound(vrc[c],  convdc["Vmmax"])
        end
    end
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :vrconv, _PM.ids(pm, nw, :convdc), vrc)
end

"imaginary part of the voltage variable `vic[j]` for `j` in `convdc`"
function variable_converter_internal_voltage_imaginary(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    bigM = 1E6; #2*pi
    vic = _PM.var(pm, nw)[:vic] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_vic",
    start = 0
    )
    if bounded
        for (c, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(vic[c], -convdc["Vmmax"])
            JuMP.set_upper_bound(vic[c],  convdc["Vmmax"])
        end
    end
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :viconv, _PM.ids(pm, nw, :convdc), vic)
end

##
function variable_acside_current(pm::_PM.AbstractACRModel; kwargs...)
    variable_acside_current_real(pm; kwargs...)
    variable_acside_current_imaginary(pm; kwargs...)
end
"variable: `irconv_ac[j]` for `j` in `convdc`"
function variable_acside_current_real(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    irc = _PM.var(pm, nw)[:irconv_ac] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_irconv_ac",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "P_g", 1.0)
    )
    if bounded
        for (c, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(irc[c], -convdc["Imax"])
            JuMP.set_upper_bound(irc[c],  convdc["Imax"])
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :irconv, _PM.ids(pm, nw, :convdc), irc)
end
"variable: `iiconv_ac[j]` for `j` in `convdc`"
function variable_acside_current_imaginary(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    iic = _PM.var(pm, nw)[:iiconv_ac] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_iiconv_ac",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "P_g", 1.0)
    )
    if bounded
        for (c, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(iic[c], -convdc["Imax"])
            JuMP.set_upper_bound(iic[c],  convdc["Imax"])
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :iiconv, _PM.ids(pm, nw, :convdc), iic)
end

"variable: `iconv_ac[j]` and `iconv_ac_sq[j]` for `j` in `convdc`"
#function variable_acside_current(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
#    ic = _PM.var(pm, nw)[:iconv_ac] = JuMP.@variable(pm.model,
#    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_iconv_ac",
#    start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "P_g", 1.0)
#    )
#    icsq = _PM.var(pm, nw)[:iconv_ac_sq] = JuMP.@variable(pm.model,
#    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_iconv_ac_sq",
#    start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "P_g", 1.0)
#    )
#    if bounded
#        for (c, convdc) in _PM.ref(pm, nw, :convdc)
#            JuMP.set_lower_bound(ic[c],  0)
#            JuMP.set_upper_bound(ic[c],  convdc["Imax"])
#            JuMP.set_lower_bound(icsq[c],  0)
#            JuMP.set_upper_bound(icsq[c],  convdc["Imax"]^2)
#        end
#    end

#    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :iconv_ac, _PM.ids(pm, nw, :convdc), ic)
#    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :iconv_ac_sq, _PM.ids(pm, nw, :convdc), icsq)
#end