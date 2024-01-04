

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
data = _PM.parse_file(file)
PM_acdc_sc.fix_scopf_data_case67_acdc!(data)

#to test
for i=1:length(data["gen"])
    data["gen"]["$i"]["model"] = 2
    data["gen"]["$i"]["ncost"] = 2
    data["gen"]["$i"]["cost"] = [0.1, 25, 25, 45]
end

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
@time results = PM_acdc_sc.run_acdc_scopf_ptdf_dcdf_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_acdc_scopf_cuts, nlp_solver)
# data_SI = deepcopy(data)
# data_minlp = deepcopy(data)
# result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 
@time result_ACDC_scopf_soft_ndc = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 

@time result_ACDC_scopf_re_dispatch_oltc_pst = PM_acdc_sc.run_ACDC_scopf_re_dispatch(data, result_ACDC_scopf_soft, PM.ACPPowerModel, nlp_solver) 

