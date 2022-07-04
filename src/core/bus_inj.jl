function calc_c1_branch_ptdf_single(am::_PM.AdmittanceMatrix, ref_bus::Int, branch::Dict{String,<:Any})
    branch_ptdf = Dict{Int,Any}()
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    b = imag(inv(branch["br_r"] + im * branch["br_x"]))

    va_fr = _PM.injection_factors_va(am, ref_bus, f_bus)
    va_to = _PM.injection_factors_va(am, ref_bus, t_bus)

    # convert bus injection functions to PTDF style
    bus_injection = Dict(i => -b*(get(va_fr, i, 0.0) - get(va_to, i, 0.0)) for i in union(keys(va_fr), keys(va_to)))

    return bus_injection
end