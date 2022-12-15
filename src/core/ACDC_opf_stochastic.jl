################################################################################
#  Copyright 2021, Arpan Koirala, Tom Van Acker                                #
################################################################################
# StochasticPowerModels.jl                                                     #
# An extention package of PowerModels.jl for Stochastic (Optimal) Power Flow   #
# See http://github.com/timmyfaraday/StochasticPowerModels.jl                  #
################################################################################
# NOTE: dc lines are omitted from the current formulation                      #
################################################################################

""
function run_sopf_acr_GM(data::Dict, model_constructor::Type, optimizer; aux::Bool=true, deg::Int=1, solution_processors=[_SPM.sol_data_model!], kwargs...)
    @assert _IM.ismultinetwork(data) == false "The data supplied is multinetwork, it should be single-network"
    @assert model_constructor <: _PM.AbstractACRModel "This problem type only supports the ACRModel"

    sdata = _SPM.build_stochastic_data(data, deg)
    if aux
        result = _PM.run_model(sdata, model_constructor, optimizer, build_sopf_acr_with_aux; multinetwork=true, solution_processors=solution_processors, ref_extensions = [_PMACDC.add_ref_dcgrid!], kwargs...)
    else
        result = _PM.run_model(sdata, model_constructor, optimizer, build_sopf_acr_without_aux; ref_extensions = [_PMACDC.add_ref_dcgrid!], multinetwork=true, solution_processors=solution_processors, kwargs...)
    end
    result["mop"] = sdata["mop"]
    return result
end

""
function run_sopf_acr_GM(file::String, model_constructor, optimizer; aux::Bool=true, deg::Int=1, solution_processors=[_SPM.sol_data_model!], kwargs...)
    data = _PM.parse_file(file)
    return run_sopf_acr_GM(data, model_constructor, optimizer; aux=aux, deg=deg, ref_extensions = [_PMACDC.add_ref_dcgrid!], solution_processors=solution_processors, kwargs...)
end

""
function build_sopf_acr_with_aux(pm::_PM.AbstractPowerModel)
    for (n, network) in _PM.nws(pm) 
        _SPM.variable_bus_voltage(pm, nw=n, aux=true)
        _SPM.variable_gen_power(pm, nw=n, bounded=false)
        _SPM.variable_branch_power(pm, nw=n, bounded=false)
        _SPM.variable_branch_current(pm, nw=n, bounded=false, aux=true) 

        _PMACDC.variable_active_dcbranch_flow(pm, nw=n)
        _PMACDC.variable_dcbranch_current(pm, nw=n)
        variable_dc_converter(pm, nw=n)
        _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=n)                 #

        #variable_dcgrid_voltage_magnitude(pm, nw=n, aux=true)
        #variable_active_dcbranch_flow(pm, nw=n, bounded=false)
        #variable_dcbranch_current(pm, nw=n, bounded=false, aux=true)
        #_PMACDC.variable_dc_converter(pm, nw=n)
    
    end


    for i in _PM.ids(pm, :bus,nw=1)
        _SPM.constraint_bus_voltage_squared_cc_limit(pm, i, nw=1)
    end

    for g in _PM.ids(pm, :gen, nw=1)
        _SPM.constraint_gen_power_cc_limit(pm, g, nw=1)
    end

    for b in _PM.ids(pm, :branch, nw=1)
        _SPM.constraint_branch_series_current_squared_cc_limit(pm, b, nw=1)
    end

    for (n, network) in _PM.nws(pm)
        for i in _PM.ids(pm, :ref_buses, nw=n)
            _SPM.constraint_bus_voltage_ref(pm, i, nw=n)
        end

        #for i in _PM.ids(pm, :bus, nw=n)
        #    expression_bus_voltage_variable(pm, i, nw=n)
        #end

        for i in _PM.ids(pm, :bus, nw=n)
            constraint_power_balance_ac(pm, i, nw=n)                  
            _SPM.constraint_gp_bus_voltage_squared(pm, i, nw=n)         
        end

        for b in _PM.ids(pm, :branch, nw=n)                                     
            _SPM.constraint_gp_power_branch_to(pm, b, nw=n)
            _SPM.constraint_gp_power_branch_from(pm, b, nw=n)
            _SPM.constraint_branch_voltage(pm, b, nw=n)
            _SPM.constraint_gp_current_squared(pm, b, nw=n)
        end

        _PMACDC.constraint_voltage_dc(pm, nw=n)               # DC grid

        for i in _PM.ids(pm, nw=n, :busdc)                          
           _PMACDC.constraint_power_balance_dc(pm, i, nw=n)
        end

        for i in _PM.ids(pm, nw=n, :branchdc)
            constraint_ohms_dc_branch(pm, i, nw=n)
        end
        for i in _PM.ids(pm, nw=n, :convdc)
        #    constraint_converter_losses(pm, i, nw=n)
        #    constraint_converter_current(pm, i, nw=n)
            constraint_conv_transformer(pm, i, nw=n)
            constraint_conv_reactor(pm, i, nw=n)
            #constraint_conv_filter(pm, i, nw=n)
            if pm.ref[:it][:pm][:nw][n][:convdc][i]["islcc"] == 1
               constraint_conv_firing_angle(pm, i, nw=n)
            end
        end
       

    end

    _SPM.objective_min_expected_generation_cost(pm)
