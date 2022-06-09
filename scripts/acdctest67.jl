using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC

file = "./data/case67acdc_scopf.m"
data67 = parse_file(file)
#data67["branch"]["7"]["br_status"] = 0
#file = "./data/case5_acdc.m"
#data = parse_file(file)
PowerModelsACDC.process_additional_data!(data67)
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
resultsACDCPF = run_acdcpf(data67, DCPPowerModel, Ipopt.Optimizer; setting = s)

