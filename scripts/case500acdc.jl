

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


c1_ini_file = "./test/data/c1/inputfiles.ini"
c1_scenarios = "scenario_02" 
c1_cases = _PMSC.parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
data = _PMSC.build_c1_pm_model(c1_cases)
_PMSCACDC.fix_scopf_data_case500_acdc!(data)
_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 


_PMSCACDC.silence()

result = _PMSCACDC.run_scopf_acdc_contingencies(data, _PM.ACPPowerModel, _PM.ACPPowerModel, _PMSCACDC.run_scopf_soft, nlp_solver, nlp_solver, setting)