end

""
function constraint_ohms_dc_branch(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    branch = _PM.ref(pm, nw, :branchdc, i)
    f_bus = branch["fbusdc"]
    t_bus = branch["tbusdc"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    p = _PM.ref(pm, nw, :dcpol)
    T2  = pm.data["T2"]
    T3  = pm.data["T3"]

    constraint_ohms_dc_branch(pm, nw, f_bus, t_bus, f_idx, t_idx, branch["r"], p, T2, T3)
end
function constraint_ohms_dc_branch(pm::_PM.AbstractACRModel, n::Int,  f_bus, t_bus, f_idx, t_idx, r, p, T2, T3)
    p_dc_fr = _PM.var(pm, n,  :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n,  :p_dcgrid, t_idx)
    vmdc_fr = Dict(nw => _PM.var(pm, n,  :vdcm, f_bus) for nw in _PM.nw_ids(pm))
    vmdc_to = Dict(nw => _PM.var(pm, n,  :vdcm, t_bus) for nw in _PM.nw_ids(pm))

    if r == 0
        JuMP.@constraint(pm.model, p_dc_fr + p_dc_to == 0)
    else
        g = 1 / r
        #JuMP.@NLconstraint(pm.model, p_dc_fr == p * g * vmdc_fr * (vmdc_fr - vmdc_to))
        #JuMP.@NLconstraint(pm.model, p_dc_to == p * g * vmdc_to * (vmdc_to - vmdc_fr))
        JuMP.@constraint( pm.model, p_dc_fr * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * p * g * (vmdc_fr[n1] * vmdc_fr[n2] - vmdc_fr[n1] * vmdc_to[n2]) for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm)) )
        JuMP.@constraint( pm.model, p_dc_to * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * p * g * (vmdc_to[n1] * vmdc_to[n2] - vmdc_to[n1] * vmdc_fr[n2]) for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm)) )
    end
end
function constraint_converter_losses(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    a = conv["LossA"]
    b = conv["LossB"]
    c = conv["LossCinv"]
    plmax = conv["LossA"] + conv["LossB"] * conv["Pacrated"] + conv["LossCinv"] * (conv["Pacrated"])^2
    T2  = pm.data["T2"]
    T3  = pm.data["T3"]

    constraint_converter_losses(pm, nw, i, a, b, c, plmax, T2, T3)
end
function constraint_converter_losses(pm::_PM.AbstractACRModel, n::Int, i::Int, a, b, c, plmax, T2, T3)
    pconv_ac = _PM.var(pm, n, :pconv_ac, i)
    pconv_dc = _PM.var(pm, n, :pconv_dc, i)
    irconv = _PM.var(pm, n, :irconv_ac, i)
    iiconv = _PM.var(pm, n, :iiconv_ac, i)

    #JuMP.@NLconstraint(pm.model, pconv_ac + pconv_dc == a + b*iconv + c*iconv^2)
    #JuMP.@NLconstraint(pm.model, pconv_ac + pconv_dc == a + b*sqrt(irconv^2 + iiconv^2) + c*(irconv^2 + iiconv^2))   #

    JuMP.@constraint(pm.model, pconv_ac * T2.get([n-1,n-1]) + pconv_dc * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (a + c*(irconv[n1] * irconv[n2]  + iiconv[n1] * iiconv[n2])) for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm) ) )
