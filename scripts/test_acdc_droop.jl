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


file = "./data/case5_acdc_scopf.m"
data = parse_file(file)
# result_acopf = PM.run_opf( data, PM.ACPPowerModel, nlp_solver; setting = setting)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
end

PM_acdc.process_additional_data!(data)

setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

##
resultpf = PM_acdc.run_acdcpf( data, PM.ACPPowerModel, nlp_solver; setting = setting)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

resultopf = PM_acdc.run_acdcopf( data, PM.ACPPowerModel, nlp_solver; setting = setting)
for i=1:length(data["convdc"])
    data["convdc"]["$i"]["Pdcset"] = resultpf_droop["solution"]["convdc"]["$i"]["pdc"]
end
result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)

##
i= 7
pref_dc = data["convdc"]["$i"]["Pdcset"]
vdcmax = data["convdc"]["$i"]["Vmmax"]
vdcmin = data["convdc"]["$i"]["Vmmin"]
vdchigh = data["convdc"]["$i"]["Vdchigh"]
vdclow = data["convdc"]["$i"]["Vdclow"]
k_droop = data["convdc"]["$i"]["droop"]
ep = data["convdc"]["$i"]["ep"]
epsilon = 1E-12

ep =0.1
f(vdc) = pref_dc +( (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))
-(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep))
+((1 / k_droop * (vdclow - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc)) - (vdc - (vdclow - epsilon)) * (vdc - (vdcmin + epsilon)))/ep)))
-((1 / k_droop * (vdclow - vdc + vdcmin - vdclow)) + ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc + vdcmin - vdclow)) - (vdc - vdcmin + vdclow - (vdclow - epsilon)) * (vdc - vdcmin + vdclow - (vdcmin + epsilon)))/ep))) )

plot(f, 0.8, 1.2)

vdc = resultpf_droop["solution"]["busdc"]["$i"]["vm"]
pdc = resultpf_droop["solution"]["convdc"]["$i"]["pdc"]

vdc1 = resultpf["solution"]["busdc"]["$i"]["vm"]
pdc1 = resultpf["solution"]["convdc"]["$i"]["pdc"]

scatter!([(vdc,pdc)], markershape = :cross, markersize = 10, markercolor = :red)

scatter!([(vdc1,pdc1)], markershape = :cross, markersize = 10, markercolor = :blue)