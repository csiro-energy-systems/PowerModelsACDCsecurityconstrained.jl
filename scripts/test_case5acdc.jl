using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained

using Plots

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

data["branch"]["1"]["rate_a"] = 0.5; data["branch"]["1"]["rate_b"] = 0.5; data["branch"]["1"]["rate_c"] = 0.5
data["branch"]["2"]["rate_a"] = 0.35; data["branch"]["2"]["rate_b"] = 0.35; data["branch"]["2"]["rate_c"] = 0.35
data["branch"]["5"]["rate_a"] = 0.5; data["branch"]["5"]["rate_b"] = 0.5; data["branch"]["5"]["rate_c"] = 0.5

##
PM_acdc.process_additional_data!(data)

setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

#result = PM_acdc.run_acdcpf( data, PM.DCPPowerModel, lp_solver; setting = setting)

result_ACDC_scopf_exact = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf, nlp_solver, setting)

result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, nlp_solver, setting)

result_ACDC_scopf_dcp_exact = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.DCPPowerModel, PM_acdc_sc.run_scopf, lp_solver, setting)

result_ACDC_scopf_dcp_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.DCPPowerModel, PM_acdc_sc.run_scopf_soft, lp_solver, setting)

