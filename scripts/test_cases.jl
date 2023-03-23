using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using Juniper
using HiGHS
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained
using Plots
using CalculusWithJulia
using LaTeXStrings
# using SCIP


const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-6)  
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)
# scip_solver = optimizer_with_attributes(SCIP.Optimizer)
########################################### case5_acdc_scopf.m ##########################################
# file = "./data/case5_acdc_scopf.m"
# data = parse_file(file)

# idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
# idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
# idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
# idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
# labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

# data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
# data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
# data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
# data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]

# data["area_gens"] = Dict{Int64, Set{Int64}}()
# data["area_gens"][1] = Set([1])

# data["contingencies"] = []  # This to empty the existing contingencies in the data

# for i=1:length(data["gen"])
#     data["gen"]["$i"]["ep"] = 1e-1
# end

# for i=1:length(data["convdc"])
#     data["convdc"]["$i"]["ep"] = 1e-1
# end

# data["gen"]["1"]["alpha"] = 15.92 
# data["gen"]["2"]["alpha"] = 11.09 

# data["branch"]["1"]["tm_min"] = 0.9; data["branch"]["1"]["tm_max"] = 1.1; data["branch"]["1"]["ta_min"] = 0.0;   data["branch"]["1"]["ta_max"] = 0.0
# data["branch"]["2"]["tm_min"] = 0.9; data["branch"]["2"]["tm_max"] = 1.1; data["branch"]["2"]["ta_min"] = 0.0;   data["branch"]["2"]["ta_max"] = 0.0

# data["branch"]["3"]["tm_min"] = 1;   data["branch"]["3"]["tm_max"] = 1;   data["branch"]["3"]["ta_min"] = 0.0;   data["branch"]["3"]["ta_max"] = 0.0
# data["branch"]["4"]["tm_min"] = 1;   data["branch"]["4"]["tm_max"] = 1;   data["branch"]["4"]["ta_min"] = 0.0;   data["branch"]["4"]["ta_max"] = 0.0 
# data["branch"]["5"]["tm_min"] = 1;   data["branch"]["5"]["tm_max"] = 1;   data["branch"]["5"]["ta_min"] = 0.0;   data["branch"]["5"]["ta_max"] = 0.0
# data["branch"]["6"]["tm_min"] = 1;   data["branch"]["6"]["tm_max"] = 1;   data["branch"]["6"]["ta_min"] = 0.0;   data["branch"]["6"]["ta_max"] = 0.0
# data["branch"]["7"]["tm_min"] = 1;   data["branch"]["7"]["tm_max"] = 1;   data["branch"]["7"]["ta_min"] = -15.0; data["branch"]["7"]["ta_max"] = 15.0

# PM_acdc.process_additional_data!(data)
# setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 
# data1 = deepcopy(data)
# result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, nlp_solver, setting)
# result_ACDC_scopf_soft_minlp = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data1, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft_minlp, minlp_solver, setting)

# # updating reference point 
# for i = 1:length(data["gen"])
#     data["gen"]["$i"]["pgref"] = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]["$i"]["pg"]
# end 
# # embedding unsecure contingencies
# if haskey(result_ACDC_scopf_soft, "gen_contingencies_unsecure") 
#     for (idx, label, type) in result_ACDC_scopf_soft["gen_contingencies_unsecure"]
#         data["gen"]["$idx"]["status"] = 0
#     end
# end
# if haskey(result_ACDC_scopf_soft, "branch_contingencies_unsecure")
#     for (idx, label, type) in result_ACDC_scopf_soft["branch_contingencies_unsecure"]
#         data["branch"]["$idx"]["br_status"] = 0
#     end
# end
# if haskey(result_ACDC_scopf_soft, "branchdc_contingencies_unsecure") 
#     for (idx, label, type) in result_ACDC_scopf_soft["branchdc_contingencies_unsecure"]
#         data["branchdc"]["$idx"]["status"] = 0
#     end
# end
# if haskey(result_ACDC_scopf_soft, "convdc_contingencies_unsecure") 
#     for (idx, label, type) in result_ACDC_scopf_soft["convdc_contingencies_unsecure"]
#         data["convdc"]["$idx"]["status"] = 0
#     end
# end
# data1 = deepcopy(data)
# data1["branch"]["6"]["br_status"] = 0
# result_ACDC_scopf_re_dispatch_oltc_pst =  PM_acdc_sc.run_acdcreopf_oltc_pst(data1, PM.ACPPowerModel, nlp_solver)
# # Re-dispatch_ots_oltc_pst
# data2 = deepcopy(data)
# data2["branch"]["5"]["br_status"] = 0
# result_ACDC_scopf_re_dispatch_ots_oltc_pst =  PM_acdc_sc.run_acdcreopf_ots_oltc_pst(data2, PM.ACPPowerModel, minlp_solver)


# ######################################### case5_2grids_acdc_sc.m #########################################
file = "./data/case5_2grids_acdc_sc.m"
data = parse_file(file)

idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([2, 1])
data["area_gens"][2] = Set([4, 3])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
end

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
end

data["gen"]["1"]["alpha"] = 15.92 
data["gen"]["2"]["alpha"] = 11.09 
data["gen"]["3"]["alpha"] = 15.92 
data["gen"]["4"]["alpha"] = 11.09 

for i=1:length(data["branch"])
    data["branch"]["$i"]["tm_min"] = 1
    data["branch"]["$i"]["tm_max"] = 1
    data["branch"]["$i"]["ta_min"] = 0.0
    data["branch"]["$i"]["ta_max"] = 0.0
end


PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, nlp_solver, setting)


# updating reference point 
for i = 1:length(data["gen"])
    data["gen"]["$i"]["pgref"] = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]["$i"]["pg"]
end 
# Re-dispatch_oltc_pst
data1 = deepcopy(data)
data1["branch"]["8"]["br_status"] = 0
result_ACDC_scopf_re_dispatch_oltc_pst =  PM_acdc_sc.run_acdcreopf_oltc_pst(data1, PM.ACPPowerModel, nlp_solver)
# Re-dispatch_ots_oltc_pst
data2 = deepcopy(data)
data2["branch"]["8"]["br_status"] = 0
result_ACDC_scopf_re_dispatch_ots_oltc_pst =  PM_acdc_sc.run_acdcreopf_ots_oltc_pst(data2, PM.ACPPowerModel, minlp_solver)

# ######################################### case5_lcc_acdc_sc.m #########################################
# file = "./data/case5_lcc_acdc_sc.m"
# data = parse_file(file)

# for i=1:length(data["convdc"])
#     data["convdc"]["$i"]["ep"] = 1e-1
#     data["convdc"]["$i"]["Vdclow"] = 0.98
#     data["convdc"]["$i"]["Vdchigh"] = 1.02
# end  


# PM_acdc.process_additional_data!(data)
# setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)


# resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)
# result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# ########################################### case5_dcgrid_sc.m ###########################################
# file = "./data/case5_dcgrid_sc.m"
# data = parse_file(file)

# for i=1:length(data["convdc"])
#     data["convdc"]["$i"]["ep"] = 1e-1
#     data["convdc"]["$i"]["Vdclow"] = 0.98
#     data["convdc"]["$i"]["Vdchigh"] = 1.02
# end  


# PM_acdc.process_additional_data!(data)
# setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

# resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)
# result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# ############################################# case5_b2bdc_sc.m #############################################
# file = "./data/case5_b2bdc_sc.m"
# data = parse_file(file)

# for i=1:length(data["convdc"])
#     data["convdc"]["$i"]["ep"] = 1e-1
#     data["convdc"]["$i"]["Vdclow"] = 0.98
#     data["convdc"]["$i"]["Vdchigh"] = 1.02
# end  


