using Revise
using JuMP
using Ipopt
using InfrastructureModels
using PowerModelsACDC
using PowerModels
using PowerPlots
using PowerModelsNEM
using CSV
using DataFrames
using DataFramesMeta
using Memento

const _JuMP = JuMP
const _IM = InfrastructureModels
const _PM = PowerModels
const _PMACDC = PowerModelsACDC
const _PMNEM = PowerModelsNEM
const _LOGGER = Memento.getlogger(@__MODULE__)

nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

file = "./data/snem2000_acdc.m"
#file = "./data/snem2000_acdc_cost.m"


data = _PMNEM.parse_file(file, validate=true, import_all=false)
_PMACDC.process_additional_data!(data)
_PMNEM.process_scenario_data!(data, "s1")

setting = Dict("output" => Dict("branch_flows" => true, "duals" => true), "conv_losses_mp" => true)
result = _PMNEM.run_acdcopf_cp(data, _PM.ACPPowerModel, nlp_solver, setting=setting)

pm = _PM.instantiate_model(data, _PM.DCPPowerModel, _PMNEM.build_acdcopf, ref_extensions=[_PMACDC.add_ref_dcgrid!], setting=setting)

_PM.print_summary(result["solution"])
powerplot(data)

@show data["gen"]["64"]
data["gen"]["130"]["fcas_cost"]

result["solution"]["gen"]["245"]
result["solution"]["bus"]["642"]
data["gen"]["178"]["fcas"]

_PMNEM.plot_fcas(data, result["solution"])
_PMNEM.plot_cost(data, result["solution"])


pm = _PM.instantiate_model(data, _PM.ACPPowerModel, _PMNEM.build_acdcopf_cp, ref_extensions=[_PMACDC.add_ref_dcgrid!], setting=setting)


open("./data/nem/s1/model.txt", "w+") do io
    print(io, pm.model)
end

JuMP.objective_function(pm.model)
JuMP.value(_PM.var(pm, 0, :gen_RReg, 2))

# find count of renewable generators

sort([(i, gen["tech"], gen["type"]) for (i, gen) in data["gen"]], by=x -> parse(Int, x[1]))


_PMNEM.get_dispatchable_participants(data["gen"])
_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["RAISEREG"])

all(>(0), data["gen"]["2"]["fcas_cost"][1]["cost"][1:2:end])
any(>(0), data["gen"]["2"]["fcas_cost"][1]["cost"][1:2:end])

data["bus"]["1"]["bus_type"]
[bus for (i, bus) in data["bus"] if bus["bus_type"] == 3][1]

data["gen"]["1"]

const mlf_columns = [
    ("bus", Int),
    ("mlf", Float64)
]

file = "./data/nem/s1/mlf.m"
file_exists = isfile(file)

if file_exists
    mlf_data = _IM.parse_matlab_file(file)

    if haskey(mlf_data, "mpc.bus_mlf")
        mlfs = []
        for (i, row) in enumerate(mlf_data["mpc.bus_mlf"])
            row_data = _IM.row_to_typed_dict(row, mlf_columns)
            row_data["index"] = i
            row_data["source_id"] = ["bus_mlf", i]
            push!(mlfs, row_data)
        end
        data["mlf"] = mlfs
    end

    for (i, bus) in data["bus"]
        idx = parse(Int, i)

    end

    mlf_line(bus, mlf, gen, load) = """
    $(bus)\t\
    $(mlf)\t\
    $(gen)\t\
    $(load)\t\
    """

    lines = map(x -> mlf_line(x...), mlfs)

    template = """
    %%-----  MLF Data  -----%%
    %column_names% 	bus	mlf gen load
    mpc.bus_mlf = [
    $(join(lines, "\n"))
    ];
    """

    open("./data/nem/s1/mlf.m", "w+") do io
        print(io, template)
    end


end

energy = length(keys(_PMNEM.get_dispatchable_participants(data["gen"])))
energy += length(_PMNEM.get_dispatchable_participants(data["load"]))

fcas = length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["RAISEREG"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["LOWERREG"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["RAISE1SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["LOWER1SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["RAISE6SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["LOWER6SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["RAISE60SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["LOWER60SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["RAISE5MIN"]))
fcas += length(_PMNEM.get_fcas_participants(data["gen"], _PMNEM.fcas_services["LOWER5MIN"]))

fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["RAISEREG"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["LOWERREG"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["RAISE1SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["LOWER1SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["RAISE6SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["LOWER6SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["RAISE60SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["LOWER60SEC"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["RAISE5MIN"]))
fcas += length(_PMNEM.get_fcas_participants(data["load"], _PMNEM.fcas_services["LOWER5MIN"]))

energy
fcas


data["branch"]["1"]
data["load"]["1"]
[value for value in data["gen"]["1"]["cost"]:10]

data[mlf]

mlf = filter(x -> x["index"] == 2, data["mlf"])
prices = [value for value in data["gen"]["2"]["cost"][2:2:end]]
quantity = [value for value in data["gen"]["2"]["cost"][1:2:end]]
prices = prices ./ mlf[1]["mlf"]

newprice = []
for i in 1:10
    push!(newprice, quantity[i], prices[i])
end

quantity
newprice

# Find prices at RRN

prices = []
for i in ["130", "1480", "703", "1643", "1123"]
    push!(prices,(i, data["bus"]["$(i)"]["lam_kcl_r"]))
end
prices

# Get largest load in each region to determin RRN
loads = []
for i in 1:5
    area_loads = filter(x -> data["bus"]["$(x[2]["load_bus"])"]["area"] == i, data["load"])
    load_power = [(i, load["load_bus"], load["pd"]) for (i, load) in area_loads]
    max_power, index = findmax(last, load_power)
    push!(loads, (i, load_power[index]))
end
loads

# interconnector branches

interconnectors = filter(x->data["bus"]["$(x[2]["f_bus"])"]["area"] != data["bus"]["$(x[2]["t_bus"])"]["area"], data["branch"])
[(i, data["bus"]["$(branch["f_bus"])"]["area"], data["bus"]["$(branch["f_bus"])"]["lam_kcl_r"], data["bus"]["$(branch["t_bus"])"]["area"], data["bus"]["$(branch["t_bus"])"]["lam_kcl_r"])  for (i, branch) in interconnectors]
