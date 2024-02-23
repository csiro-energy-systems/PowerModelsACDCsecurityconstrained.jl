using Revise
using Ipopt
using PowerModelsACDC
using PowerModels
using PowerModelsACDCsecurityconstrained
using JLD

const PM_acdc_sc = PowerModelsACDCsecurityconstrained

file = "./data/snem2000_acdc.m"
data = parse_file(file, validate=true, import_all=false)

PowerModelsACDC.process_additional_data!(data)
PM_acdc_sc.process_scenario_data!(data, "s1")

setting = Dict("output" => Dict("branch_flows" => true, "duals" => true), "conv_losses_mp" => true)
nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

dc_data = deepcopy(data)
dc_result = PM_acdc_sc.run_acdcopf(dc_data, DCPPowerModel, nlp_solver, setting=setting)
update_data!(dc_data, dc_result["solution"])

ac_data = deepcopy(data)
ac_result = PM_acdc_sc.run_acdcopf(ac_data, ACPPowerModel, nlp_solver, setting=setting)
update_data!(ac_data, ac_result["solution"])

rrns = Dict("NSW"=>"130", "VIC"=>"1480", "QLD"=>"1274", "SA" => "1643", "TAS" => "1123")

PM_acdc_sc.plot_fcas(dc_data)
PM_acdc_sc.plot_cost(dc_data)
PM_acdc_sc.plot_losses(dc_data, ac_data)
PM_acdc_sc.plot_prices(dc_data, ac_data)
PM_acdc_sc.plot_voltages(ac_data)
PM_acdc_sc.plot_line_capacities(dc_data, ac_data)
PM_acdc_sc.plot_regional_prices(dc_data, ac_data, rrns)

prices = Dict()
for (region, bus) in rrns
    prices[region] = ac_data["bus"]["$(bus)"]["lam_kcl_r"]
end
prices

ac_data["gen"]["1"]["cost"]


dc_data["mlf"]





