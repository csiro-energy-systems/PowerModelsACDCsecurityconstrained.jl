function run_acdcopf_acr(file::String, model_type::Type, solver; kwargs...)
    data = _PM.parse_file(file)
    _PMACDC.process_additional_data!(data)
    return run_acdcopf_acr(data, model_type, solver; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function run_acdcopf_acr(data::Dict{String,Any}, model_type::Type, solver; kwargs...)
    return _PM.run_model(data, model_type, solver, post_acdcopf; ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
end

""
function post_acdcopf(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)

    _PMACDC.variable_active_dcbranch_flow(pm)
    _PMACDC.variable_dcbranch_current(pm)
    variable_dc_converter(pm)
    #variable_conv_loss_McCormick_envelope(pm)
    _PMACDC.variable_dcgrid_voltage_magnitude(pm)
    #variable_ac_side_converter_voltage_magnitude_sqr(pm)
    variable_ac_side_converter_current_magnitude_sqr(pm)
    variable_ac_side_converter_current_magnitude(pm)

    _PM.objective_min_fuel_cost(pm)

    _PM.constraint_model_voltage(pm)
    _PMACDC.constraint_voltage_dc(pm)

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        constraint_power_balance_ac(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        _PM.constraint_ohms_yt_from(pm, i)
        _PM.constraint_ohms_yt_to(pm, i)
        _PM.constraint_voltage_angle_difference(pm, i) #angle difference across transformer and reactor - useful for LPAC if available?
        _PM.constraint_thermal_limit_from(pm, i)
        _PM.constraint_thermal_limit_to(pm, i)
    end
    for i in _PM.ids(pm, :busdc)
        _PMACDC.constraint_power_balance_dc(pm, i)
    end
    for i in _PM.ids(pm, :branchdc)
        constraint_ohms_dc_branch(pm, i)
    end
    for i in _PM.ids(pm, :convdc)
        constraint_ac_side_converter_current_magnitude(pm, i)
        constraint_converter_losses(pm, i)
        constraint_converter_current(pm, i)
        constraint_conv_transformer(pm, i)
        constraint_conv_reactor(pm, i)
        constraint_conv_filter(pm, i)
        if pm.ref[:it][:pm][:nw][_PM.nw_id_default][:convdc][i]["islcc"] == 1
           constraint_conv_firing_angle(pm, i)
        end
    end
end



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
            JuMP.set_lower_bound(vrf[c],  -convdc["Vmmax"]* bigM )   # convdc["Vmmin"] / bigM
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
"variable: `me[j]` for `j` in `convdc` used to define McCormick envelopes to linearize sqrt(irc^2 +iic^2) term in converter loss constraint" 
function variable_conv_loss_McCormick_envelope(pm::_PM.AbstractACRModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    me = _PM.var(pm, nw)[:me] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_me",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc, i), "me", 0)
    )
    if bounded
        for (c, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(me[c], 0)
            JuMP.set_upper_bound(me[c],  convdc["Imax"])
        end
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :me, _PM.ids(pm, nw, :convdc), me)
end

## lifting variables

function variable_ac_side_converter_voltage_magnitude_sqr(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true, aux_fix::Bool=false)
    vcs = _PM.var(pm, nw)[:vcs] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_vcs",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc, i), "vcs", 1.0)^2
    )

    if bounded
        for (i, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(vcs[i],  convdc["Vmmin"]^2)
            JuMP.set_upper_bound(vcs[i],  convdc["Vmmax"]^2)
        end
    end

    if aux_fix 
        JuMP.fix.(vcs, 1.0; force=true)
        JuMP.fix.(vcs, 1.0; force=true)
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :vcs, _PM.ids(pm, nw, :convdc), vcs)
end

function variable_ac_side_converter_current_magnitude_sqr(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true, aux_fix::Bool=false)
    ics = _PM.var(pm, nw)[:ics] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_ics",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc, i), "ics", 1)^2
    )

    if bounded
        for (i, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(ics[i],  0)
            JuMP.set_upper_bound(ics[i],  convdc["Imax"]^2)
        end
    end

    #if aux_fix 
    #    JuMP.fix.(ics, 1.0; force=true)
    #    JuMP.fix.(ics, 1.0; force=true)
    #end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :ics, _PM.ids(pm, nw, :convdc), ics)
end

function variable_ac_side_converter_current_magnitude(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true, aux_fix::Bool=false)
    ic = _PM.var(pm, nw)[:ic] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :convdc)], base_name="$(nw)_ic",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc, i), "ic", 1)
    )

    if bounded
        for (i, convdc) in _PM.ref(pm, nw, :convdc)
            JuMP.set_lower_bound(ic[i],  0)
            JuMP.set_upper_bound(ic[i],  convdc["Imax"])
        end
    end

    #if aux_fix 
    #    JuMP.fix.(ic, 1.0; force=true)
    #    JuMP.fix.(ic, 1.0; force=true)
    #end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :convdc, :ic, _PM.ids(pm, nw, :convdc), ic)
