

using Ipopt
using PowerModels
using PowerModelsACDC
using PowerModelsACDCsecurityconstrained
using Revise
using JLD
using CSV
using PlotlyJS
using Dates
using DataFrames
using DataFramesMeta

const _PMACDC = PowerModelsACDC
const _PMACDCsc = PowerModelsACDCsecurityconstrained

file = "./test/data/matpower/snem2000_acdc.m"
data = parse_file(file, validate=true, import_all=false)

_PMACDC.process_additional_data!(data)
_PMACDCsc.process_scenario_data!(data, "s3")

setting = Dict("output" => Dict("branch_flows" => true, "duals" => true), "conv_losses_mp" => true)
nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

dc_data = deepcopy(data)
dc_result =_PMACDCsc.run_acdcopfcas(dc_data, DCPPowerModel, nlp_solver, setting=setting)
update_data!(dc_data, dc_result["solution"])

ac_data = deepcopy(data)
ac_result =_PMACDCsc.run_acdcopfcas(ac_data, ACPPowerModel, nlp_solver, setting=setting)
update_data!(ac_data, ac_result["solution"])

rrns = Dict("NSW"=>"130", "VIC"=>"1480", "QLD"=>"1274", "SA" => "1643", "TAS" => "1123")

# enable using PlotlyJS in module

_PMACDCsc.plot_fcas(dc_data)
_PMACDCsc.plot_cost(dc_data)
_PMACDCsc.plot_losses(dc_data, ac_data)
_PMACDCsc.plot_prices(dc_data, ac_data)
_PMACDCsc.plot_voltages(ac_data)
_PMACDCsc.plot_line_capacities(dc_data, ac_data)
_PMACDCsc.plot_regional_prices(dc_data, ac_data, rrns)

prices = Dict()
for (region, bus) in rrns
    prices[region] = ac_data["bus"]["$(bus)"]["lam_kcl_r"]
end
prices

ac_data["gen"]["1"]["cost"]


dc_data["mlf"]