# PM_acdc.process_additional_data!(data)
# data["busdc"]["1"]["Pdc"] = 1
# setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

# resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)
# result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# ############################################# case24_3zones_acdc_sc.m #############################################

# file = "./data/case24_3zones_acdc_sc.m"
# data = parse_file(file)

# for i=1:length(data["convdc"])
#     data["convdc"]["$i"]["ep"] = 0.1
#     data["convdc"]["$i"]["Vdclow"] = 0.98
#     data["convdc"]["$i"]["Vdchigh"] = 1.02
# end  

# PM_acdc.process_additional_data!(data)
# setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

# resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# ############################################# case39_acdc_sc.m #############################################
# file = "./data/case39_acdc_sc.m"
# data = parse_file(file)

# for i=1:length(data["convdc"])
#     data["convdc"]["$i"]["ep"] = 0.1
#     data["convdc"]["$i"]["Vdclow"] = 0.98
#     data["convdc"]["$i"]["Vdchigh"] = 1.02
# end  

# PM_acdc.process_additional_data!(data)
# setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

# resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# ############################################# pglib_opf_case588_sdet_acdc_sc.m #############################################
# file = "./data/pglib_opf_case588_sdet_acdc_sc.m"
# data = parse_file(file)

# for i=1:length(data["convdc"])
#     data["convdc"]["$i"]["ep"] = 0.1
#     data["convdc"]["$i"]["Vdclow"] = 0.98
#     data["convdc"]["$i"]["Vdchigh"] = 1.02
# end  

# PM_acdc.process_additional_data!(data)
# setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

# resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# ############################################# case3120sp_acdc_sc.m #############################################
file = "./data/case3120sp_acdc_sc.m"
data = parse_file(file)

idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([1])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
end

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end
for i=1:length(data["gen"])
    data["gen"]["$i"]["alpha"] = 15.92
end 

for i=1:length(data["branch"])
    data["branch"]["$i"]["tm_min"] = 1
    data["branch"]["$i"]["tm_max"] = 1
    data["branch"]["$i"]["ta_min"] = 0.0
    data["branch"]["$i"]["ta_max"] = 0.0
end

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)
result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, nlp_solver, setting)


# updating reference point 
for i = 1:length(data["gen"])
    data["gen"]["$i"]["pgref"] = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]["$i"]["pg"]
end 
# Re-dispatch_oltc_pst
data1 = deepcopy(data)
data1["branch"]["8"]["br_status"] = 0
result_ACDC_scopf_re_dispatch_oltc_pst =  PM_acdc_sc.run_acdcreopf_oltc_pst(data1, PM.ACPPowerModel, nlp_solver)
# Re-dispatch_ots_oltc_pst
data2 = deepcopy(data)
data2["branch"]["8"]["br_status"] = 0
result_ACDC_scopf_re_dispatch_ots_oltc_pst =  PM_acdc_sc.run_acdcreopf_ots_oltc_pst(data2, PM.ACPPowerModel, minlp_solver)




############################################# case67_acdc_scopf.m #############################################
file = "./data/case67_acdc_scopf.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 0.1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end
data["convdc"]["8"]["Vdclow"] = 0.97
data["convdc"]["8"]["Vdchigh"] = 1.01

for i=1:length(data["branch"])
data["branch"]["$i"]["tm_min"] = 1
data["branch"]["$i"]["tm_max"] = 1
data["branch"]["$i"]["ta_min"] = 0.0
data["branch"]["$i"]["ta_max"] = 0.0
end

idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]

data["convdc_contingencies"] = Vector{Any}(undef, 4)
data["convdc_contingencies"][1] = (idx = 4, label = "36", type = "convdc")
data["convdc_contingencies"][2] = (idx = 5, label = "37", type = "convdc")
data["convdc_contingencies"][3] = (idx = 6, label = "38", type = "convdc")
data["convdc_contingencies"][4] = (idx = 7, label = "39", type = "convdc")

#data["branchdc_contingencies"] = []
data["gen_contingencies"] = []

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([4, 3, 2, 1])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
    # data["gen"]["$i"]["qmax"] = data["gen"]["$i"]["qmax"] + 1
    # data["gen"]["$i"]["qmin"] = data["gen"]["$i"]["qmin"] - 1
end

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
end

data["gen"]["1"]["alpha"] = 16.825
data["gen"]["2"]["alpha"] = 4.48667
data["gen"]["3"]["alpha"] = 30.5909 
data["gen"]["4"]["alpha"] = 5.60833
data["gen"]["5"]["alpha"] = 30.5909
data["gen"]["6"]["alpha"] = 26.92
data["gen"]["7"]["alpha"] = 22.4333
data["gen"]["8"]["alpha"] = 15.7216
data["gen"]["9"]["alpha"] = 7.12698
data["gen"]["10"]["alpha"] = 5.28235
data["gen"]["11"]["alpha"] = 6.23611
data["gen"]["12"]["alpha"] = 5.51586
data["gen"]["13"]["alpha"] = 6.23611
data["gen"]["14"]["alpha"] = 6.23611
data["gen"]["15"]["alpha"] = 5.33929
data["gen"]["16"]["alpha"] = 4.15278 
data["gen"]["17"]["alpha"] = 5.75
data["gen"]["18"]["alpha"] = 7.44349
data["gen"]["19"]["alpha"] = 4.74603
data["gen"]["20"]["alpha"] = 1

                               

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, nlp_solver, setting)

###########################################################################################################################################################################

# updating reference point 
for i = 1:length(data["gen"])
    data["gen"]["$i"]["pgref"] = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]["$i"]["pg"]
end 
# embedding unsecure contingencies
if haskey(result_ACDC_scopf_soft, "gen_contingencies_unsecure") 
    for (idx, label, type) in result_ACDC_scopf_soft["gen_contingencies_unsecure"]
        data["gen"]["$idx"]["status"] = 0
    end
end
if haskey(result_ACDC_scopf_soft, "branch_contingencies_unsecure")
    for (idx, label, type) in result_ACDC_scopf_soft["branch_contingencies_unsecure"]
        data["branch"]["$idx"]["br_status"] = 0
    end
end
if haskey(result_ACDC_scopf_soft, "branchdc_contingencies_unsecure") 
    for (idx, label, type) in result_ACDC_scopf_soft["branchdc_contingencies_unsecure"]
        data["branchdc"]["$idx"]["status"] = 0
    end
end
if haskey(result_ACDC_scopf_soft, "convdc_contingencies_unsecure") 
    for (idx, label, type) in result_ACDC_scopf_soft["convdc_contingencies_unsecure"]
        data["convdc"]["$idx"]["status"] = 0
    end
end
# Re-dispatch
#result_ACDC_scopf_re_dispatch =  PM_acdc_sc.run_acdcreopf(data, PM.ACPPowerModel, nlp_solver)
# Re-dispatch_oltc_pst
data1 = deepcopy(data)
data1["convdc"]["7"]["status"] = 0
result_ACDC_scopf_re_dispatch_oltc_pst =  PM_acdc_sc.run_acdcreopf_oltc_pst(data1, PM.ACPPowerModel, nlp_solver)
# Re-dispatch_ots_oltc_pst
data2 = deepcopy(data)
data2["branchdc"]["1"]["status"] = 0
result_ACDC_scopf_re_dispatch_ots_oltc_pst =  PM_acdc_sc.run_acdcreopf_ots_oltc_pst(data2, PM.ACPPowerModel, minlp_solver)

###########################################################################################################################################################################

# gen_p_adp = [gen["pg"] for (i,gen) in result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["gen"]] - [gen["pg"] for (i,gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]]   
# gen_p_adp_abs = sum(abs.(gen_p_adp))

