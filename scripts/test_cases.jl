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

const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-6)  
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)

########################################### case5_acdc_scopf.m ##########################################
file = "./data/case5_acdc_scopf.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
end

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)
result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

######################################### case5_2grids_acdc_sc.m #########################################
file = "./data/case5_2grids_acdc_sc.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  


PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)
result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

######################################### case5_lcc_acdc_sc.m #########################################
file = "./data/case5_lcc_acdc_sc.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  


PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)
result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

########################################### case5_dcgrid_sc.m ###########################################
file = "./data/case5_dcgrid_sc.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  


PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)
result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

############################################# case5_b2bdc_sc.m #############################################
file = "./data/case5_b2bdc_sc.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  

PM_acdc.process_additional_data!(data)
data["busdc"]["1"]["Pdc"] = 1
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)
result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

############################################# case24_3zones_acdc_sc.m #############################################

file = "./data/case24_3zones_acdc_sc.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 0.1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

############################################# case39_acdc_sc.m #############################################
file = "./data/case39_acdc_sc.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 0.1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

############################################# pglib_opf_case588_sdet_acdc_sc.m #############################################
file = "./data/pglib_opf_case588_sdet_acdc_sc.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 0.1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

############################################# case3120sp_acdc_sc.m #############################################
file = "./data/case3120sp_acdc_sc.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 0.1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

############################################# case67_acdc_scopf.m #############################################
file = "./data/case67_acdc_scopf.m"
data = parse_file(file)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 0.1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end  

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

############################################# casexxxxxxxxxxxxxxxxxx.m #############################################

resultpf = PM_acdc.run_acdcpf( data, PM.ACPPowerModel, nlp_solver; setting = setting)
resultopf = PM_acdc.run_acdcopf( data, PM.ACPPowerModel, nlp_solver; setting = setting)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

resultopf = PM_acdc.run_acdcopf( data, PM.ACPPowerModel, nlp_solver; setting = setting)
for i=1:length(data["convdc"])
    data["convdc"]["$i"]["Pdcset"] = resultpf_droop["solution"]["convdc"]["$i"]["pdc"]
end
result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)