end

function constraint_converter_current(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    Vmax = conv["Vmmax"]
    Imax = conv["Imax"]
    constraint_converter_current(pm, nw, i, Vmax, Imax)
end
function constraint_converter_current(pm::_PM.AbstractACRModel, n::Int, i::Int, Umax, Imax)
    vrc = _PM.var(pm, n, :vrc, i)
    vic = _PM.var(pm, n, :vic, i)
    pconv_ac = _PM.var(pm, n, :pconv_ac, i)
    qconv_ac = _PM.var(pm, n, :qconv_ac, i)
    irconv = _PM.var(pm, n, :irconv_ac, i)
    iiconv = _PM.var(pm, n, :iiconv_ac, i)
    
    #JuMP.@NLconstraint(pm.model, pconv_ac^2 + qconv_ac^2 == vmc^2 * iconv^2)
    JuMP.@NLconstraint(pm.model, pconv_ac^2 + qconv_ac^2 == (vrc^2 + vic^2) * (irconv^2 + iiconv^2))         
end
function constraint_conv_transformer(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    T2  = pm.data["T2"]
    T3  = pm.data["T3"]
    constraint_conv_transformer(pm, nw, i, conv["rtf"], conv["xtf"], conv["busac_i"], conv["tm"], Bool(conv["transformer"]), T2, T3)
end
function constraint_conv_transformer(pm::_PM.AbstractACRModel, n::Int, i::Int, rtf, xtf, acbus, tm, transformer, T2, T3)
    ptf_fr = _PM.var(pm, n, :pconv_tf_fr, i)
    qtf_fr = _PM.var(pm, n, :qconv_tf_fr, i)
    ptf_to = _PM.var(pm, n, :pconv_tf_to, i)
    qtf_to = _PM.var(pm, n, :qconv_tf_to, i)

    vr = Dict(nw => _PM.var(pm, n, :vr, acbus) for nw in _PM.nw_ids(pm))
    vi = Dict(nw => _PM.var(pm, n, :vi, acbus) for nw in _PM.nw_ids(pm))
    vrf = Dict(nw => _PM.var(pm, n, :vrf, i) for nw in _PM.nw_ids(pm))     
    vif = Dict(nw => _PM.var(pm, n, :vif, i) for nw in _PM.nw_ids(pm))

    ztf = rtf + im*xtf
    if transformer
        ytf = 1/(rtf + im*xtf)
        gtf = real(ytf)
        btf = imag(ytf)
        gtf_sh = 0
        btf_sh = 0
        gf_sh = 0
        bf_sh = 0
        tr = 0
        ti = 0
        JuMP.@constraint(pm.model, ptf_fr ==  gtf / tm^2 * (vr^2 + vi^2) + (-gtf * tr + btf * ti) / tm^2 * (vr * vrf + vi * vif) + (-btf * tr - gtf * ti) / tm^2 * (vi * vrf - vr * vif) )
        JuMP.@constraint(pm.model, qtf_fr == -btf / tm^2 * (vr^2 + vi^2) - (-btf * tr - gtf * ti) / tm^2 * (vr * vrf + vi * vif) + (-gtf * tr + btf * ti) / tm^2 * (vi * vrf - vr * vif) )
        JuMP.@constraint(pm.model, ptf_to ==  gtf * (vrf^2 + vif^2) + (-gtf * tr - btf * ti) / tm^2 * (vr * vrf + vi * vif) + (-btf * tr + gtf * ti) / tm^2 * (-(vi * vrf - vr * vif)) )
        JuMP.@constraint(pm.model, qtf_to == -btf * (vrf^2 + vif^2) - (-btf * tr + gtf * ti) / tm^2 * (vr * vrf + vi * vif) + (-gtf * tr - btf * ti) / tm^2 * (-(vi * vrf - vr * vif)) )

        #JuMP.@constraint(pm.model, ptf_fr * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (gtf / tm^2 * (vr[n1] * vr[n2] + vi[n1] * vi[n2]) + (-gtf * tr + btf * ti) / tm^2 * (vr[n1] * vrf[n2] + vi[n1] * vif[n2]) + (-btf * tr - gtf * ti) / tm^2 * (vi[n1] * vrf[n2] - vr[n1] * vif[n2]) ) 
        #for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm) ) )
        #JuMP.@constraint(pm.model, qtf_fr * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (-btf / tm^2 * (vr[n1] * vr[n2] + vi[n1] * vi[n2]) - (-btf * tr - gtf * ti) / tm^2 * (vr[n1] * vrf[n2] + vi[n1] * vif[n2]) + (-gtf * tr + btf * ti) / tm^2 * (vi[n1] * vrf[n2] - vr[n1] * vif[n2]) ) 
        #for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm) ) )
        #JuMP.@constraint(pm.model, ptf_to * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (gtf * (vrf[n1] * vrf[n2] + vif[n1] * vif[n2]) + (-gtf * tr - btf * ti) / tm^2 * (vr[n1] * vrf[n2] + vi[n1] * vif[n2]) + (-btf * tr + gtf * ti) / tm^2 * (-(vi[n1] * vrf[n2] - vr[n1] * vif[n2])) )
        #for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm) ) )
        #JuMP.@constraint(pm.model, qtf_to * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (-btf * (vrf[n1] * vrf[n2] + vif[n1] * vif[n2]) - (-btf * tr + gtf * ti) / tm^2 * (vr[n1] * vrf[n2] + vi[n1] * vif[n2]) + (-gtf * tr - btf * ti) / tm^2 * (-(vi[n1] * vrf[n2] - vr[n1] * vif[n2])) )
        #for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm) ) )

    else
        JuMP.@constraint(pm.model, ptf_fr + ptf_to == 0)
        JuMP.@constraint(pm.model, qtf_fr + qtf_to == 0)
        JuMP.@constraint(pm.model, vr == vrf)
        JuMP.@constraint(pm.model, vi == vif)
    end
end


function constraint_conv_reactor(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    conv = _PM.ref(pm, nw, :convdc, i)
    T2  = pm.data["T2"]
    T3  = pm.data["T3"]
    constraint_conv_reactor(pm, i, nw, conv["rc"], conv["xc"], Bool(conv["reactor"]), T2, T3)
end
function constraint_conv_reactor(pm::_PM.AbstractACRModel, i::Int, n::Int, rc, xc, reactor, T2, T3)
    pconv_ac = _PM.var(pm, n,  :pconv_ac, i)
    qconv_ac = _PM.var(pm, n,  :qconv_ac, i)
    ppr_to = - pconv_ac
    qpr_to = - qconv_ac
    ppr_fr = _PM.var(pm, n,  :pconv_pr_fr, i)
    qpr_fr = _PM.var(pm, n,  :qconv_pr_fr, i)

    vrf = Dict(nw => _PM.var(pm, n, :vrf, i) for nw in _PM.nw_ids(pm))
    vif = Dict(nw => _PM.var(pm, n, :vif, i) for nw in _PM.nw_ids(pm))
    vrc = Dict(nw => _PM.var(pm, n, :vrc, i) for nw in _PM.nw_ids(pm))
    vic = Dict(nw => _PM.var(pm, n, :vic, i) for nw in _PM.nw_ids(pm))

    zc = rc + im*xc
    if reactor
        yc = 1/(zc)
        gc = real(yc)
        bc = imag(yc)                                      
        JuMP.@NLconstraint(pm.model, - pconv_ac ==  gc * (vrc^2 + vic^2) + -gc * (vrc * vrf + vic * vif) + -bc * (vic * vrf - vrc * vif))  
        JuMP.@NLconstraint(pm.model, - qconv_ac == -bc * (vrc^2 + vic^2) +  bc * (vrc * vrf + vic * vif) + -gc * (vic * vrf - vrc * vif)) 
        JuMP.@NLconstraint(pm.model, ppr_fr ==  gc * (vrf^2 + vif^2) + -gc * (vrc * vrf + vic * vif) + -bc * (-(vic * vrf - vrc * vif)))
        JuMP.@NLconstraint(pm.model, qpr_fr == -bc * (vrf^2 + vif^2) +  bc * (vrc * vrf + vic * vif) + -gc * (-(vic * vrf - vrc * vif)))

        #JuMP.@constraint(pm.model, - pconv_ac * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (gc * (vrc[n1] * vrc[n2] + vic[n1] * vic[n2]) + -gc * (vrc[n1] * vrf[n2] + vic[n1] * vif[n2]) + -bc * (vic[n1] * vrf[n2] - vrc[n1] * vif[n2])) for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm)) )
        #JuMP.@constraint(pm.model, - qconv_ac * T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (-bc * (vrc[n1] * vrc[n2] + vic[n1] * vic[n2]) + bc * (vrc[n1] * vrf[n2] + vic[n1] * vif[n2]) + -gc * (vic[n1] * vrf[n2] - vrc[n1] * vif[n2])) for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm)) ) 
        #JuMP.@constraint(pm.model,   ppr_fr  *  T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (gc * (vrf[n1] * vrf[n2] + vif[n1] * vif[n2]) + -gc * (vrc[n1] * vrf[n2] + vic[n1] * vif[n2]) + -bc * (-(vic[n1] * vrf[n2] - vrc[n1] * vif[n2]))) for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm)) )       
        #JuMP.@constraint(pm.model,   qpr_fr  *  T2.get([n-1,n-1]) == sum(T3.get([n1-1,n2-1,n-1]) * (-bc * (vrf[n1] * vrf[n2] + vif[n1] * vif[n2]) +  bc * (vrc[n1] * vrf[n2] + vic[n1] * vif[n2]) + -gc * (-(vic[n1] * vrf[n2] - vrc[n1] * vif[n2]))) for n1 in _PM.nw_ids(pm), n2 in _PM.nw_ids(pm)) )
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

    #JuMP.@NLconstraint(pm.model,   p == cos(phi) * S)
    #JuMP.@NLconstraint(pm.model,   q == sin(phi) * S)
end
# power balance
""
function constraint_power_balance_ac(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    bus_arcs   = _PM.ref(pm, nw, :bus_arcs, i)
    bus_gens   = _PM.ref(pm, nw, :bus_gens, i)
    bus_loads  = _PM.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PM.ref(pm, nw, :bus_shunts, i)
    bus_convs_ac = _PM.ref(pm, nw, :bus_convs_ac, i)

    bus_pd = Dict(k => _PM.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => _PM.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_power_balance_ac(pm, nw, i, bus_arcs, bus_gens, bus_convs_ac, bus_pd, bus_qd, bus_gs, bus_bs)
end
function constraint_power_balance_ac(pm::_PM.AbstractACRModel, n::Int, i::Int, bus_arcs, bus_gens, bus_convs_ac, bus_pd, bus_qd, bus_gs, bus_bs)
    vr = _PM.var(pm, n, :vr, i)
    vi = _PM.var(pm, n, :vi, i)

    p    = _PM.get(_PM.var(pm, n),    :p, Dict()); _PM._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = _PM.get(_PM.var(pm, n),    :q, Dict()); _PM._check_var_keys(q, bus_arcs, "reactive power", "branch")
    
    pg   = _PM.get(_PM.var(pm, n),   :pg, Dict()); _PM._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = _PM.get(_PM.var(pm, n),   :qg, Dict()); _PM._check_var_keys(qg, bus_gens, "reactive power", "generator")

    pconv_grid_ac = _PM.var(pm, n,  :pconv_tf_fr)
    qconv_grid_ac = _PM.var(pm, n,  :qconv_tf_fr)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(pconv_grid_ac[c] for c in bus_convs_ac) == sum(pg[g] for g in bus_gens) - sum(pd for pd in values(bus_pd)) - sum(gs for gs in values(bus_gs))*(vr^2 + vi^2))
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(qconv_grid_ac[c] for c in bus_convs_ac) == sum(qg[g] for g in bus_gens) - sum(qd for qd in values(bus_qd)) + sum(bs for bs in values(bus_bs))*(vr^2 + vi^2))
end

################ ## #### #########











###### not needed now!
function expression_bus_voltage_variable(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    if !haskey(_PM.var(pm, nw), :vm)
        _PM.var(pm, nw)[:vm] = Dict{Int,Any}()
    end
    if !haskey(_PM.var(pm, nw), :va)
        _PM.var(pm, nw)[:va] = Dict{Int,Any}()
    end

    expression_bus_voltage_variable(pm, nw, i)
end

function expression_bus_voltage_variable(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    vr = _PM.var(pm, n, :vr, i)
    vi = _PM.var(pm, n, :vi, i)
    
    v_magnitude = sqrt(vr^2 + vi^2)
    v_angle = arctan(vi/vr)

    var(pm, n, :vm)[i] = v_magnitude 
    var(pm, n, :va)[i] = v_angle
end


#function build_sopf_acr_without_aux(pm::AbstractPowerModel)
#    for (n, network) in _PM.nws(pm) 
#        variable_bus_voltage(pm, nw=n, aux=false)

#        variable_gen_power(pm, nw=n, bounded=false)

#        variable_branch_power(pm, nw=n, bounded=false)
#        variable_branch_current(pm, nw=n, bounded=true, aux=false) 
#    end

#    for i in _PM.ids(pm, :bus,nw=1)
#        constraint_bus_voltage_cc_limit(pm, i, nw=1)
#    end

#    for g in _PM.ids(pm, :gen, nw=1)
#        constraint_gen_power_cc_limit(pm, g, nw=1)
#   end

#    for b in _PM.ids(pm, :branch, nw=1)
#       constraint_branch_series_current_cc_limit(pm, b, nw=1)
#    end

#    for (n, network) in _PM.nws(pm)

#        for i in _PM.ids(pm, :ref_buses, nw=n)
#            constraint_bus_voltage_ref(pm, i, nw=n)
#        end

#        for i in _PM.ids(pm, :bus, nw=n)
#            constraint_power_balance(pm, i, nw=n)
#        end

#        for b in _PM.ids(pm, :branch, nw=n)
#            constraint_gp_power_branch_to(pm, b, nw=n)
#            constraint_gp_power_branch_from(pm, b, nw=n)

#            constraint_branch_voltage(pm, b, nw=n)
#        end
#    end

#    objective_min_expected_generation_cost(pm)
#end



##############################################################################################################################################################
# dcbus voltage
function variable_dcgrid_voltage_magnitude(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, aux::Bool=true, aux_fix::Bool=false, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMACDC.variable_dcgrid_voltage_magnitude(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    if aux
        variable_dcgrid_voltage_magnitude_sqr(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
    else
        if nw == nw_id_default
            variable_dcgrid_voltage_magnitude_expectation(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
            variable_dcgrid_voltage_magnitude_variance(pm, nw=nw, bounded=bounded, report=report, aux_fix=aux_fix; kwargs...)
        end 
    end

    
end
function variable_dcgrid_voltage_magnitude_sqr(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true, aux_fix::Bool=false)
    wdc = _PM.var(pm, nw)[:wdc] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :busdc)], base_name="$(nw)_wdc",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc, i), "Vdc", 1.0)^2
    )
    wdcr = _PM.var(pm, nw)[:wdcr] = JuMP.@variable(pm.model,
    [(i,j) in _PM.ids(pm, nw, :buspairsdc)], base_name="$(nw)_wdcr",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc, i), "Vdc", 1.0)^2
    )

    if bounded
        for (i, busdc) in _PM.ref(pm, nw, :busdc)
            JuMP.set_lower_bound(wdc[i],  busdc["Vdcmin"]^2)
            JuMP.set_upper_bound(wdc[i],  busdc["Vdcmax"]^2)
        end
        for (bp, buspairdc) in _PM.ref(pm, nw, :buspairsdc)
            JuMP.set_lower_bound(wdcr[bp],  0)
            JuMP.set_upper_bound(wdcr[bp],  buspairdc["vm_fr_max"] * buspairdc["vm_to_max"])
        end
    end

    if aux_fix 
        JuMP.fix.(wdc, 1.0; force=true)
        JuMP.fix.(wdcr, 1.0; force=true)
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :busdc, :wdc, _PM.ids(pm, nw, :busdc), wdc)
end
function variable_dcgrid_voltage_magnitude_expectation(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true, aux_fix::Bool=false)
    vdcme = _PM.var(pm, nw)[:vdcme] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :busdc)], base_name="$(nw)_vdcme",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc, i), "vdcme_start", 1.0)
    )

    if bounded
        for (i, busdc) in _PM.ref(pm, nw, :busdc)
            JuMP.set_lower_bound(vdcme[i], 0.0)
        end
    end
    
    if aux_fix 
        JuMP.fix.(vdcme, 1.0; force=true)
    end

    report && _PM.sol_component_value(pm, nw, :busdc, :vdcme, _PM.ids(pm, nw, :busdc), vdcme)
