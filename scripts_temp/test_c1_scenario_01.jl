#Pkg.develop(PackageSpec(path = "/Users/moh050/OneDrive - CSIRO/Documents/GitHub/ChargingStationOpt"))
# using Pkg
# Pkg.activate("./scripts")

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


c1_ini_file = "./test/data/c1/inputfiles.ini"
c1_scenarios = "scenario_02"  #, "scenario_02"]
c1_cases = _PMSC.parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
data = build_c1_pm_model(c1_cases)


data["branchdc_contingencies"] = []
data["convdc_contingencies"] = []

data["contingencies"] = []  # This to empty the existing contingencies in the data
data["dcline"]=Dict{String, Any}()

for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
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

# for (i,branch) in data["branch"]
#     branch["rate_a"] = min(branch["rate_a"], branch["rate_b"], branch["rate_c"])
#     branch["rate_c"] = max(branch["rate_a"], branch["rate_b"], branch["rate_c"])
# end

data["dcpol"] = 2
data["busdc"]=Dict{String, Any}()
data["busdc"]["1"]=Dict{String, Any}()
data["busdc"]["2"]=Dict{String, Any}()
data["busdc"]["1"]=Dict("basekVdc" => 345, "source_id" => Any["busdc", 1], "Vdc" => 1, "busdc_i" => 1, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 1, "Pdc" => 0)
data["busdc"]["2"]=Dict("basekVdc" => 345, "source_id" => Any["busdc", 2], "Vdc" => 1, "busdc_i" => 2, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 2, "Pdc" => 0)

data["branchdc"]=Dict{String, Any}()
data["branchdc"]["1"]=Dict{String, Any}()
data["branchdc"]["1"]=Dict("c" => 0, "r" => 0.052, "status" => 1, "rateB" => 100, "fbusdc" => 1, "source_id" => Any["branchdc", 1, 2, "R" ], "rateA" => 100, "l" => 0, "index" => 1, "rateC" => 100, "tbusdc" => 2)
data["convdc"]=Dict{String, Any}()
data["convdc"]["1"]=Dict{String, Any}()
data["convdc"]["2"]=Dict{String, Any}()
data["convdc"]["1"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 2, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 50, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["2"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 21.9013, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 3, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 50, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end

#data["branchdc_contingencies"]=Vector{Any}(undef, 1)
#data["branchdc_contingencies"][1]=(idx = 1, label = "LINE-1-2-R", type = "branchdc")
#data["branch_contingencies"]=Vector{Any}(undef, 3)
#data["branch_contingencies"][1]=(idx = 7, label = "LINE-4-5-BL", type = "branch")
#data["branch_contingencies"][2]=(idx = 9, label = "LINE-6-12-BL", type = "branch")
#data["branch_contingencies"][3]=(idx = 10, label = "LINE-6-13-BL", type = "branch")


#data["branch_contingencies"][4]=(idx = 6, label = "LINE-3-4-BL", type = "branch")
#data["branch_contingencies"][5]=(idx = 1, label = "LINE-1-2-BL", type = "branch")
#data["branch_contingencies"][6]=(idx = 2, label = "LINE-1-5-BL", type = "branch")
#data["branch_contingencies"][7]=(idx = 3, label = "LINE-2-3-BL", type = "branch")
#data["branch_contingencies"][8]=(idx = 4, label = "LINE-2-4-BL", type = "branch")
#data["branch_contingencies"][9]=(idx = 5, label = "LINE-2-5-BL", type = "branch")
#data["branch_contingencies"][10]=(idx = 8, label = "LINE-6-11-BL", type = "branch")
#data["branch_contingencies"][11]=(idx = 11, label = "LINE-7-8-BL", type = "branch")

#data["gen_contingencies"]=Vector{Any}(undef, 2)
#data["gen_contingencies"][1]=(idx = 3, label = "GEN-3-1", type = "gen")
#data["gen_contingencies"][2]=(idx = 1, label = "GEN-1-1", type = "gen")
#data["gen_contingencies"][3]=(idx = 2, label = "GEN-2-1", type = "gen")

data["slack"] = Dict{String, Any}()
data["slack"]["1"] = Dict{String, Any}()
data["slack"]["1"]["cost"] = [0, 1000, 0.01, 5E5, 0.1, 5E7, 10, 5E15]
data["slack"]["1"]["ncost"] = 4


PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 
# data_SI = deepcopy(data)
# result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 
result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations_SI, nlp_solver, setting) 






