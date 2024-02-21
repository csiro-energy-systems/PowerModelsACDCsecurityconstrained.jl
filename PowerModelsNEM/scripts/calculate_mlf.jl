using Revise
using Ipopt
using PowerModelsACDC
using PowerModels
using PowerModelsNEM

file = "./data/snem2000_acdc.m"
data = PowerModelsNEM.parse_file(file, validate=true, import_all=false)

scenario = "s1"
PowerModelsACDC.process_additional_data!(data)
PowerModelsNEM.process_scenario_data!(data, scenario)

PowerModelsNEM.mlf_initialise!(data)

rrn = ["130", "1480", "703", "1643", "1123"]

bus_count = length(data["bus"])
result = Array{Tuple{Float64,Float64}}(undef, bus_count)
area_data = PowerModelsNEM.set_reference_bus(data, rrn)

count = 1
for area in 1:5
    buses = filter(x -> x[2]["area"] == area, area_data["bus"])
    fx = PowerModelsNEM.inject_load(0.0, rrn[area], rrn[area], area_data)

    for (i, bus) in sort(collect(buses), by=x -> parse(Int, x[1]))
        idx = parse(Int, i)
        p, mlf = PowerModelsNEM.finite_difference(fx, x -> PowerModelsNEM.inject_load(x, i, rrn[area], area_data), 0.0)
        result[idx] = (p, mlf)

        @show "$(count) of $(bus_count)", mlf
        count += 1
    end
end

# Calculate MLF for single node

# area_data = set_reference_bus(data, rrn)
# fx = run_pf(0.0, rrn[1], rrn[1], area_data)
# p, mlf = finite_difference(fx, x -> run_pf(x, "3", rrn[1], area_data), 0.0)

PowerModelsNEM.export_mlfs(result, scenario)