# gen_q_adp = [gen["qg"] for (i,gen) in result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["gen"]] - [gen["qg"] for (i,gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]]
# gen_q_adp_abs = sum(abs.(gen_q_adp))

# b_status = [(i, branch["br_status"]) for (i, branch) in result_ACDC_scopf_re_dispatch_ots_oltc_pst["solution"]["branch"]]
# bdc_status = [(i, branchdc["brdc_status"]) for (i, branchdc) in result_ACDC_scopf_re_dispatch_ots_oltc_pst["solution"]["branchdc"]]

# PM.update_data!(data, result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"])

# result_ACDC_scopf_soft["branch_contingencies_unsecure"]
# result_ACDC_scopf_soft["branchdc_contingencies_unsecure"]
# result_ACDC_scopf_soft["convdc_contingencies_unsecure"]


# branch_id = result_ACDC_scopf_soft["branch_contingencies_unsecure"][2].idx
# data["branch"]["$branch_id"]["br_status"] = 0
# vio = PM_acdc_sc.calc_violations(data,data)



  



# f1(delta_k) = Pglb[i] + ep_g[i] * log( 1 + ( exp((Pgub[i]-Pglb[i])/ep_g[i]) / (1 + exp((Pgub[i] - Pgo[i] - alpha_g[i] * delta_k)/ep_g[i])) ) )

# f2(qg) =  Vmo[i]  - ep_g[i]*log(1 + exp(((vmub-Vmo[i]) - qg + qglb[i])/ep_g[i])) + ep_g[i]*log(1 + exp(((vmub-Vmo[i]) + qg - qgub[i])/ep_g[i]))

# f3(vdc) = (pref_dc + (  -((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
# -(-(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
# -((1 / k_droop * (vdclow - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc)) - (vdc - (vdclow - epsilon)) * (vdc - (vdcmin + epsilon)))/ep)))
# -(-((1 / k_droop * (vdclow - vdc + vdcmin - vdclow)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc + vdcmin - vdclow)) - (vdc - vdcmin + vdclow - (vdclow - epsilon)) * (vdc - vdcmin + vdclow - (vdcmin + epsilon)))/ep)))))     )




# f3(vdc) = (pref_dc + (   -((1 /  k_droop_i * (vdcmax - vdc) + 1 / k_droop_i * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop_i * (vdcmax - vdc) + 1 / k_droop_i * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
# -(-(1 / k_droop_i * (2*vdcmax - vdchigh - vdc) + 1 / k_droop_i * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop_i * (2*vdcmax - vdchigh - vdc) + 1 / k_droop_i * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
# -((1 / k_droop_r * (vdcmin - vdc) + 1 / k_droop_r * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop_r * (vdcmin - vdc) + 1 / k_droop_r * (vdclow - vdcmin)) - vdc + vdcmin)/ep)))
# -(-((1 / k_droop_r * (2*vdcmin - vdc - vdclow) + 1 / k_droop_r * (vdclow - vdcmin)) + ep*log(1 + exp((-( 1 / k_droop_r * (2*vdcmin - vdc - vdclow) + 1 / k_droop_r * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep)))   )))

# f3max(vdc) = (pref_dc -((1 / k_droop_max * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop_max * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
# -(-(1 / k_droop_max * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop_max * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
# -((1 / k_droop_max * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop_max * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - vdc + vdcmin)/ep)))
# -(-((1 / k_droop_max * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop_max * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep)))   )    )
  
# ########################################################################################################################################################################################################################################################################
# f4(vdc) = pref_dc + (   -((1 / k_droop * (vdchigh - vdc)) - ep * log(1 + exp(((1 / k_droop * (vdchigh - vdc) ) - vdcmax + vdc)/ep))) 
#         -(-(1 / k_droop * (vdcmax - vdc) ) + ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc)  ) - 2*vdcmax + vdchigh + vdc)/ep)) )
#         -((1 / k_droop * (vdclow - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc) ) - vdc + vdcmin)/ep)))
#         -(-((1 / k_droop * (vdcmin - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) ) - vdc + 2*vdcmin - vdclow )/ep)))   ))
# plot(f3, 0.8, 1.2)

# # droop Curve Plot
# plt = Plots.plot(layout=(8,4,2), size = (800,800), xformatter=:latex, yformatter=:latex)
# sp=7
#     i=sp+1
#     pref_dc = data["convdc"]["$i"]["Pdcset"] 
#     Vdcset = data["convdc"]["$i"]["Vdcset"]
#     vdcmax = data["convdc"]["$i"]["Vmmax"]
#     vdcmin = data["convdc"]["$i"]["Vmmin"]
#     vdchigh = data["convdc"]["$i"]["Vdchigh"]
#     vdclow = data["convdc"]["$i"]["Vdclow"]
#     k_droop = data["convdc"]["$i"]["droop"]
#     ep = data["convdc"]["$i"]["ep"]

    
#     # if pref_dc > 0
#     #     k_droop_i = 1/ (((1/k_droop) *(vdcmax - vdchigh) - pref_dc)/(vdcmax - vdchigh))
#     #     k_droop_r = 1/ (((1/k_droop) *(vdclow - vdcmin) + pref_dc)/(vdclow - vdcmin))
#     # elseif pref_dc < 0
#     #     k_droop_i = 1/ (((1/k_droop) *(vdcmax - vdchigh) - pref_dc)/(vdcmax - vdchigh))
#     #     k_droop_r = 1/ (((1/k_droop) *(vdclow - vdcmin) + pref_dc)/(vdclow - vdcmin))
#     # elseif pref_dc == 0
#     #     k_droop_i = k_droop
#     #     k_droop_r = k_droop
#     # end
    

#     epsilon = 1E-12

    
#     vdc = [nw["busdc"]["$i"]["vm"] for (j, nw) in result_ACDC_scopf_soft["final"]["solution"]["nw"]]
#     pdc = [nw["convdc"]["$i"]["pdc"] for (j, nw) in result_ACDC_scopf_soft["final"]["solution"]["nw"]]
    
#     vdco =  result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
#     pdco = result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

#     vdcf = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
#     pdcf = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

#     vdcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["busdc"]["$i"]["vm"]
#     pdcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["convdc"]["$i"]["pdc"]

#     vdcr2 = result_ACDC_scopf_re_dispatch_ots_oltc_pst["solution"]["busdc"]["$i"]["vm"]
#     pdcr2 = result_ACDC_scopf_re_dispatch_ots_oltc_pst["solution"]["convdc"]["$i"]["pdc"]

