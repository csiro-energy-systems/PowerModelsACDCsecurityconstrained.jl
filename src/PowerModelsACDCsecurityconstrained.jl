module PowerModelsACDCsecurityconstrained

    using Ipopt    
    import JuMP
    import PowerModels
    # import StochasticPowerModels
    import PowerModelsACDC
    import PowerModelsSecurityConstrained
    import Memento
    import LinearAlgebra
    import InfrastructureModels
    import Distributed
    # import PolyChaos
    # import KernelDensity
    using CSV
    using PlotlyJS
    using Dates
    using DataFrames
    using DataFramesMeta
    

    const _PM = PowerModels
    const _PMSC = PowerModelsSecurityConstrained
    const _PMACDC = PowerModelsACDC
    const _IM = InfrastructureModels
    # const _SPM = StochasticPowerModels
    const _LA = LinearAlgebra
    # const _PCE = PolyChaos
    # const _KDE = KernelDensity
    const _DI = Distributed
    
    # Create our module level logger (this will get precompiled)
    const _LOGGER = Memento.getlogger(@__MODULE__)
    const C1_PG_LOSS_TOL = 1e-6                      # Update_GM

    # Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
    # NOTE: If this line is not included then the precompiled `_PM._LOGGER` won't be registered at runtime.
    __init__() = Memento.register(_LOGGER)

    include("./core/types.jl")
    include("core/variables.jl")


    include("core/ACDC_scopf_iterative.jl")
    
    include("core/ACDC_scopf.jl")
    include("core/ACDC_scopf_soft.jl")
    include("core/ACDC_scopf_soft_minlp.jl")

  
    include("core/contingency_filter_ndc.jl")
    include("core/conting_c.jl")
    include("core/CalVio.jl")

    include("core/constraint_template.jl")
    include("core/constraint.jl")

    include("core/build_ACDC_scopf_multinetwork.jl")
    
    include("core/ACDC_pf.jl")                  # TODO Is needed ?
    include("core/contingency_filter_cuts.jl")
    include("core/ACDC_scopf_cuts.jl")
    include("core/ACDC_scopf_cuts_iterative.jl")
    #include("core/ACDC_R_pf.jl")
    #include("core/ACDC_R_cv.jl")
    
    # include("core/ACDC_opf_stochastic.jl")   ## Stochastic
    # include("core/variable_stochastic.jl")

    include("core/acdcopfACR.jl")       #ACR formulation

    include("core/ACDC_re_dispatch.jl")       # Re-dispatch

    include("core/ACDC_re_dispatch_ots.jl")       # Re-dispatch + ots

    include("core/ACDC_re_dispatch_ots_oltc_pst.jl")    # Re-dispatch + ots + oltc + pst

    include("core/checkscopf.jl") # Temporary to check & verify 

    include("core/objective.jl")

    include("core/re_dispatch_algo.jl") 
    include("core/contingency_filter_SI.jl")

    include("core/expression_template.jl")

    include("core/ndc_filter.jl")
   
    include("utils/split_gen.jl")

    include("./core/solution.jl")
    include("./core/data.jl")
    include("./core/utils.jl")
    include("./core/main.jl")

    include("./data/nem.jl")
    include("./data/mlf.jl")

    include("./vis/cost.jl")
    include("./vis/plots.jl")
end # module