end
function variable_dcgrid_voltage_magnitude_variance(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true, aux_fix::Bool=false)
    vdcmv = _PM.var(pm, nw)[:vdcmv] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :busdc)], base_name="$(nw)_vdcmv",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc, i), "vdcmv_start", 1.0)
    )

    if bounded
        for (i, busdc) in _PM.ref(pm, nw, :busdc)
            JuMP.set_lower_bound(vdcmv[i],  0.0)
        end
    end
    
    if aux_fix 
        JuMP.fix.(vdcmv, 1.0; force=true)
    end

    report && _PM.sol_component_value(pm, nw, :busdc, :vdcmv, _PM.ids(pm, nw, :busdc), vdcmv)
end
# dcbranch flow
"variable: `p_dcgrid[l,i,j]` for `(l,i,j)` in `arcs_dcgrid`"
function variable_active_dcbranch_flow(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true, kwargs...)
    p = _PM.var(pm, nw)[:p_dcgrid] = JuMP.@variable(pm.model,
    [(l,i,j) in _PM.ref(pm, nw, :arcs_dcgrid)], base_name="$(nw)_pdcgrid",
    start = _PM.comp_start_value(_PM.ref(pm, nw, :branchdc, l), "p_start", 1.0)
    )

    if bounded
        for arc in _PM.ref(pm, nw, :arcs_dcgrid)
            l,i,j = arc
            JuMP.set_lower_bound(p[arc], -_PM.ref(pm, nw, :branchdc, l)["rateA"])
            JuMP.set_upper_bound(p[arc],  _PM.ref(pm, nw, :branchdc, l)["rateA"])
        end
    end

    report && _IM.sol_component_value_edge(pm, _PM.pm_it_sym, nw, :branchdc, :pf, :pt, _PM.ref(pm, nw, :arcs_dcgrid_from), _PM.ref(pm, nw, :arcs_dcgrid_to), p)