#     pmax =  pref_dc + ((1/k_droop * (vdcmax -vdcmin))/2) + 1
#     pmin =  pref_dc - ((1/k_droop * (vdcmax -vdcmin))/2) - 1


    
#     vspan!([vdclow, vdchigh], linecolor = :lightgrey, fillcolor = :lightgrey, xformatter=:latex, yformatter=:latex, label = false, subplot=sp)
#     plot!(f4, 0.85, 1.15, ylims =[pmin, pmax], linewidth=1, color="black", dpi = 300, xformatter=:latex, yformatter=:latex, label = false, legend = :false, grid = false, gridalpha = 0.5, gridstyle = :dash, subplot=sp)  #framestyle = :box  #legend_columns= -1,
#     vline!([vdcmin, vdcmax], linestyle = :dash, linecolor = :lightgrey, xformatter=:latex, yformatter=:latex, label = false, subplot=sp)
#     # scatter!([(vdci,pdci)],  markershape = :cross, markersize = 7, markercolor = :red, markerstrokecolor = :red, label = false, subplot=sp)
#     scatter!([(vdco,pdco)],  markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", subplot=sp)
#     # annotate!([(vdco,pdco+1.4, (L"base\;case\;solution", :red, :left, 7))], subplot=sp)
#     annotate!([(vdcmin,pdco, (L"v^{dc,l}_e", :black, :left, 12))], subplot=sp)
#     annotate!([(vdcmax,pdco, (L"v^{dc,u}_e", :black, :left, 12))], subplot=sp)
#     scatter!([(vdcf,pdcf)],  markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label = L"{\mathrm{final}}", subplot=sp)
#     # annotate!([(vdcf,pdcf+3.3, (L"final\;solution", :blue, :left, 7))], subplot=sp)
#     scatter!([(vdc,pdc)],  markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label = L"{\mathrm{contingencies}}", subplot=sp)
#     scatter!([(vdcr1,pdcr1)],  markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=sp)
#     scatter!([(vdcr2,pdcr2)],  markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=sp)
#     plot!(xlabel=L"{V^{\mathrm{dc}}_e(\mathrm{p.u})}", labelfontsize= 9,subplot=sp)
#     plot!(ylabel=L"{{P^{\mathrm{cv,dc}}_c}^ϵ(\mathrm{p.u})}", labelfontsize= 9, subplot=sp)
#     plot!(title=L"{\mathrm{Converter}\;8}", titlefontsize= 10, subplot=sp)

#    # legend
#     scatter!((1:3'), xlim = (4,5), markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", legend=:topleft, framestyle = :none, subplot=8)
#     scatter!((1:3'), xlim = (4,5), markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label = L"{\mathrm{final}}", subplot=8)
#     scatter!((1:3'), xlim = (4,5), markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label = L"{\mathrm{contingencies}}", subplot=8)
#     scatter!((1:3'), xlim = (4,5), markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=8)
#     scatter!((1:3'), xlim = (4,5), markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=8)
    

# savefig(plt, "droop_plot.png")
# ########################################################################################################################################################################################################################################################################

# f1(delta_k) = Pglb + ep_g * log( 1 + ( exp((Pgub-Pglb)/ep_g) / (1 + exp((Pgub - Pgo - alpha_g * delta_k)/ep_g)) ) )
# Plots.plot(f1)

# plt = Plots.plot(layout=(18, 9, 2), size = (1000,1600))
# #basemap(region=(0,10,0,10), frame=(axes=:Wsen, annot=:auto, label="Y Label"), figsize=10, par=(:MAP_LABEL_OFFSET, "30p"), show=true)
# sp=19
# Pgo = result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["gen"]["$sp"]["pg"]
# Pgf = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]["$sp"]["pg"]
# Pgub = data["gen"]["$sp"]["pmax"]
# Pglb = data["gen"]["$sp"]["pmin"]
# alpha_g = data["gen"]["$sp"]["alpha"]
# ep_g = data["gen"]["$sp"]["ep"]
# delta_kf = (Pgf .- Pgo)./alpha_g
# delta_k_max = (Pgub .- Pgo)./alpha_g .+ 0.1
# delta_k_min = (Pglb .- Pgo)./alpha_g .-0.1


# Pgc = [nw["gen"]["$sp"]["pg"] for (j, nw) in result_ACDC_scopf_soft["final"]["solution"]["nw"]]
# delta_kc = (Pgc .- Pgo) ./ alpha_g

# Pgcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["gen"]["$i"]["pg"]
# delta_kcr1 = (Pgcr1 .- Pgo) ./ alpha_g

# Pgcr2 = result_ACDC_scopf_re_dispatch_ots_oltc_pst["solution"]["gen"]["$i"]["pg"]
# delta_kcr2 = (Pgcr2 .- Pgo) ./ alpha_g

# sp = sp-2 

# using Plots.PlotMeasures
# gr(display_type=:inline)
# # vspan!([delta_k_min+0.1, delta_k_max-0.1], linecolor = :lightgrey, fillcolor = :lightgrey, label = false, subplot=sp)
# Plots.hline!([Pglb, Pgub], xlims=[delta_k_min, delta_k_max], linestyle = :dash, linecolor = :lightgrey, label = false, subplot=sp)
# Plots.plot!(f1, delta_k_min, delta_k_max, ylims=[0, Pgub+1], xformatter=:latex, yformatter=:latex, linewidth=1,color="black", dpi = 300, label = false, legend =false, grid = false, gridalpha = 0.5, gridstyle = :dash, left_margin = 8mm, right_margin = 2mm, subplot=sp)  # legend = :outerright, legend_columns= -1,
# Plots.annotate!([(delta_k_max-0.08,Pglb, (L"\Re(s^\mathrm{gl}_n)", :black, :left, 12))], subplot=sp)
# Plots.annotate!([(delta_k_min+0.01,Pgub, (L"\Re(s^\mathrm{gu}_n)", :black, :left, 12))], subplot=sp)
# Plots.scatter!([(0,Pgo)],  markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", subplot=sp)
# Plots.scatter!([(delta_kf, Pgf)],  markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label =L"{\mathrm{final}}", subplot=sp)
# Plots.scatter!([(delta_kc,Pgc)],  markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label =L"{\mathrm{contingencies}}", subplot=sp)
# Plots.scatter!([(delta_kcr1,Pgcr1)],  markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=sp)
# Plots.scatter!([(delta_kcr2,Pgcr2)],  markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=sp)
    

# Plots.plot!(xlabel=L"{V^{\mathrm{dc}}_e(\mathrm{p.u})}", labelfontsize= 9,subplot=sp)
# Plots.plot!(ylabel=L"{\Re(S^{\mathrm{g}}_{nk})^{\epsilon}(\mathrm{p.u})}", labelfontsize= 9, subplot=sp)
# Plots.plot!(title=L"{\mathrm{Generator}\;19}", titlefontsize= 10, subplot=sp)


# Plots.scatter!((1:3'), xlim = (4,5), markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", legend=:topleft, framestyle = :none, subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label =L"{\mathrm{final}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label =L"{\mathrm{contingencies}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=18)
 

# Plots.savefig(plt, "p_response.png")
# ########################################################################################################################################################################################################################################################################
# f2(qg) =  Vmo + ep_g*log(1 + exp(((vmub-Vmo) - qg + qglb)/ep_g)) -  ep_g*log(1 + exp(((Vmo-vmlb) + qg - qgub)/ep_g))
# plot(f2, qglb, qgub)

# plt = Plots.plot(layout=(18, 9, 2), size = (1000,1800))
# #basemap(region=(0,10,0,10), frame=(axes=:Wsen, annot=:auto, label="Y Label"), figsize=10, par=(:MAP_LABEL_OFFSET, "30p"), show=true)
# sp=8
# vmub = 1.1
# vmlb = 0.9
# ep_g = data["gen"]["$sp"]["ep"] = 0.01
# gen_bus = data["gen"]["$sp"]["gen_bus"]
# # qgo = result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["gen"]["$sp"]["qg"]
# qgo = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]["$sp"]["qg"]
# # Vmo = result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["bus"]["$gen_bus"]["vm"]
# Vmo = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["$gen_bus"]["vm"]

# qgub = data["gen"]["$sp"]["qmax"]
# qglb = data["gen"]["$sp"]["qmin"] 


# Vmc = [nw["bus"]["$gen_bus"]["vm"] for (j, nw) in result_ACDC_scopf_soft["final"]["solution"]["nw"] if j!=="0"]
# qgc = [nw["gen"]["$sp"]["qg"] for (j, nw) in result_ACDC_scopf_soft["final"]["solution"]["nw"] if j!=="0"]

# # qgcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["gen"]["$i"]["qg"]
# # Vmcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["bus"]["$gen_bus"]["vm"]

# # qgcr2 = result_ACDC_scopf_re_dispatch_ots_oltc_pst["solution"]["gen"]["$i"]["qg"]
# # Vmcr2 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["bus"]["$gen_bus"]["vm"]

# sp = sp-2 

# using Plots.PlotMeasures
# Plots.vline!([qglb, qgub], ylims = [0.80, 1.25],linestyle = :dash, linecolor = :lightgrey, label = false, subplot=sp) # xlims=[delta_k_min, delta_k_max]
# Plots.plot!(f2, qglb, qgub, xformatter=:latex, yformatter=:latex, linewidth=1,color="black", dpi = 300, label = false, legend =false, grid = false, gridalpha = 0.5, gridstyle = :dash, left_margin = 9mm, right_margin = 2mm, subplot=sp)  #  ylims=[0, Pgub+1] legend = :outerright, legend_columns= -1,
# Plots.annotate!([(qglb+0.08,vmlb-0.02, (L"\Im(s^\mathrm{gl}_n)", :black, :left, 12))], subplot=sp)
# Plots.annotate!([(qgub-2,vmub+0.04, (L"\Im(s^\mathrm{gu}_n)", :black, :left, 12))], subplot=sp)
# Plots.scatter!([(qgo,Vmo)], markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", subplot=sp)
# # Plots.scatter!([(qgf,Vmf)], markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label =L"{\mathrm{final}}", subplot=sp)
# Plots.scatter!([(qgc,Vmc)], markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label =L"{\mathrm{contingencies}}", subplot=sp)
# # Plots.scatter!([(qgcr1,Vmcr1)], markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=sp)
# # Plots.scatter!([(qgcr2,Vmcr2)], markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=sp)
    

# Plots.plot!(xlabel=L"{\Im(S^{\mathrm{g}}_{n})^{\epsilon}(\mathrm{p.u})}", labelfontsize= 9,subplot=sp)
# Plots.plot!(ylabel=L"{|V_i|(\mathrm{p.u})}", labelfontsize= 9, subplot=sp)
# str = string(sp+2) 
# Plots.plot!(title=L"{\mathrm{Generator}\;%$str}", titlefontsize= 10, subplot=sp)


# Plots.scatter!((1:3'), xlim = (4,5), markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{final}\;case\;0}", legend=:topleft, framestyle = :none, subplot=18)
# # Plots.scatter!((1:3'), xlim = (4,5), markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label =L"{\mathrm{final}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label =L"{\mathrm{contingencies}\;cases\;1,2,...}", subplot=18)
# # Plots.scatter!((1:3'), xlim = (4,5), markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=18)
# # Plots.scatter!((1:3'), xlim = (4,5), markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=18)
 

# Plots.savefig(plt, "q2_response.png")







# ########################################################################################################################################################################################################################################################################

# resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# ############################################# casexxxxxxxxxxxxxxxxxx.m #############################################


# resultpf = PM_acdc.run_acdcpf( data, PM.ACPPowerModel, nlp_solver; setting = setting)
# resultopf = PM_acdc.run_acdcopf( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

# resultopf = PM_acdc.run_acdcopf( data, PM.ACPPowerModel, nlp_solver; setting = setting)
# for i=1:length(data["convdc"])
#     data["convdc"]["$i"]["Pdcset"] = resultpf_droop["solution"]["convdc"]["$i"]["pdc"]
# end
# result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)
# x1 = x2 = x3 =0
# y=zeros(Float64, 1,20)
# for i=1:8
#     x1 = x1 + data["gen"]["$i"]["pmax"] 
# end
# for i=9:14
#     x2 = x2 + data["gen"]["$i"]["pmax"] 
# end
# for i=15:19
#     x3 = x3 + data["gen"]["$i"]["pmax"] 
# end
# for i=1:8
#     y[i] = x1/result_droop["solution"]["gen"]["$i"]["pg"]
# end
# for i=9:14
#     y[i] = x2/result_droop["solution"]["gen"]["$i"]["pg"]
# end
# for i=15:19
#     y[i] = x3/result_droop["solution"]["gen"]["$i"]["pg"]
# end


# forx/result_droop["solution"]["gen"]["1"]["pg"] 
# result_droop["solution"]["gen"]["17"]["pg"]  +
# result_droop["solution"]["gen"]["18"]["pg"]  +
# result_droop["solution"]["gen"]["19"]["pg"]


# x/result_droop["solution"]["gen"]["15"]["pg"]
# x/result_droop["solution"]["gen"]["16"]["pg"]
# x/result_droop["solution"]["gen"]["17"]["pg"]  
# x/result_droop["solution"]["gen"]["18"]["pg"]  
# x/result_droop["solution"]["gen"]["19"]["pg"]  



# f2(qg) =  Vmo[i]  - ep_g[i]*log(1 + exp(((vmub-Vmo[i]) - qg + qglb[i])/ep_g[i])) + ep_g[i]*log(1 + exp(((vmub-Vmo[i]) + qg - qgub[i])/ep_g[i]))

# plot(f2)

# ep = 0.5
# f3(vdc) = (pref_dc +  (   (ep*log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
# -( ep*log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
# -( ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - vdc + vdcmin)/ep)))
# +( ep*log(1 + exp((-(1 / k_droop * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep))   )))

# f31(vdc) = (pref_dc +  ( ( ep*log(1+exp(((1 / k_droop * (vdchigh - vdc)) - vdcmax + vdc)/ep))) 
#                         -( ep*log(1+exp(((1 / k_droop * (vdcmax - vdc)  ) - 2*vdcmax + vdchigh + vdc)/ep)) )
#                         -( ep*log(1+exp((-(1 / k_droop * (vdclow - vdc) ) - vdc + vdcmin)/ep)))
#                         +( ep*log(1+exp((-(1 / k_droop * (vdcmin - vdc) ) - vdc + 2*vdcmin - vdclow )/ep))   )))

# plot(f3, 0.8, 1.2)

# plot(f31, 0.8, 1.2)



# plot([gen["qg"] for (i,gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]], label = "base")

# plot!([gen["qg"] for (i,gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["gen"]], label = "c1")

# plot!([gen["qmax"] for (i,gen) in data["gen"]], seriestype = :stepmid, label = "qmax")

# plot!([gen["qmin"] for (i,gen) in data["gen"]], seriestype = :stepmid, label = "qmin")

# savefig("qg.png")

# k1=k2 = k3=Vector{Float64}(1:20)
# # j = [1 2 4 5 10 13 18 25 29 33 36 41 43 50 56 59 63 64 66 67]
# k1[1] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["1"]["vm"]
# k1[2] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["2"]["vm"]
# k1[3] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["4"]["vm"]
# k1[4] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["5"]["vm"]
# k1[5] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["10"]["vm"]
# k1[6] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["13"]["vm"]
# k1[7] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["18"]["vm"]
# k1[8] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["25"]["vm"]
# k1[9] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["29"]["vm"]
# k1[10] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["33"]["vm"]
# k1[11] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["36"]["vm"]
# k1[12] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["41"]["vm"]
# k1[13] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["43"]["vm"]
# k1[14] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["50"]["vm"]
# k1[15] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["56"]["vm"]
# k1[16] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["59"]["vm"]
# k1[17] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["63"]["vm"]
# k1[18] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["64"]["vm"]
# k1[19] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["66"]["vm"]
# k1[20] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["67"]["vm"]

