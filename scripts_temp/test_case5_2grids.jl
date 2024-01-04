

using Ipopt
using Cbc
using Juniper
using HiGHS
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained


const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "max_cpu_time" => 3600.0)  # "print_level"=>0, "tol"=>1e-6
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)


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

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end

data["gen"]["1"]["alpha"] = 15.92 
data["gen"]["2"]["alpha"] = 11.09 
data["gen"]["3"]["alpha"] = 15.92 
data["gen"]["4"]["alpha"] = 11.09

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

# data["branch"]["1"]["tm_min"] = 0.9; data["branch"]["1"]["tm_max"] = 1.1; 
# data["branch"]["2"]["tm_min"] = 0.9; data["branch"]["2"]["tm_max"] = 1.1; 
# data["branch"]["7"]["ta_min"] = -15.0; data["branch"]["7"]["ta_max"] = 15.0

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 
# data_SI = deepcopy(data)
# data_minlp = deepcopy(data)
# result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations_SI, nlp_solver, setting) 
@time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 

@time result_ACDC_scopf_re_dispatch_oltc_pst = PM_acdc_sc.run_ACDC_scopf_re_dispatch(data, result_ACDC_scopf_soft, PM.ACPPowerModel, nlp_solver) 