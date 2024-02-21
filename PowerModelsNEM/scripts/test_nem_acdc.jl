using Revise
using Ipopt
using PowerModelsACDC
using PowerModels
using PowerModelsNEM
using JLD

file = "./data/snem2000_acdc.m"
data = parse_file(file, validate=true, import_all=false)

PowerModelsACDC.process_additional_data!(data)
PowerModelsNEM.process_scenario_data!(data, "s1")

setting = Dict("output" => Dict("branch_flows" => true, "duals" => true), "conv_losses_mp" => true)
nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

model_type = DCPPowerModel
result = PowerModelsNEM.run_acdcopf(data, model_type, nlp_solver, setting=setting)

update_data!(data, result["solution"])

PowerModelsNEM.plot_fcas(data)
PowerModelsNEM.plot_cost(data)
PowerModelsNEM.plot_losses(model_type, data)
PowerModelsNEM.plot_prices(data)
PowerModelsNEM.plot_voltages(data)
PowerModelsNEM.plot_line_capacities(data)

prices = []
for i in ["130", "1480", "703", "1643", "1123"]
    push!(prices,(i, data["bus"]["$(i)"]["lam_kcl_r"]))
end
prices