# k2[1] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["1"]["vm"]
# k2[2] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["2"]["vm"]
# k2[3] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["4"]["vm"]
# k2[4] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["5"]["vm"]
# k2[5] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["10"]["vm"]
# k2[6] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["13"]["vm"]
# k2[7] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["18"]["vm"]
# k2[8] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["25"]["vm"]
# k2[9] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["29"]["vm"]
# k2[10] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["33"]["vm"]
# k2[11] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["36"]["vm"]
# k2[12] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["41"]["vm"]
# k2[13] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["43"]["vm"]
# k2[14] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["50"]["vm"]
# k2[15] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["56"]["vm"]
# k2[16] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["59"]["vm"]
# k2[17] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["63"]["vm"]
# k2[18] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["64"]["vm"]
# k2[19] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["66"]["vm"]
# k2[20] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["67"]["vm"]


# k3[1] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["1"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["1"]["vm"]
# k3[2] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["2"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["2"]["vm"]
# k3[3] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["4"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["4"]["vm"]
# k3[4] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["5"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["5"]["vm"]
# k3[5] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["10"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["10"]["vm"]
# k3[6] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["13"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["13"]["vm"]
# k3[7] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["18"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["18"]["vm"]
# k3[8] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["25"]["vm"] -  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["25"]["vm"]
# k3[9] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["29"]["vm"] -  result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["29"]["vm"]
# k3[10] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["33"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["33"]["vm"]
# k3[11] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["36"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["36"]["vm"]
# k3[12] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["41"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["41"]["vm"]
# k3[13] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["43"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["43"]["vm"]
# k3[14] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["50"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["50"]["vm"]
# k3[15] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["56"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["56"]["vm"]
# k3[16] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["59"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["59"]["vm"]
# k3[17] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["63"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["63"]["vm"]
# k3[18] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["64"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["64"]["vm"]
# k3[19] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["66"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["66"]["vm"]
# k3[20] =  result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]["67"]["vm"] - result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]["67"]["vm"]



# plot(k1, label = "base")
# plot!(k2, label = "c1")
# savefig("vg.png")
# plot(-k3, label = "diff")
# savefig("vgdiff.png")



# #diagrams

# Pgub = 10
# Pglb = 1
# alpha_g = 4.6
# ep_g = 2

# Pgo = 5

# # #f(delta_k) = Pgub - ep_g * log(1 + exp((Pgub - Pgo - alpha_g * delta_k)/ep_g) )

# f1(delta_k) = Pglb + ep_g * log( 1 + ( exp((Pgub-Pglb)/ep_g) / (1 + exp((Pgub - Pgo - alpha_g * delta_k)/ep_g)) ) )
# plot(f1, -10, 10, grid = false, ylimit = [0,11], linewidth=1, color="grey", dpi = 600, legend = false)
# plot!(f1, -10, 10, grid = false, linewidth=1, color="black")
# savefig("diag1.png")

# vmub = 1.1
# vmlb = 0.9
# qglb = -5
# qgub = 5
# Vmo = 1.0
# ep_g = 0.05


# f2(qg) =  Vmo + ep_g*log(1 + exp(((vmub-Vmo) - qg + qglb)/ep_g)) -  ep_g*log(1 + exp(((Vmo-vmlb) + qg - qgub)/ep_g))
# plot(f2, -5, 5, grid = false, linewidth=1, color="black", dpi = 600, legend = false)
# plot!(f2, -5, 5, grid = false, linewidth=1, color="black")
# savefig("diag2.png")



#     pref_dc = data["convdc"]["$i"]["Pdcset"] 
#     Vdcset = data["convdc"]["$i"]["Vdcset"]
#     vdcmax = data["convdc"]["$i"]["Vmmax"]
#     vdcmin = data["convdc"]["$i"]["Vmmin"]
#     vdchigh = data["convdc"]["$i"]["Vdchigh"]
#     vdclow = data["convdc"]["$i"]["Vdclow"]
#     k_droop = data["convdc"]["$i"]["droop"]
#     ep = data["convdc"]["$i"]["ep"]
#     vdchigh = 1.04
#     vdclow = 1
#     ep = 1
    
# f31(vdc) = (11 +  ( ( ep*log(1+exp(((1 / k_droop * (vdchigh - vdc)) - vdcmax + vdc)/ep))) 
#                         -( ep*log(1+exp(((1 / k_droop * (vdcmax - vdc)  ) - 2*vdcmax + vdchigh + vdc)/ep)) )
#                         -( ep*log(1+exp((-(1 / k_droop * (vdclow - vdc) ) - vdc + vdcmin)/ep)))
#                         +( ep*log(1+exp((-(1 / k_droop * (vdcmin - vdc) ) - vdc + 2*vdcmin - vdclow )/ep))   )))



# plot(f3,  0.8, 1.2, grid = false, linewidth=1, color="grey", dpi = 600, legend = false)
# plot(f31, 0.8, 1.2, grid = false, linewidth=1, color="black")
# plot(f4, 0.8, 1.2, grid = false, linewidth=1, color="black")


# f3(vdc) = (pref_dc + (  -((1 / k_droop * (vdchigh - vdc)) - ep * log(1 + exp(((1 / k_droop * (vdchigh - vdc) ) - vdcmax + vdc)/ep))) 
# -(-(1 / k_droop * (vdcmax - vdc) ) + ep * log(1 + exp(((1 / k_droop * (vdcmax  - vdc)  ) - 2*vdcmax + vdchigh + vdc)/ep)) )
# -((1 / k_droop * (vdclow - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc)) - (vdc - (vdclow - epsilon)) * (vdc - (vdcmin + epsilon)))/ep)))
# -(-((1 / k_droop * (- vdc + vdcmin )) + ep*log(1 + exp((-(1 / k_droop * (- vdc + vdcmin  )) - (vdc - vdcmin + vdclow - (vdclow - epsilon)) * (vdc - vdcmin + vdclow - (vdcmin + epsilon)))/ep)))))     )

# vdchigh = 1.01
# vdclow = 0.97

# f4(vdc) = pref_dc + (   -((1 / k_droop * (vdchigh - vdc)) - ep * log(1 + exp(((1 / k_droop * (vdchigh - vdc) ) - vdcmax + vdc)/ep))) 
#         -(-(1 / k_droop * (vdcmax - vdc) ) + ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc)  ) - 2*vdcmax + vdchigh + vdc)/ep)) )
#         -((1 / k_droop * (vdclow - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc) ) - vdc + vdcmin)/ep)))
#         -(-((1 / k_droop * (vdcmin - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) ) - vdc + 2*vdcmin - vdclow )/ep)))   ))



# # Contingency 15 ac line 54
# (vm = 0.0, pg = 1.375966007799434e-11, qg = 3.6034253326927037, sm = 2.0582671857843184, smdc = 0.0, cmac = 0.0, cmdc = 0.0)
# vio_data = Dict{Any, Any}("branchdcv" => Any[], "genp" => Any[], "genq" => Any[], "branchv" => Any[("45", 0.8373393368519224), ("45", 1.220927848932396)])

# # Contingency 14 ac line 45
# (vm = 0.0, pg = 1.6275869541004795e-11, qg = 3.617765335952612, sm = 0.05687838710674065, smdc = 0.0, cmac = 0.0, cmdc = 0.0)
# vio_data = Dict{Any, Any}("branchdcv" => Any[], "genp" => Any[], "genq" => Any[], "branchv" => Any[("54", 0.05687838710674065)])

# # Contingency 20 dc line 1
# (vm = 0.0, pg = 3.072031518058793e-11, qg = 3.525322331378617, sm = 0.0, smdc = 14.44109803940336, cmac = 0.0, cmdc = 0.0)
# vio_data = Dict{Any, Any}("branchdcv" => Any[("2", 7.3832274034653445), ("2", 7.057870635938016)], "genp" => Any[], "genq" => Any[], "branchv" => Any[])

