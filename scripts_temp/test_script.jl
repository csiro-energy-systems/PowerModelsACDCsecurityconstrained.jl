
# To check and fix the issues in the pkg

using Ipopt
using Cbc
using Juniper
using JuMP
using HiGHS
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained


const _PM = PowerModels
const _PMACDC = PowerModelsACDC
const _PMSC = PowerModelsSecurityConstrained
const _PMSCACDC = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)  # "print_level"=>0, "tol"=>1e-6
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver, "print_level"=>0)


file = "./test/data/case5_acdc_scopf.m"
data = _PM.parse_file(file)
_PMSCACDC.fix_scopf_data_case5_acdc!(data)
_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 

data["gen_contingencies"] = []
data["branchdc_contingencies"] = []
data["convdc_contingencies"] = []
data["branch_contingencies"] = data["branch_contingencies"][1:3]

result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf, nlp_solver, nlp_solver, setting)
result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf_soft, nlp_solver, nlp_solver, setting)
result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf_soft_smooth, nlp_solver, nlp_solver, setting)
result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf_soft_minlp, minlp_solver, nlp_solver, setting)


# add loss distribution factors and total loss
data["ploss"] = 0 # sum(abs(branch["pf"] + branch["pt"]) for (b,branch) in data["branch"] if branch["br_status"] !=0)
load_total = sum(load["pd"] for (i,load) in data["load"] if load["status"] != 0)
data["ploss_df"] = Dict(bus["index"] => 0.0 for (i,bus) in data["bus"])
for (i, load) in data["load"]
    data["ploss_df"][load["load_bus"]] = load["pd"]/load_total
end

result = _PMSCACDC.run_scopf_acdc_cuts(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_acdc_scopf_cuts_soft, nlp_solver, nlp_solver, setting)




c1_ini_file = "./test/data/c1/inputfiles.ini"
c1_scenarios = "scenario_02"  #, "scenario_02"]
c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
data = build_c1_pm_model(c1_cases)

result = _PMSC.run_c1_scopf_contigency_cuts(data, _PM.ACPPowerModel,nlp_solver)






# results = PM_acdc_sc.run_acdc_scopf_ptdf_dcdf_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_acdc_scopf_cuts, nlp_solver)

# data_SI = deepcopy(data)
data_minlp = deepcopy(data)

result_ACDC_scopf_soft_ndc = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 

@time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations_SI, nlp_solver, setting) 

@time result_ACDC_scopf_soft_minlp = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data_minlp, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft_minlp, PM_acdc_sc.check_contingency_violations, minlp_solver, setting)

@time result_ACDC_scopf_re_dispatch_oltc_pst = PM_acdc_sc.run_ACDC_scopf_re_dispatch(data, result_ACDC_scopf_soft_ndc, PM.ACPPowerModel, nlp_solver)    