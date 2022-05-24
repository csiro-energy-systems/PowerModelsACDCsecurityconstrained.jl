using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC

file = "./data/case67acdc_scopf.m"
data = parse_file(file)
#file = "./data/case5_acdc.m"
#data = parse_file(file)
PowerModelsACDC.process_additional_data!(data)
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
resultsACDCPF = run_acdcopf(data, DCPPowerModel, Ipopt.Optimizer; setting = s)