# # Contingency 21 dc line 2
# (vm = 0.0, pg = 3.824585093070709e-11, qg = 3.566192380903863, sm = 0.0, smdc = 14.058774282174088, cmac = 0.0, cmdc = 0.0)
# vio_data = Dict{Any, Any}("branchdcv" => Any[("1", ), ("1", 6.871520281870328)], "genp" => Any[], "genq" => Any[], "branchv" => Any[])

# # Contingency 36 converter 4
# (vm = 0.0, pg = 3.8463454643533623e-11, qg = 3.639074383820459, sm = 0.0, smdc = 0.17469960489407654, cmac = 0.0, cmdc = 0.0) 
# vio_data = Dict{Any, Any}("branchdcv" => Any[("1", 0.1633352706156117), ("1", 0.011364334278464838)], "genp" => Any[], "genq" => Any[], "branchv" => Any[])

# # Contingency 39 converter 7
# (vm = 0.0, pg = 3.8681946534779854e-11, qg = 2.9422050634191903, sm = 0.0, smdc = 0.14557129061765472, cmac = 0.0, cmdc = 0.0)
# vio_data = Dict{Any, Any}("branchdcv" => Any[("1", 0.14557129061765472)], "genp" => Any[], "genq" => Any[], "branchv" => Any[])

# (sqrt(result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["branch"]["54"]["pt"]^2 + result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["branch"]["54"]["qt"]^2) / 9) * 100
# (sqrt(result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["branch"]["45"]["pt"]^2 + result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["branch"]["45"]["qt"]^2) / 9) * 100
# (result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["branchdc"]["1"]["pf"] /15.75) * 100
# (result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["branchdc"]["2"]["pf"] /15.75) * 100


# ########################################### visuallization ##########################################
# ########################################### visuallization ##########################################

# # # gen p responnse
#  delta_kk = []
#  delta_kkn = []
# # ep_g = [gen["ep"] for (i, gen) in data["gen"]]
#  Pgo = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["gen"]]
#  Pgf = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]]
#  pgc1 = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["gen"]]
#  pgc2 = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["2"]["gen"]]

#  Pgon = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["gen"]]
#  Pgfn= [gen["pg"] for (i, gen) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["gen"]]
#  pgc1n = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["1"]["gen"]]
#  pgc2n = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["2"]["gen"]]
 
# # pgc3 = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["3"]["gen"]]
# # pgc4 = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["4"]["gen"]]
# # pgc5 = [gen["pg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["5"]["gen"]]
# Pgub = [gen["pmax"] for (i, gen) in data["gen"]]
# Pglb = [gen["pmin"] for (i, gen) in data["gen"]]
# alpha_g = [gen["alpha"] for (i, gen) in data["gen"]]
# ep_g = [gen["ep"] for (i, gen) in data["gen"]]

# Pgub = 12
# Pglb = 1
# alpha_g = 5.6
# ep_g = 0.1

# # #f(delta_k) = Pgub - ep_g * log(1 + exp((Pgub - Pgo - alpha_g * delta_k)/ep_g) )
# f1(delta_k) = Pglb[i] + ep_g[i] * log( 1 + ( exp((Pgub[i]-Pglb[i])/ep_g[i]) / (1 + exp((Pgub[i] - Pgo[i] - alpha_g[i] * delta_k)/ep_g[i])) ) )
# plot(f1, 1, 12)

# plot(layout=(3,2))
#  sp=1
# # # i=1
# # push!(delta_kk, (Pgf[i] - Pgo[i])/alpha_g[i])

# # plot!(subplot=sp,f1,-0.5, 0.5, linewidth=1,color="black", label = L"P^{g}(\Delta_k)", legend = :topright)
# # scatter!([(0,Pgo[i])], markershape = :cross, markersize = 5, markercolor = :red, label = false, subplot=sp)
# # scatter!([(delta_kk[i],Pgf[i])], markershape = :cross, markersize = 5, markercolor = :blue, label = false, subplot=sp)
# # plot!(xlabel=L"{\Delta_k}",subplot=sp)
# # plot!(ylabel=L"{P^{g}(\Delta_k) (p.u)}",subplot=sp)
# # sp=2

# # # Plot 1
# i=1
# push!(delta_kk, (Pgf[i] - Pgo[i])/alpha_g[i])
# push!(delta_kkn, (Pgfn[i] - Pgon[i])/alpha_g[i])
# plot(f1,-0.5, 0.5, linewidth=1,color="black", label = L"P^{g}(\Delta_k)", legend = :topright, grid = true, gridalpha = 0.5, gridstyle = :dash, framestyle = :box)
# scatter!([(0,Pgo[i])], markershape = :star7, markersize = 10, markercolor = :red, markerstrokecolor = :red, label = false)
# scatter!([(0,Pgon[i])], markershape = :star7, markersize = 10, markercolor = :red, markerstrokecolor = :red, label = false)
# annotate!([(0.05,Pgo[i], (L"base\;case\;solution", :red, :left, 10))])
# scatter!([(delta_kk[i],Pgf[i])], markershape = :star7, markersize = 10, markercolor = :blue, markerstrokecolor = :blue, label = false)
# scatter!([(delta_kk[i],Pgfn[i])], markershape = :star7, markersize = 10, markercolor = :blue, markerstrokecolor = :blue, label = false)

# annotate!([(delta_kk[i]+0.05,Pgf[i], (L"final\;solution", :blue, :left, 10))])
# scatter!([(((pgc1[i] - Pgo[i])/alpha_g[i]),pgc1[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green, label = false)
# scatter!([(((pgc2[i] - Pgo[i])/alpha_g[i]),pgc2[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)
# scatter!([(((pgc1n[i] - Pgon[i])/alpha_g[i]),pgc1n[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green, label = false)
# scatter!([(((pgc2n[i] - Pgon[i])/alpha_g[i]),pgc2n[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)

# # scatter!([(((pgc3[i] - Pgo[i])/alpha_g[i]),pgc3[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)
# # scatter!([(((pgc4[i] - Pgo[i])/alpha_g[i]),pgc4[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)
# # scatter!([(((pgc5[i] - Pgo[i])/alpha_g[i]),pgc5[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)
# plot!(xlabel=L"{\Delta_k}")
# plot!(ylabel=L"{P^{g}(\Delta_k) (p.u)}")
# savefig("Gen1P.png")


# # # Plot 1
# i=2
# plot(f1,-0.8, 0.8, linewidth=1,color="black", label = L"P^{g}(\Delta_k)", legend = :topright, grid = true, gridalpha = 0.5, gridstyle = :dash, framestyle = :box)
# scatter!([(0,Pgo[i]+0.018)], markershape = :star7, markersize = 10, markercolor = :red, markerstrokecolor = :red, label = false)
# annotate!([(0.05,Pgo[i]+0.015, (L"base\;case\;solution", :red, :left, 10))])
# scatter!([((Pgf[i] - Pgo[i])/alpha_g[i],Pgf[i])], markershape = :star7, markersize = 10, markercolor = :blue, label = false)
# annotate!([((Pgf[i] - Pgo[i])/alpha_g[i]+0.05,Pgf[i], (L"final\;solution", :blue, :left, 10))])
# # scatter!([(((pgc1[i] - Pgo[i])/alpha_g[i]),pgc1[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green, label = false)
# # scatter!([(((pgc2[i] - Pgo[i])/alpha_g[i]),pgc2[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)
# # scatter!([(((pgc3[i] - Pgo[i])/alpha_g[i]),pgc3[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)
# # scatter!([(((pgc4[i] - Pgo[i])/alpha_g[i]),pgc4[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)
# # scatter!([(((pgc5[i] - Pgo[i])/alpha_g[i]),pgc5[i])], markershape = :star7, markersize = 7, markercolor = :green, markerstrokecolor = :green,label = false)
# plot!(xlabel=L"{\Delta_k}")
# plot!(ylabel=L"{P^{g}(\Delta_k) (p.u)}")
# savefig("Gen2P.png")

