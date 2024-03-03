using Revise
using PowerModelsACDCsecurityconstrained
using DataFrames
using DataFramesMeta

PM_acdc_sc = PowerModelsACDCsecurityconstrained

file = "./data/snem2000_acdc.m"
data = parse_file(file, validate=true, import_all=false)

gens = PM_acdc_sc.get_df_from_dict(data["gen"], ["index", "gen_bus", "pmax", "startup", "shutdown", "ncost", "cost", "type"])

gens = PM_acdc_sc.assign_participant(gens, "Generator", PM_acdc_sc.gen_filter)
gens = PM_acdc_sc.join_offers(gens, "s1")

gens_energy = PM_acdc_sc.join_energy_prices(gens, "s1")
gens_energy = @orderby gens_energy :index
PM_acdc_sc.gen_convert_to_pwl!(gens_energy)
PM_acdc_sc.export_gen_cost(gens_energy, "s1")

gens_fcas = PM_acdc_sc.join_fcas_prices(gens, "s1")
gens_fcas = @orderby gens_fcas :index
PM_acdc_sc.gen_convert_to_pwl!(gens_fcas)

loads = PM_acdc_sc.get_df_from_dict(data["load"], ["index", "pd"],  ["pd" => "pmax"])
loads = PM_acdc_sc.assign_participant(loads, "Load", PM_acdc_sc.load_filter)
loads = PM_acdc_sc.join_offers(loads, "s1")

loads_energy = PM_acdc_sc.join_energy_prices(loads, "s1")
loads_energy = @orderby loads_energy :index
PM_acdc_sc.load_convert_to_pwl!(loads_energy)
PM_acdc_sc.export_load_data(loads_energy, "s1")

load_fcas = PM_acdc_sc.join_fcas_prices(loads, "s1")
load_fcas = @orderby load_fcas :index
PM_acdc_sc.load_convert_to_pwl!(load_fcas)

PM_acdc_sc.export_fcas_data("s1", gens_fcas, load_fcas)




