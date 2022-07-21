using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6)  
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


##

file = "./data/case67acdc_scopf.m"
data = parse_file(file)

idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([4, 3, 2, 1])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    data["gen"]["$i"]["model"] = 1
    data["gen"]["$i"]["pg"] = 0
    data["gen"]["$i"]["qg"] = 0
    #data["gen"]["$i"]["pmin"] = 0
    #data["gen"]["$i"]["qmin"] = -data["gen"]["$i"]["qmax"]
    data["gen"]["$i"]["ncost"] = 10
    data["gen"]["$i"]["cost"] = [0.114610934721, 148.906997825, 0.224657803731, 203.163028589, 0.33470467274, 257.869865285, 0.44475154175, 313.027507911, 0.5547984107589999, 368.635956469, 0.664845279769, 424.695210957, 0.774892148778, 481.205271377, 0.884939017788, 538.166137728, 0.9949858867970001, 595.57781001, 1.10503275581, 653.440288223]
    data["gen"]["$i"]["alpha"] = 1
end


###################################################
PowerModelsACDC.process_additional_data!(data)

setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)        #Update_GM

result_ACDCscopf2 = PowerModelsACDCsecurityconstrained.run_c1_scopf_contigency_cuts_GM(data, PowerModels.DCPPowerModel, lp_solver, setting)





############################################# Soft test ################################################
#PowerModelsACDC.process_additional_data!(data)
#result = PowerModelsACDC.run_acdcopf(data, ACPPowerModel, nlp_solver)
#PowerModels.update_data!(data, result["solution"])
#cuts = PowerModelsACDCsecurityconstrained.check_c1_contingencies_branch_power_GM(data, nlp_solver, total_cut_limit=20, gen_flow_cuts=[], branch_flow_cuts=[])    # Filtering 
#println(length(cuts.gen_cuts) + length(cuts.branch_cuts))
#data["gen_flow_cuts"] = cuts.gen_cuts
#data["branch_flow_cuts"] = cuts.branch_cuts
#data["branchdc_flow_cuts"] = cuts.branchdc_cuts

#result1 = PowerModelsACDCsecurityconstrained.run_c1_scopf_cuts_soft_GM(data, ACPPowerModel, nlp_solver)  #_GM

############################################# Soft test ################################################

