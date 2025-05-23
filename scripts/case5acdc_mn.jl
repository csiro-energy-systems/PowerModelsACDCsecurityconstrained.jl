using Pkg
Pkg.activate(".")


using Ipopt
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained


const _PM = PowerModels
const _PMACDC = PowerModelsACDC
const _PMSC = PowerModelsSecurityConstrained
const _PMSCACDC = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0) 

# without storage
file = "./test/data/matpower/case5_acdc_scopf.m"
# with storage
file = "./test/data/matpower/case5_acdc_scopf_strg.m"
data = _PM.parse_file(file)
_PMSCACDC.fix_scopf_data_case5_acdc!(data)
_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 

_PMSCACDC.silence()

data["hours"] = 1:6
data["time_interval"] = 1 # 1 = 1hr used for Ramp_Up_Rate and Ramp_Down_Rate constraints
data["gen_contingencies"] =[]
data["branch_contingencies"] = data["branch_contingencies"][1:2]
data["branchdc_contingencies"] = []
data["convdc_contingencies"] = []

for (i, gen) in data["gen"]
    gen["model"] = 1
    gen["ncost"] = 2
    gen["cost"] = [5, 100, 10, 200] 
    gen["Ramp_Up_Rate(MW/h)"] = 1.0
    gen["Ramp_Down_Rate(MW/h)"] = 1.0
end

# with storage: use case5_acdc_scopf_strg and update alpha for contingency response function
data["storage"]["1"]["alpha"] = 3.5
data["storage"]["2"]["alpha"] = 3.5

# updating gen 2 time_series, assuming it's a renewable generator for 2 steps
data["gen"]["2"]["gen_series"] = [0.8 0.9 0.9 0.95 1.0 1.1]

# updateing load 3 time_series for 2 steps
data["load"]["3"]["load_series"] = [0.9 0.95 0.95 0.98 1.0 1.1]

# similarly update time series for other renewable genrators and for their costs do it explicitly in script

# Creating multi-network data clustering time-steps (s1, ..., sn) and contingencies (c1, ..., cn)
# Format: [s1, c1 ... cn, s2, c1 ... cn, .... , sn, c1 ... cn]
mn_data = _PMSCACDC.build_mn_scopf_acdc_multinetwork(data)

# without storage: use case5_acdc_scopf
result = _PMSCACDC.run_mn_scopf_soft(mn_data, _PM.ACPPowerModel, nlp_solver, setting = setting)

# with storage: use case5_acdc_scopf_strg
result = _PMSCACDC.run_mn_scopf_strg_soft(mn_data, _PM.ACPPowerModel, nlp_solver, setting = setting)