end





#####################################################################################################################################

################################################################################
#  Copyright 2021, Tom Van Acker, Arpan Koirala                                #
################################################################################
# StochasticPowerModels.jl                                                     #
# An extention package of PowerModels.jl for Stochastic (Optimal) Power Flow   #
# See http://github.com/timmyfaraday/StochasticPowerModels.jl                  #
################################################################################

# input data
""
function parse_dst(dst, pa, pb, deg)
    dst == "Beta"    && return _PCE.Beta01OrthoPoly(deg, pa, pb; Nrec=5*deg)
    dst == "Normal"  && return _PCE.GaussOrthoPoly(deg; Nrec=5*deg)
    dst == "Uniform" && return _PCE.Uniform01OrthoPoly(deg; Nrec=5*deg)
end

"""
    StochasticPowerModels.build_stochastic_data(data::Dict{String,Any}, deg::Int)

Function to build the multi-network data representative of the polynomial chaos
expansion of a single-network data dictionary.
"""
function build_stochastic_data_GM(data::Dict{String,Any}, deg::Int)
    # add maximum current
    for (nb, branch) in data["branch"]
        f_bus = branch["f_bus"]
        branch["cmax"] = branch["rate_a"] / data["bus"]["$f_bus"]["vmin"]
    end

    # build mop
    opq = [parse_dst(ns[2]["dst"], ns[2]["pa"], ns[2]["pb"], deg) for ns in data["sdata"]]
    mop = _PCE.MultiOrthoPoly(opq, deg)

    # build load matrix
    Nd, Npce = length(data["load"]), mop.dim
    pd, qd = zeros(Nd, Npce), zeros(Nd, Npce)
    for nd in 1:Nd 
        # reactive power
        qd[nd,1] = data["load"]["$nd"]["qd"]
        # active power
        nb = data["load"]["$nd"]["load_bus"]
        ni = data["bus"]["$nb"]["dst_id"]
        if ni == 0
            pd[nd,1] = data["load"]["$nd"]["pd"]
        else
            base = data["baseMVA"]
            μ, σ = data["bus"]["$nb"]["μ"] / base, data["bus"]["$nb"]["σ"] / base
            if mop.uni[ni] isa _PCE.GaussOrthoPoly
                pd[nd,[1,ni+1]] = _PCE.convert2affinePCE(μ, σ, mop.uni[ni])
            else
                pd[nd,[1,ni+1]] = _PCE.convert2affinePCE(μ, σ, mop.uni[ni], kind="μσ")
            end
        end
    end

    # replicate the data
    data = _PM.replicate(data, Npce)

    # add the stochastic data 
    data["T2"] = _PCE.Tensor(2,mop)
    data["T3"] = _PCE.Tensor(3,mop)
    data["T4"] = _PCE.Tensor(4,mop)
    data["mop"] = mop
    for nw in 1:Npce, nd in 1:Nd
        data["nw"]["$nw"]["load"]["$nd"]["pd"] = pd[nd,nw]
        data["nw"]["$nw"]["load"]["$nd"]["qd"] = qd[nd,nw]
    end

    return data
