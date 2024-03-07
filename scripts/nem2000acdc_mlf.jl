

using Revise
using Ipopt
using PowerModels
using PowerModelsACDC
using PowerModelsACDCsecurityconstrained

const _PM = PowerModels
const _PMACDC = PowerModelsACDC
const _PMACDCsc = PowerModelsACDCsecurityconstrained

nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

file = "./test/data/matpower/snem2000_acdc.m"
data = parse_file(file, validate=true, import_all=false)
scenario = "s1"
_PMACDC.process_additional_data!(data)
_PMACDCsc.process_scenario_data!(data, scenario)
setting = Dict("output" => Dict("branch_flows" => true, "duals" => true), "conv_losses_mp" => true)

rrn = ["130", "1480", "1274", "1643", "1123"]

bus_count = length(data["bus"])
result = Array{Tuple{Float64,Float64}}(undef, bus_count)

count = 1
for region in 1:5
    area_data = _PMACDCsc.set_reference_bus(data, rrn[region])

    output = _PMACDC.run_acdcopf(area_data, PowerModels.ACPPowerModel, nlp_solver, setting=setting)
    _PM.update_data!(area_data, output["solution"])
    _PMACDCsc.update_data_converter_setpoints!(area_data, output["solution"])

    buses = filter(x -> x[2]["area"] == region, area_data["bus"])
    fx = _PMACDCsc.inject_load(0.0, rrn[region], rrn[region], area_data, nlp_solver, setting)

    for (i, bus) in sort(collect(buses), by=x -> parse(Int, x[1]))
        idx = parse(Int, i)
        p, mlf = _PMACDCsc.finite_difference(fx, x -> _PMACDCsc.inject_load(x, i, rrn[region], area_data, nlp_solver, setting), 0.0)
        result[idx] = (p, mlf)

        @show "$(count) of $(bus_count)", mlf
        count += 1
    end
end


# Calculate MLF for single node

# area_data = PM_acdc_sc.set_reference_bus(data, rrn[1])
# length(data["gen"])
# length([bus for (i, bus) in data["bus"] if bus["bus_type"] == 3])
# length(area_data["gen"])
# length([bus for (i, bus) in area_data["bus"] if bus["bus_type"] == 3])
# PM_acdc_sc.mlf_initialise!(area_data)
# fx = PM_acdc_sc.inject_load(0.0, rrn[1], rrn[1], area_data)
# p, mlf = PM_acdc_sc.finite_difference(fx, x -> PM_acdc_sc.inject_load(x, "3", rrn[1], area_data), 0.0)
# PM_acdc_sc.get_slack_generation(rrn[1], area_data)

_PMACDCsc.export_mlfs(result, scenario)