# qgub = [gen["qmax"] for (i, gen) in data["gen"]]
# qglb = [gen["qmin"] for (i, gen) in data["gen"]]
# vmub = 1.1
# vmlb = 0.9
 

# f2(qg) =  Vmo[i]  - ep_g[i]*log(1 + exp(((vmub-Vmo[i]) - qg + qglb[i])/ep_g[i])) + ep_g[i]*log(1 + exp(((vmub-Vmo[i]) + qg - qgub[i])/ep_g[i]))


# Qgo = [gen["qg"] for (i, gen) in result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["gen"]]
# Qgf = [gen["qg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]]
# Vmo = [(i,bus["vm"]) for (i, bus) in result_ACDC_scopf_soft["base"]["solution"]["nw"]["0"]["bus"]]
# Vmf = [bus["vm"] for (i, bus) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"]]

# Vmc = [(i,bus["vm"]) for (i, bus) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]]
# Vmc_pos = [bus["vg_pos"] for (i, bus) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]]
# Vmc_neg = [bus["vg_neg"] for (i, bus) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["bus"]]
# qgc1 = [gen["qg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["1"]["gen"]]
# qgc2 = [gen["qg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["2"]["gen"]]
# qgc3 = [gen["qg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["3"]["gen"]]
# qgc4 = [gen["qg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["4"]["gen"]]

# qgc5 = [gen["qg"] for (i, gen) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["5"]["gen"]]


# # Plot 3
# i=2
# plot(f2,-5, 5, linewidth=1,color="black", label = L"V^{g}(Q^g)", legend = :topright, grid = true, gridalpha = 0.5, gridstyle = :dash, framestyle = :box)
# scatter!([(Qgo[i],Vmo[i])], markershape = :star7, markersize = 10, markercolor = :red, markerstrokecolor = :red, label = false)
# annotate!([(Qgo[i],Vmo[i]+0.009, (L"base\;case\;solution", :red, :left, 10))])
# scatter!([(Qgf[i],Vmf[i])], markershape = :star7, markersize = 10, markercolor = :blue, markerstrokecolor = :blue, label = false)
# annotate!([(Qgf[i],Vmf[i]+0.02 + 0.009, (L"final\;solution", :blue, :left, 10))])
# scatter!([(qgc1[i],Vmc[i])], markershape = :star7, markersize = 10, markercolor = :blue, markerstrokecolor = :blue, label = false)
# ylims!(.9,1.1)
# plot!(xlabel=L"{Q^g(p.u)}")
# plot!(ylabel=L"{V^{g}(Q^g) (p.u)}")
# savefig("Gen1Q.png")

# # Plot 4
# i=2
# plot(f2,-3, 3, linewidth=1,color="black", label = L"V^{g}(Q^g)", legend = :topright, grid = true, gridalpha = 0.5, gridstyle = :dash, framestyle = :box)
# scatter!([(Qgo[i],Vmo[i])], markershape = :star7, markersize = 10, markercolor = :red, markerstrokecolor = :red, label = false)
# annotate!([(Qgo[i],Vmo[i]+0.009, (L"base\;case\;solution", :red, :left, 10))])
# scatter!([(Qgf[i],Vmf[i]+0.046)], markershape = :star7, markersize = 10, markercolor = :blue, markerstrokecolor = :blue, label = false)
# annotate!([(Qgf[i],Vmf[i]+0.046 + 0.02, (L"final\;solution", :blue, :left, 10))])
# plot!(xlabel=L"{Q^g(p.u)}")
# plot!(ylabel=L"{V^{g}(Q^g) (p.u)}")
# savefig("Gen2Q.png")

# # # Plot 5
# i= 1
# pref_dc = data["convdc"]["$i"]["Pdcset"]
# vdcmax = data["convdc"]["$i"]["Vmmax"]
# vdcmin = data["convdc"]["$i"]["Vmmin"]
# vdchigh = data["convdc"]["$i"]["Vdchigh"]
# vdclow = data["convdc"]["$i"]["Vdclow"]
# k_droop = data["convdc"]["$i"]["droop"]
# ep = data["convdc"]["$i"]["ep"]
# epsilon = 1E-12


# f3(vdc) = pref_dc +( (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))
# -(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep))
# +((1 / k_droop * (vdclow - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc)) - (vdc - (vdclow - epsilon)) * (vdc - (vdcmin + epsilon)))/ep)))
# -((1 / k_droop * (vdclow - vdc + vdcmin - vdclow)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc + vdcmin - vdclow)) - (vdc - vdcmin + vdclow - (vdclow - epsilon)) * (vdc - vdcmin + vdclow - (vdcmin + epsilon)))/ep))) )

# plot(f4,0.8, 1.2, linewidth=1,color="black", label = L"P^{c}(V^c_{dc})", legend = :topright, grid = true, gridalpha = 0.5, gridstyle = :dash, framestyle = :box)

# vdcb = result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
# pdcb = result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

# vdcf = result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
# pdcf = result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

# scatter!([(vdcb,pdcb)],  markershape = :star7, markersize = 10, markercolor = :red, markerstrokecolor = :red, label = false)
# annotate!([(vdcb,pdcb+1.4, (L"base\;case\;solution", :red, :left, 10))])
# scatter!([(vdcf,pdcf)],  markershape = :star7, markersize = 10, markercolor = :blue, markerstrokecolor = :blue, label = false)
# annotate!([(vdcf,pdcf+3.3, (L"final\;solution", :blue, :left, 10))])

# plot!(xlabel=L"{V^c_{dc}(p.u)}")
# plot!(ylabel=L"{P^{c}(V^c_{dc}) (p.u)}")
# savefig("Con2d.png")


# i= 1
# pref_dc = data["convdc"]["$i"]["Pdcset"]
# vdcmax = data["convdc"]["$i"]["Vmmax"]
# vdcmin = data["convdc"]["$i"]["Vmmin"]
# vdchigh = data["convdc"]["$i"]["Vdchigh"]
# vdclow = data["convdc"]["$i"]["Vdclow"]
# k_droop = data["convdc"]["$i"]["droop"]
# ep = data["convdc"]["$i"]["ep"]
# epsilon = 1E-12

# f(vdc) = pref_dc +( (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))
# -(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep))
# +((1 / k_droop * (vdclow - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc)) - (vdc - (vdclow - epsilon)) * (vdc - (vdcmin + epsilon)))/ep)))
# -((1 / k_droop * (vdclow - vdc + vdcmin - vdclow)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc + vdcmin - vdclow)) - (vdc - vdcmin + vdclow - (vdclow - epsilon)) * (vdc - vdcmin + vdclow - (vdcmin + epsilon)))/ep))) )

# vdc_base = result_ACDC_scopf_soft_w["base"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
# pdc_base = result_ACDC_scopf_soft_w["base"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

# vdc_final = result_ACDC_scopf_soft_w["final"]["solution"]["busdc"]["$i"]["vm"]
# pdc_final = result_ACDC_scopf_soft_w["final"]["solution"]["convdc"]["$i"]["pdc"]

# plot(f, 0.8, 1.2)
# scatter!([(vdc_base,pdc_base)], markershape = :cross, markersize = 10, markercolor = :red)
# scatter!([(vdc_final,pdc_final)], markershape = :cross, markersize = 10, markercolor = :blue)









