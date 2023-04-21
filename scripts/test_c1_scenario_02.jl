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


c1_ini_file = "./data/c1/inputfiles.ini"
c1_scenarios = "scenario_02"  #, "scenario_02"]
c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
data = build_c1_pm_model(c1_cases)

# PM_sc.correct_c1_solution!(data)
for (i, bus) in data["bus"]
    if bus["base_kv"] == 345
    println("$i.........$(bus["base_kv"])...........$(bus["bus_type"])")
    end
end
# for (i, branch) in data["branch"]
#     println("$i.........$(branch["rate_c"])")
# end

# data["branchdc_contingencies"] = []
# data["convdc_contingencies"] = []

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
data["busdc"] = Dict{String, Any}()
data["busdc"]["1"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 1], "area"=>1, "busdc_i"=>1, "grid"=>1, "index"=>1, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["2"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 2], "area"=>1, "busdc_i"=>2, "grid"=>1, "index"=>2, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["3"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 3], "area"=>1, "busdc_i"=>3, "grid"=>1, "index"=>3, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["4"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 4], "area"=>1, "busdc_i"=>4, "grid"=>1, "index"=>4, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["5"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 5], "area"=>1, "busdc_i"=>5, "grid"=>1, "index"=>5, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["6"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 6], "area"=>1, "busdc_i"=>6, "grid"=>1, "index"=>6, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["7"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 7], "area"=>1, "busdc_i"=>7, "grid"=>1, "index"=>7, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["8"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 8], "area"=>1, "busdc_i"=>8, "grid"=>1, "index"=>8, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["9"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 9], "area"=>1, "busdc_i"=>9, "grid"=>1, "index"=>9, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
data["busdc"]["10"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 10], "area"=>1, "busdc_i"=>10, "grid"=>1, "index"=>10, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)


data["branchdc"] = Dict{String, Any}()
data["branchdc"]["1"] = Dict{String, Any}("c"=>0, "r"=>0.052,"status"=>1, "rateB"=>100, "fbusdc"=>1, "source_id"=>Any["branchdc", 1], "rateA"=>100, "l"=>0, "index"=>1, "rateC"=>100, "tbusdc" => 2)
data["branchdc"]["2"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>2, "source_id"=>Any["branchdc", 2], "rateA"=>100, "l"=>0, "index"=>2, "rateC"=>100, "tbusdc" => 3)
data["branchdc"]["3"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>1, "source_id"=>Any["branchdc", 3], "rateA"=>100, "l"=>0, "index"=>3, "rateC"=>100, "tbusdc" => 4)
data["branchdc"]["4"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>2, "source_id"=>Any["branchdc", 4], "rateA"=>100, "l"=>0, "index"=>4, "rateC"=>100, "tbusdc" => 4)
data["branchdc"]["5"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>2, "source_id"=>Any["branchdc", 5], "rateA"=>100, "l"=>0, "index"=>5, "rateC"=>100, "tbusdc" => 4)
data["branchdc"]["6"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>1, "source_id"=>Any["branchdc", 6], "rateA"=>100, "l"=>0, "index"=>6, "rateC"=>100, "tbusdc" => 5)
data["branchdc"]["7"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>5, "source_id"=>Any["branchdc", 7], "rateA"=>100, "l"=>0, "index"=>7, "rateC"=>100, "tbusdc" => 6)
data["branchdc"]["8"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>5, "source_id"=>Any["branchdc", 8], "rateA"=>100, "l"=>0, "index"=>8, "rateC"=>100, "tbusdc" => 7)
data["branchdc"]["9"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>7, "source_id"=>Any["branchdc", 9], "rateA"=>100, "l"=>0, "index"=>9, "rateC"=>100, "tbusdc" => 4)
data["branchdc"]["10"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>4, "source_id"=>Any["branchdc", 10], "rateA"=>100, "l"=>0, "index"=>10, "rateC"=>100, "tbusdc" => 8)
data["branchdc"]["11"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>8, "source_id"=>Any["branchdc", 11], "rateA"=>100, "l"=>0, "index"=>11, "rateC"=>100, "tbusdc" => 9)
data["branchdc"]["12"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>8, "source_id"=>Any["branchdc", 12], "rateA"=>100, "l"=>0, "index"=>12, "rateC"=>100, "tbusdc" => 10)
data["branchdc"]["13"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>3, "source_id"=>Any["branchdc", 13], "rateA"=>100, "l"=>0, "index"=>13, "rateC"=>100, "tbusdc" => 10)
data["branchdc"]["14"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>6, "source_id"=>Any["branchdc", 14], "rateA"=>100, "l"=>0, "index"=>14, "rateC"=>100, "tbusdc" => 9)