end

## Constraints!!!
function constraint_ac_side_converter_current_magnitude(pm::_PM.AbstractACRModel, i::Int; nw::Int=_PM.nw_id_default)
     constraint_ac_side_converter_current_magnitude(pm, nw, i)
end
function constraint_ac_side_converter_current_magnitude(pm::_PM.AbstractACRModel, n::Int, i::Int)
    ic = _PM.var(pm, n, :ic, i)
    ics = _PM.var(pm, n, :ics, i)
    irconv = _PM.var(pm, n, :irconv_ac, i)
    iiconv = _PM.var(pm, n, :iiconv_ac, i)
    #vcs = _PM.var(pm, n, :vcs, i)
    #vrc = _PM.var(pm, n, :vrc, i)
    #vic = _PM.var(pm, n, :vic, i)

    JuMP.@constraint(pm.model, ics == ic^2)
    #JuMP.@constraint(pm.model, ics == irconv^2 + iiconv^2)
    #JuMP.@constraint(pm.model, vcs == vrc^2 + vic^2)
end

function constraint_ohms_dc_branch(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branchdc, i)
    f_bus = branch["fbusdc"]
    t_bus = branch["tbusdc"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    p = _PM.ref(pm, nw, :dcpol)

    constraint_ohms_dc_branch(pm, nw, f_bus, t_bus, f_idx, t_idx, branch["r"], p)
end

function constraint_ohms_dc_branch(pm::_PM.AbstractACRModel, n::Int,  f_bus, t_bus, f_idx, t_idx, r, p)
    p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
    vmdc_fr = _PM.var(pm, n,  :vdcm, f_bus)
    vmdc_to = _PM.var(pm, n,  :vdcm, t_bus)

    if r == 0
        JuMP.@constraint(pm.model, p_dc_fr + p_dc_to == 0)
    else
        g = 1 / r
        JuMP.@NLconstraint(pm.model, p_dc_fr == p * g * vmdc_fr * (vmdc_fr - vmdc_to))
        JuMP.@NLconstraint(pm.model, p_dc_to == p * g * vmdc_to * (vmdc_to - vmdc_fr))
    end
end
function constraint_converter_losses(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default) # Constraint Template
    conv = _PM.ref(pm, nw, :convdc, i)
    a = conv["LossA"]
    b = conv["LossB"]
    c = conv["LossCinv"]
    plmax = conv["LossA"] + conv["LossB"] * conv["Pacrated"] + conv["LossCinv"] * (conv["Pacrated"])^2
    big_M = conv["Imax"]
   
    constraint_converter_losses(pm, nw, i, a, b, c, plmax, big_M)
end

function constraint_converter_losses(pm::_PM.AbstractACRModel, n::Int, i::Int, a, b, c, plmax, big_M) # Constraint
    pconv_ac = _PM.var(pm, n, :pconv_ac, i)
    pconv_dc = _PM.var(pm, n, :pconv_dc, i)
    irconv = _PM.var(pm, n, :irconv_ac, i)
    iiconv = _PM.var(pm, n, :iiconv_ac, i)
    ics = _PM.var(pm, n, :ics, i)
    ic = _PM.var(pm, n, :ic, i)
    #me = _PM.var(pm, n, :me, i)

    #JuMP.@NLconstraint(pm.model, pconv_ac + pconv_dc == a + b*sqrt(irconv^2 + iiconv^2) + c*(irconv^2 + iiconv^2))   # Linearizing sqrt(irconv^2 + iiconv^2) using McCormick envelopes
    #JuMP.@constraint(pm.model, pconv_ac + pconv_dc == a + b * me + c * (me^2))
    #JuMP.@constraint(pm.model, -(irconv^2 + iiconv^2) - 2 * big_M * me <= (big_M^2))
    #JuMP.@constraint(pm.model, -(irconv^2 + iiconv^2) + 2 * big_M * me <= (big_M^2))
    #JuMP.@constraint(pm.model, (irconv^2 + iiconv^2) <= (big_M^2))
    #JuMP.@constraint(pm.model, (irconv^2 + iiconv^2) >= 0)

    #JuMP.@constraint(pm.model, pconv_ac + pconv_dc == a + b * me + c * (me^2))
    #JuMP.@constraint(pm.model, -(ics^2) - 2 * big_M * me <= (big_M^2))
    #JuMP.@constraint(pm.model, -(ics^2) + 2 * big_M * me <= (big_M^2))
    #JuMP.@constraint(pm.model, (ics^2) <= (big_M^2))
    #JuMP.@constraint(pm.model, (ics^2) >= 0)

    JuMP.@constraint(pm.model, pconv_ac + pconv_dc == a + b * ic + c * ics)
end

# function constraint_converter_current(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)  # Constraint Template
#     conv = _PM.ref(pm, nw, :convdc, i)
#     Vmax = conv["Vmmax"]
#     Imax = conv["Imax"]
#     constraint_converter_current(pm, nw, i, Vmax, Imax)
# end
function constraint_converter_current(pm::_PM.AbstractACRModel, n::Int, i::Int, Umax, Imax) # Constraint
    vrc = _PM.var(pm, n, :vrc, i)
    vic = _PM.var(pm, n, :vic, i)
    pconv_ac = _PM.var(pm, n, :pconv_ac, i)
    qconv_ac = _PM.var(pm, n, :qconv_ac, i)
    irconv = _PM.var(pm, n, :irconv_ac, i)
    iiconv = _PM.var(pm, n, :iiconv_ac, i)
    #vcs = _PM.var(pm, n, :vcs, i)
    ics = _PM.var(pm, n, :ics, i)
    ic = _PM.var(pm, n, :ic, i)

    JuMP.@NLconstraint(pm.model, pconv_ac^2 + qconv_ac^2 == (vrc^2 + vic^2) * ics)         
end
function constraint_conv_transformer(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    constraint_conv_transformer(pm, nw, i, conv["rtf"], conv["xtf"], conv["busac_i"], conv["tm"], Bool(conv["transformer"]))
end
function constraint_conv_transformer(pm::_PM.AbstractACRModel, n::Int, i::Int, rtf, xtf, acbus, tm, transformer)
    ptf_fr = _PM.var(pm, n, :pconv_tf_fr, i)
    qtf_fr = _PM.var(pm, n, :qconv_tf_fr, i)
    ptf_to = _PM.var(pm, n, :pconv_tf_to, i)
    qtf_to = _PM.var(pm, n, :qconv_tf_to, i)

    vr = _PM.var(pm, n, :vr, acbus)
    vi = _PM.var(pm, n, :vi, acbus)
    vrf = _PM.var(pm, n, :vrf, i)      
    vif = _PM.var(pm, n, :vif, i) 

    ztf = rtf + im*xtf
    if transformer
        ytf = 1/(rtf + im*xtf)
        gtf = real(ytf)
        btf = imag(ytf)
        gtf_sh = 0
        btf_sh = 0
        gf_sh = 0
        bf_sh = 0
        tr = 1
        ti = 0
        
        JuMP.@NLconstraint(pm.model, ptf_fr ==  gtf / tm^2 * (vr^2 + vi^2)         + -gtf / tm * (vr * vrf + vi * vif)           + -btf / tm * (vi * vrf - vr * vif) )
        JuMP.@NLconstraint(pm.model, qtf_fr == -btf / tm^2 * (vr^2 + vi^2)         - -btf / tm * (vr * vrf + vi * vif)           + -gtf / tm * (vi * vrf - vr * vif) )
        JuMP.@NLconstraint(pm.model, ptf_to ==  gtf * (vrf^2 + vif^2)              + -gtf / tm * (vr * vrf + vi * vif)           + -btf / tm * (-(vi * vrf - vr * vif)) )
        JuMP.@NLconstraint(pm.model, qtf_to == -btf * (vrf^2 + vif^2)              - -btf / tm * (vr * vrf + vi * vif)           + -gtf / tm * (-(vi * vrf - vr * vif)) )

    else
        
        JuMP.@constraint(pm.model, ptf_fr + ptf_to == 0)
        JuMP.@constraint(pm.model, qtf_fr + qtf_to == 0)
        JuMP.@constraint(pm.model, vr == vrf)
        JuMP.@constraint(pm.model, vi == vif)
    end
end


function constraint_conv_reactor(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    constraint_conv_reactor(pm, i, nw, conv["rc"], conv["xc"], Bool(conv["reactor"]))
end
function constraint_conv_reactor(pm::_PM.AbstractACRModel, i::Int, n::Int, rc, xc, reactor)
    pconv_ac = _PM.var(pm, n,  :pconv_ac, i)
    qconv_ac = _PM.var(pm, n,  :qconv_ac, i)
    ppr_to = - pconv_ac
    qpr_to = - qconv_ac
    ppr_fr = _PM.var(pm, n,  :pconv_pr_fr, i)
    qpr_fr = _PM.var(pm, n,  :qconv_pr_fr, i)

    vrf = _PM.var(pm, n, :vrf, i) 
    vif = _PM.var(pm, n, :vif, i) 
    vrc = _PM.var(pm, n, :vrc, i) 
    vic = _PM.var(pm, n, :vic, i) 

    #vcs = _PM.var(pm, n, :vcs, i)
    #ics = _PM.var(pm, n, :ics, i)

    zc = rc + im*xc
    if reactor
        yc = 1/(zc)
        gc = real(yc)
        bc = imag(yc)                                      
        JuMP.@NLconstraint(pm.model, - pconv_ac ==  gc * (vrc^2 + vic^2 ) + -gc * (vrc * vrf + vic * vif) + -bc * (vic * vrf - vrc * vif))  
        JuMP.@NLconstraint(pm.model, - qconv_ac == -bc * (vrc^2 + vic^2 ) +  bc * (vrc * vrf + vic * vif) + -gc * (vic * vrf - vrc * vif)) 
        JuMP.@NLconstraint(pm.model, ppr_fr ==  gc * (vrf^2 + vif^2) + -gc * (vrc * vrf + vic * vif) + -bc * (-(vic * vrf - vrc * vif)))
        JuMP.@NLconstraint(pm.model, qpr_fr == -bc * (vrf^2 + vif^2) +  bc * (vrc * vrf + vic * vif) + -gc * (-(vic * vrf - vrc * vif)))


    else
        JuMP.@constraint(pm.model, ppr_fr + ppr_to == 0)
        JuMP.@constraint(pm.model, qpr_fr + qpr_to == 0)
        JuMP.@constraint(pm.model, vrc == vrf)
        JuMP.@constraint(pm.model, vic == vif)
    end
end

function constraint_conv_filter(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    constraint_conv_filter(pm, nw, i, conv["bf"], Bool(conv["filter"]) )
end
function constraint_conv_filter(pm::_PM.AbstractACRModel, n::Int, i::Int, bv, filter)
    ppr_fr = _PM.var(pm, n, :pconv_pr_fr, i)
    qpr_fr = _PM.var(pm, n, :qconv_pr_fr, i)
    ptf_to = _PM.var(pm, n, :pconv_tf_to, i)
    qtf_to = _PM.var(pm, n, :qconv_tf_to, i)

    vrf = _PM.var(pm, n, :vrf, i)
    vif = _PM.var(pm, n, :vif, i)
    
    JuMP.@constraint(pm.model,   ppr_fr + ptf_to == 0 )
   JuMP.@constraint(pm.model, qpr_fr + qtf_to +  (-bv) * filter *(vrf^2 + vif^2) == 0)
   
end
function constraint_conv_firing_angle(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    S = conv["Pacrated"]
    P1 = cos(0) * S
    Q1 = sin(0) * S
    P2 = cos(pi) * S
    Q2 = sin(pi) * S
    constraint_conv_firing_angle(pm, nw, i, S, P1, Q1, P2, Q2)
end
function constraint_conv_firing_angle(pm::_PM.AbstractACRModel, n::Int, i::Int, S, P1, Q1, P2, Q2)
    p = _PM.var(pm, n, :pconv_ac, i)
    q = _PM.var(pm, n, :qconv_ac, i)
    phi = _PM.var(pm, n, :phiconv, i)

    JuMP.@NLconstraint(pm.model,   p == cos(phi) * S)
    JuMP.@NLconstraint(pm.model,   q == sin(phi) * S)
end
# power balance
""
function constraint_power_balance_ac(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    bus_arcs   = _PM.ref(pm, nw, :bus_arcs, i)
    bus_gens   = _PM.ref(pm, nw, :bus_gens, i)
    bus_loads  = _PM.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PM.ref(pm, nw, :bus_shunts, i)
    bus_convs_ac = _PM.ref(pm, nw, :bus_convs_ac, i)

    bus_pd = Dict(k => _PM.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => _PM.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_power_balance_ac(pm, nw, i, bus_arcs, bus_gens, bus_convs_ac, bus_loads, bus_shunts, bus_pd, bus_qd, bus_gs, bus_bs)
end
function constraint_power_balance_ac(pm::_PM.AbstractACRModel, n::Int, i::Int, bus_arcs, bus_gens, bus_convs_ac, bus_loads, bus_shunts, bus_pd, bus_qd, bus_gs, bus_bs)
    vr = _PM.var(pm, n, :vr, i)
    vi = _PM.var(pm, n, :vi, i)
    p    = _PM.var(pm, n, :p)
    q    = _PM.var(pm, n, :q) 
    pg   = _PM.var(pm, n, :pg) 
    qg   = _PM.var(pm, n, :qg) 
    pconv_grid_ac = _PM.var(pm, n,  :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n,  :qconv_tf_fr)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*(vr^2 + vi^2))
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac) == sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs))*(vr^2 + vi^2))
end


