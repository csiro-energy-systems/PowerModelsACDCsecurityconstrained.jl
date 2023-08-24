using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained
using Memento

nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6)    # "print_level"=>0,
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)

const _LOGGER = Memento.getlogger(@__MODULE__)
const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained

##

# c1_ini_file = "./data/c1/inputfiles.ini"
# c1_scenarios = "scenario_04"  #, "scenario_02"]
# c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
# data = build_c1_pm_model(c1_cases)

##

file = "./data/case5_acdc_scopf.m"
data = parse_file(file)

idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([2, 1])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    data["gen"]["$i"]["model"] = 2
    data["gen"]["$i"]["ncost"] = 2
    data["gen"]["1"]["cost"] = [10, 25, 25, 45]
    data["gen"]["2"]["cost"] = [5, 20, 20, 40]
end

data["gen"]["1"]["alpha"] = 15.92 
data["gen"]["2"]["alpha"] = 11.09

for i=1:length(data["branch"])
    if data["branch"]["$i"]["tap"] !== 1 
        data["branch"]["$i"]["tm_min"] = 0.9
        data["branch"]["$i"]["tm_max"] = 1.1
    end
    if data["branch"]["$i"]["tap"] == 1 
        data["branch"]["$i"]["tm_min"] = 1
        data["branch"]["$i"]["tm_max"] = 1
    end
    if data["branch"]["$i"]["shift"] !== 0
        data["branch"]["$i"]["ta_min"] = -15
        data["branch"]["$i"]["ta_max"] = 15
    end
    if data["branch"]["$i"]["shift"] == 0
        data["branch"]["$i"]["ta_min"] = 0
        data["branch"]["$i"]["ta_max"] = 0
    end
end



#data["branch"]["1"]["rate_a"] = 0.5; data["branch"]["1"]["rate_b"] = 0.5; data["branch"]["1"]["rate_c"] = 0.5
#data["branch"]["2"]["rate_a"] = 0.5; data["branch"]["2"]["rate_b"] = 0.5; data["branch"]["2"]["rate_c"] = 0.5
#data["branch"]["5"]["rate_a"] = 0.5; data["branch"]["5"]["rate_b"] = 0.5; data["branch"]["5"]["rate_c"] = 0.5

#data["branchdc"]["1"]["rateA"] = 0.5; data["branchdc"]["1"]["rateA"] = 0.5; data["branchdc"]["1"]["rateA"] = 0.5
# data["branchdc"]["2"]["rateA"] = 35; data["branchdc"]["2"]["rateB"] = 35; data["branchdc"]["2"]["rateC"] = 35
data["branchdc"]["3"]["rateA"] = 50; data["branchdc"]["3"]["rateB"] = 50; data["branchdc"]["3"]["rateC"] = 50

# data["load"]["1"]["pd"] = data["load"]["1"]["pd"] * 2
# data["load"]["1"]["qd"] = data["load"]["1"]["qd"] * 2
# data["load"]["2"]["pd"] = data["load"]["2"]["pd"] * 2
# data["load"]["2"]["qd"] = data["load"]["2"]["qd"] * 2
# data["load"]["3"]["pd"] = data["load"]["3"]["pd"] * 2
# data["load"]["3"]["qd"] = data["load"]["3"]["qd"] * 2

data["dcline"] = Dict{String, Any}() 

##
PowerModelsACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)


#data["branchdc"]["3"]["status"] = 0
#data["branch"]["1"]["br_status"] = 0

#results = PowerModelsACDC.run_acdcopf(data, PowerModels.ACPPowerModel, nlp_solver)
#results = PowerModelsSecurityConstrained.run_c1_scopf_ptdf_cuts!(data, PowerModels.ACPPowerModel, nlp_solver)


results = PM_acdc_sc.run_acdc_scopf_ptdf_dcdf_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_acdc_scopf_cuts, nlp_solver)

# verification
#PowerModels.update_data!(data, results["solution"])
#data["gen_flow_cuts"] = []
#data["branch_flow_cuts"] = []
#data["branchdc_flow_cuts"] = []
#itr = 1
#cuts_obs = 1

#while cuts_obs > 0
    
#    b_cuts = PowerModelsACDCsecurityconstrained.check_c1_contingencies_branch_power_GM(data, nlp_solver, total_cut_limit=itr, gen_flow_cuts=[], branch_flow_cuts=[])
#    cuts_obs = length(b_cuts.gen_cuts) + length(b_cuts.branch_cuts) + length(b_cuts.branchdc_cuts)
#    append!(data["gen_flow_cuts"], b_cuts.gen_cuts)
#    append!(data["branch_flow_cuts"], b_cuts.branch_cuts)
#    append!(data["branchdc_flow_cuts"], b_cuts.branchdc_cuts)
#    PowerModelsSecurityConstrained.info(_LOGGER, "active cuts: gen $(length(data["gen_flow_cuts"])), branch $(length(data["branch_flow_cuts"])), branchdc $(length(data["branchdc_flow_cuts"]))")
#    itr += 1
#end
            
# powerplot(data; width=800, height=800, node_size=100, edge_size=3)