data["convdc"]=Dict{String, Any}()
data["convdc"]["1"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 7, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["2"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 14, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["3"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 3], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 3, "busac_i" => 23, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 3, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["4"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 4], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 4, "busac_i" => 39, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 4, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["5"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 5], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 5, "busac_i" => 57, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 5, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["6"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 6], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 6, "busac_i" => 65, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 6, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["7"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 7], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 7, "busac_i" => 80, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 7, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["8"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 8], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 8, "busac_i" => 123, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 8, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["9"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 9], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 9, "busac_i" => 146, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 9, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["10"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 10], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 10, "busac_i" => 151, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 10, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)


for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end

data["branchdc_contingencies"] = Vector{Any}(undef, 14)
data["branchdc_contingencies"][1] = (idx = 1, label = "branchdc_1", type = "branchdc")
data["branchdc_contingencies"][2] = (idx = 1, label = "branchdc_2", type = "branchdc")
data["branchdc_contingencies"][3] = (idx = 1, label = "branchdc_3", type = "branchdc")
data["branchdc_contingencies"][4] = (idx = 1, label = "branchdc_4", type = "branchdc")
data["branchdc_contingencies"][5] = (idx = 1, label = "branchdc_5", type = "branchdc")
data["branchdc_contingencies"][6] = (idx = 1, label = "branchdc_6", type = "branchdc")
data["branchdc_contingencies"][7] = (idx = 1, label = "branchdc_7", type = "branchdc")
data["branchdc_contingencies"][8] = (idx = 1, label = "branchdc_8", type = "branchdc")
data["branchdc_contingencies"][9] = (idx = 1, label = "branchdc_9", type = "branchdc")
data["branchdc_contingencies"][10] = (idx = 1, label = "branchdc_10", type = "branchdc")
data["branchdc_contingencies"][11] = (idx = 1, label = "branchdc_11", type = "branchdc")
data["branchdc_contingencies"][12] = (idx = 1, label = "branchdc_12", type = "branchdc")
data["branchdc_contingencies"][13] = (idx = 1, label = "branchdc_13", type = "branchdc")
data["branchdc_contingencies"][14] = (idx = 1, label = "branchdc_14", type = "branchdc")

data["convdc_contingencies"] = Vector{Any}(undef, 10)
data["convdc_contingencies"][1] = (idx = 1, label = "Conv_1", type = "convdc")
data["convdc_contingencies"][2] = (idx = 2, label = "Conv_2", type = "convdc")
data["convdc_contingencies"][3] = (idx = 3, label = "Conv_3", type = "convdc")
data["convdc_contingencies"][4] = (idx = 4, label = "Conv_4", type = "convdc")
data["convdc_contingencies"][5] = (idx = 5, label = "Conv_5", type = "convdc")
data["convdc_contingencies"][6] = (idx = 6, label = "Conv_6", type = "convdc")
data["convdc_contingencies"][7] = (idx = 7, label = "Conv_7", type = "convdc")
data["convdc_contingencies"][8] = (idx = 8, label = "Conv_8", type = "convdc")
data["convdc_contingencies"][9] = (idx = 9, label = "Conv_9", type = "convdc")
data["convdc_contingencies"][10] = (idx = 10, label = "Conv_10", type = "convdc")



PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 

# data_SI = deepcopy(data)
# result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 
@time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 

@time result_ACDC_scopf_re_dispatch_oltc_pst = PM_acdc_sc.run_ACDC_scopf_re_dispatch(data, result_ACDC_scopf_soft, PM.ACPPowerModel, nlp_solver) 

using Plots
scatter([branch["pf"] for (i, branch) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["branch"]])
scatter!([branchdc["pf"] for (i, branchdc) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["branchdc"]])