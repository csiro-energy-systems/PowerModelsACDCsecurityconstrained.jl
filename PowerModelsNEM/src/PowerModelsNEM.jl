module PowerModelsNEM

using Ipopt
using JuMP
using JSON
using PlotlyJS
using CSV
using Dates
using DataFrames
using DataFramesMeta
import InfrastructureModels
import PowerModels
import PowerModelsACDC
import Memento

const _IM = InfrastructureModels
const _PM = PowerModels
const _PMACDC = PowerModelsACDC

# Create our module level logger (this will get precompiled)
const _LOGGER = Memento.getlogger(@__MODULE__)
const C1_PG_LOSS_TOL = 1e-6                      # Update_GM

# Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
# NOTE: If this line is not included then the precompiled `_PM._LOGGER` won't be registered at runtime.
__init__() = Memento.register(_LOGGER)

include("./core/types.jl")
include("./core/solution.jl")
include("./core/variables.jl")
include("./core/objective.jl")
include("./core/constraint.jl")
include("./core/data.jl")
include("./core/utils.jl")
include("./core/main.jl")

include("./data/nem.jl")
include("./data/mlf.jl")

include("./vis/cost.jl")
include("./vis/losses.jl")



end # module