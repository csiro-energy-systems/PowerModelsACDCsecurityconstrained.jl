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


const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "max_cpu_time" => 3600.0)  # "print_level"=>0, "tol"=>1e-6
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)


##

file = "./data/case67_acdc_scopf.m"
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

#data["branchdc_contingencies"] = []
data["gen_contingencies"] = []

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([8, 7, 6, 5, 4, 3, 2, 1])
data["area_gens"][2] = Set([14, 13, 12, 11, 10, 9])
data["area_gens"][3] = Set([19, 18, 17, 16, 15])
data["area_gens"][4] = Set([20])

data["contingencies"] = []  # This to empty the existing contingencies in the data

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

for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
end

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end

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


PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
# data_SI = deepcopy(data)
# data_minlp = deepcopy(data)
# result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 
@time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 

@time result_ACDC_scopf_re_dispatch_oltc_pst = PM_acdc_sc.run_ACDC_scopf_re_dispatch(data, result_ACDC_scopf_soft, PM.ACPPowerModel, nlp_solver) 

