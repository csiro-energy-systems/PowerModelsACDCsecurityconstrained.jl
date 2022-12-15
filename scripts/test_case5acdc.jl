using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained
#using Plots

const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6)  
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


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
data["area_gens"][1] = Set([1])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    data["gen"]["$i"]["model"] = 2
    data["gen"]["$i"]["pg"] = 0
    data["gen"]["$i"]["qg"] = 0
    data["gen"]["$i"]["ncost"] = 2
    data["gen"]["1"]["cost"] = [10, 25, 25, 45]
    data["gen"]["2"]["cost"] = [5, 20, 20, 40]
    data["gen"]["$i"]["alpha"] = 1
end

#data["branch"]["1"]["rate_a"] = 0.5; data["branch"]["1"]["rate_b"] = 0.5; data["branch"]["1"]["rate_c"] = 0.5
#data["branch"]["2"]["rate_a"] = 0.5; data["branch"]["2"]["rate_b"] = 0.5; data["branch"]["2"]["rate_c"] = 0.5
#data["branch"]["5"]["rate_a"] = 0.5; data["branch"]["5"]["rate_b"] = 0.5; data["branch"]["5"]["rate_c"] = 0.5

#data["branchdc"]["1"]["rateA"] = 0.5; data["branchdc"]["1"]["rateB"] = 0.5; data["branchdc"]["1"]["rateC"] = 0.5
data["branchdc"]["2"]["rateA"] = 35; data["branchdc"]["2"]["rateB"] =35; data["branchdc"]["2"]["rateC"] = 35
#data["branchdc"]["3"]["rateA"] = 80; data["branchdc"]["3"]["rateB"] = 80; data["branchdc"]["3"]["rateC"] = 80

data["load"]["1"]["pd"] = data["load"]["1"]["pd"] * 2
data["load"]["1"]["qd"] = data["load"]["1"]["qd"] * 2
data["load"]["2"]["pd"] = data["load"]["2"]["pd"] * 2
data["load"]["2"]["qd"] = data["load"]["2"]["qd"] * 2
data["load"]["3"]["pd"] = data["load"]["3"]["pd"] * 2
data["load"]["3"]["qd"] = data["load"]["3"]["qd"] * 2

##
PM_acdc.process_additional_data!(data)

setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

#result = PM_acdc.run_acdcpf( data, PM.DCPPowerModel, lp_solver; setting = setting)

result_ACDC_scopf_exact = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf, nlp_solver, setting)

#result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, nlp_solver, setting)

#result_ACDC_scopf_dcp_exact = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.DCPPowerModel, PM_acdc_sc.run_scopf, lp_solver, setting)

#result_ACDC_scopf_dcp_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.DCPPowerModel, PM_acdc_sc.run_scopf_soft, lp_solver, setting)

# updating reference point 
for i = 1:length(data["gen"])
    data["gen"]["$i"]["pgref"] = result_ACDC_scopf_exact["base"]["solution"]["nw"]["0"]["gen"]["$i"]["pg"]
end 
# embedding unsecure contingencies
if haskey(result_ACDC_scopf_exact, "gen_contingencies_unsecure") 
    (data["gen"][id][2]["status"] = 0 for id in result_ACDC_scopf_exact["gen_contingencies_unsecure"])
end
if haskey(result_ACDC_scopf_exact, "branch_contingencies_unsecure")
    (data["branch"][id][2]["status"] = 0 for id in result_ACDC_scopf_exact["branch_contingencies_unsecure"])
end
if haskey(result_ACDC_scopf_exact, "branchdc_contingencies_unsecure") 
    (data["branchdc"][id][2]["status"] = 0 for id in result_ACDC_scopf_exact["branchdc_contingencies_unsecure"])
end
# Re-dispatch
result_ACDC_scopf_re_dispatch =  PM_acdc_sc.run_acdcreopf(data, PM.ACPPowerModel, nlp_solver)