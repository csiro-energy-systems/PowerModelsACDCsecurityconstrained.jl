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

nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6)
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)

const _LOGGER = Memento.getlogger(@__MODULE__)

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
PowerModelsACDC.process_additional_data!(data)
data["dcline"] = Dict{String, Any}() 
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

results = PowerModelsACDCsecurityconstrained.run_c1_scopf_ptdf_cuts_GM(data, PowerModels.ACPPowerModel, nlp_solver)

# verification
PowerModels.update_data!(data, results["solution"])
data["gen_flow_cuts"] = []
data["branch_flow_cuts"] = []
data["branchdc_flow_cuts"] = []
itr = 1
cuts_obs = 1

while cuts_obs > 0
    
    b_cuts = PowerModelsACDCsecurityconstrained.check_c1_contingencies_branch_power_GM(data, nlp_solver, total_cut_limit=itr, gen_flow_cuts=[], branch_flow_cuts=[])
    cuts_obs = length(b_cuts.gen_cuts) + length(b_cuts.branch_cuts) + length(b_cuts.branchdc_cuts)
    append!(data["gen_flow_cuts"], b_cuts.gen_cuts)
    append!(data["branch_flow_cuts"], b_cuts.branch_cuts)
    append!(data["branchdc_flow_cuts"], b_cuts.branchdc_cuts)
    PowerModelsSecurityConstrained.info(_LOGGER, "active cuts: gen $(length(data["gen_flow_cuts"])), branch $(length(data["branch_flow_cuts"])), branchdc $(length(data["branchdc_flow_cuts"]))")
    itr += 1
end
            