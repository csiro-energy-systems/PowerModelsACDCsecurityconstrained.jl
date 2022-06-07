module PowerModelsACDCsecurityconstrained

    import PowerModels
    import PowerModelsACDC
    import PowerModelsSecurityConstrained
    import Memento
    import JuMP
    import InfrastructureModels
    import Plots
    

    const _PM = PowerModels
    const _PMSC = PowerModelsSecurityConstrained
    const _PMACDC = PowerModelsACDC
    const _IM = InfrastructureModels
    const _P = Plots
    # Create our module level logger (this will get precompiled)
    const _LOGGER = Memento.getlogger(@__MODULE__)
    const C1_PG_LOSS_TOL = 1e-6                      # Update_GM

    # Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
    # NOTE: If this line is not included then the precompiled `_PM._LOGGER` won't be registered at runtime.
    __init__() = Memento.register(_LOGGER)

    include("core/conting.jl")
    include("core/PF.jl")
    include("core/conting_v.jl")
    include("core/conting_c.jl")
    include("core/CalVio.jl")
    include("core/build_scopf_multinetwork.jl")

end # module
