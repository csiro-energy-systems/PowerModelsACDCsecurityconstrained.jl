


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


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0) 
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)


file = "./test/data/matpower/case5_acdc_scopf.m"
data = _PM.parse_file(file)
_PMSCACDC.fix_scopf_data_case5_acdc!(data)
_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 

_PMSCACDC.silence()

result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf, nlp_solver, nlp_solver, setting)
result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf_soft, nlp_solver, nlp_solver, setting)
result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf_soft_smooth, nlp_solver, nlp_solver, setting)
result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf_soft_minlp, minlp_solver, nlp_solver, setting)


_PM.update_data!(data, result["final"]["solution"]["nw"]["0"])
_PMSCACDC.add_losses_and_loss_distribution_factors!(data)  

result = _PMSCACDC.run_scopf_acdc_cuts(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_acdc_scopf_cuts, nlp_solver, nlp_solver, setting)
result = _PMSCACDC.run_scopf_acdc_cuts(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_acdc_scopf_cuts_soft, nlp_solver, nlp_solver, setting)



