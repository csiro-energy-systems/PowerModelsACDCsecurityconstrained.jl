module PowerModelsACDCsecurityconstrained

    import PowerModels
    import PowerModelsACDC
    import PowerModelsSecurityConstrained
    import Memento
    import JuMP
    import InfrastructureModels
    
    

    const _PM = PowerModels
    const _PMSC = PowerModelsSecurityConstrained
    const _PMACDC = PowerModelsACDC
    const _IM = InfrastructureModels
    
    # Create our module level logger (this will get precompiled)
    const _LOGGER = Memento.getlogger(@__MODULE__)
    const C1_PG_LOSS_TOL = 1e-6                      # Update_GM

    # Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
    # NOTE: If this line is not included then the precompiled `_PM._LOGGER` won't be registered at runtime.
    __init__() = Memento.register(_LOGGER)

    include("core/variables.jl")


    include("core/ACDC_scopf_iterative.jl")
    
    include("core/ACDC_scopf.jl")
    include("core/ACDC_scopf_soft.jl")

  
    include("core/contingency_filters.jl")
    include("core/conting_c.jl")
    include("core/CalVio.jl")

    include("core/constraint_template.jl")
    include("core/constraint.jl")

    include("core/build_ACDC_scopf_multinetwork.jl")
    
    # include("core/ACDC_pf.jl")
    # include("core/conting_soft_v.jl")
    # include("core/PF_convex_cuts.jl")
    

end # module