end

# output data
"""
    StochasticPowerModels.pce_coeff(result, element::String, id::Int, var::String)

Returns all polynomial chaos coefficients associated with the variable `var` of 
the `id`th element `element`.
"""
pce_coeff(result, element::String, id::Int, var::String) =
    [nw[2][element]["$id"][var] for nw in sort(collect(result["solution"]["nw"]), by=x->parse(Int,x[1]))]

"""
    StochasticPowerModels.sample(sdata, result, element::String, id::Int, var::String; sample_size::Int=1000)

Return an `sample_size` sample of the variable `var` of the `id`th element 
`element`.
"""
sample(result, element::String, id::Int, var::String; sample_size::Int=1000) =
    _PCE.samplePCE(sample_size, pce_coeff(result, element, id, var), result["mop"])

"""
    StochasticPowerModels.density(sdata, result, element::String, id::Int, var::String; sample_size::Int=1000)

Return an kernel density estimate of the variable `var` of the `id`th element 
`element`.
"""
density(result, element::String, id::Int, var::String; sample_size::Int=1000) =
    _KDE.kde(sample(result, element, id, var; sample_size=sample_size))

function print_summary(obj::Dict{String,<:Any}; kwargs...)
    if _IM.ismultinetwork(obj)
        for (n,nw) in obj["nw"]
            println("----------------")
            println("PCE index $n")
            _PM.summary(stdout, nw; kwargs...)
        end
    end
end