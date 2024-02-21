using Revise
using PowerModelsNEM
using DataFrames
using DataFramesMeta

file = "./data/snem2000_acdc.m"
data = parse_file(file, validate=true, import_all=false)

gens = PowerModelsNEM.get_df_from_dict(data["gen"], ["index", "gen_bus", "pmax", "startup", "shutdown", "ncost", "cost", "type"])

gens = PowerModelsNEM.assign_participant(gens, "Generator", PowerModelsNEM.gen_filter)
gens = PowerModelsNEM.join_offers(gens, "s1")

gens_energy = PowerModelsNEM.join_energy_prices(gens, "s1")
gens_energy = @orderby gens_energy :index
PowerModelsNEM.gen_convert_to_pwl!(gens_energy)
PowerModelsNEM.export_gen_cost(gens_energy, "s1")

gens_fcas = PowerModelsNEM.join_fcas_prices(gens, "s1")
gens_fcas = @orderby gens_fcas :index
PowerModelsNEM.gen_convert_to_pwl!(gens_fcas)

loads = PowerModelsNEM.get_df_from_dict(data["load"], ["index", "pd"],  ["pd" => "pmax"])
loads = PowerModelsNEM.assign_participant(loads, "Load", PowerModelsNEM.load_filter)
loads = PowerModelsNEM.join_offers(loads, "s1")

loads_energy = PowerModelsNEM.join_energy_prices(loads, "s1")
loads_energy = @orderby loads_energy :index
PowerModelsNEM.load_convert_to_pwl!(loads_energy)
PowerModelsNEM.export_load_data(loads_energy, "s1")

load_fcas = PowerModelsNEM.join_fcas_prices(loads, "s1")
load_fcas = @orderby load_fcas :index
PowerModelsNEM.load_convert_to_pwl!(load_fcas)

PowerModelsNEM.export_fcas_data("s1", gens_fcas, load_fcas)




