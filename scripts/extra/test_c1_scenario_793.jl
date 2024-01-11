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


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-3, "max_iter" => 5000)  # "print_level"=>0, "tol"=>1e-6, "max_iter" => 5000
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)


c1_ini_file = "./data/c1/inputfiles.ini"
c1_scenarios = "scenario_06"  #, "scenario_02"]
c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
data = build_c1_pm_model(c1_cases)


# for (i, bus) in data["bus"]
#     if bus["base_kv"] == 345
#     println("$i.........$(bus["base_kv"])...........$(bus["bus_type"])")
#     end
# end

# data["dcline"] = Dict{String, Any}()
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 1,"t_bus" => 3,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 2,"t_bus" => 3,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 1,"t_bus" => 5,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 4,"t_bus" => 6,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 4,"t_bus" => 5,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 4,"t_bus" => 7,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 5,"t_bus" => 7,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 6,"t_bus" => 7,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 2,"t_bus" => 6,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 8,"t_bus" => 9,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 8,"t_bus" => 10,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 3,"t_bus" => 10,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)
# data["dcline"]["1"] = Dict{String, Any}("f_bus" => 6,"t_bus" => 9,"status" => 2,"Pf" => 10,"Pt" =>8.9,"Qf" => 99.9934,"Qt" => -10.4049,"Vf" => 1.1,"Vt" => 1.05555,"Pmin" => 0,"Pmax" => 100,"QminF" =>-100,"QmaxF" =>100,"QminT" =>-100,"QmaxT" => 100,"loss0" => 0,"loss1" => 0)


# using PowerPlots
# powerplot(data, bus_size=80, gen_size=50, load_size=1, dcline_size=1, branch_size=1, connector_size=1, width=3000, height=3000)


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

# for i=1:length(data["shunt"])
#     if data["shunt"]["$i"]["dispatchable"] == true
#         delete!(data["shunt"], "$i")
#     end
# end 


data["dcpol"] = 2
data["busdc"]=Dict{String, Any}()
data["busdc"]["1"]=Dict{String, Any}("basekVdc" => 345, "source_id" => Any["busdc", 1], "Vdc" => 1, "busdc_i" => 1, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 1, "Pdc" => 0)
data["busdc"]["2"]=Dict{String, Any}("basekVdc" => 345, "source_id" => Any["busdc", 2], "Vdc" => 1, "busdc_i" => 2, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 2, "Pdc" => 0)
# data["busdc"]["3"]=Dict{String, Any}("basekVdc" => 345, "source_id" => Any["busdc", 3], "Vdc" => 1, "busdc_i" => 1, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 1, "Pdc" => 0)
# data["busdc"]["4"]=Dict{String, Any}("basekVdc" => 345, "source_id" => Any["busdc", 4], "Vdc" => 1, "busdc_i" => 2, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 2, "Pdc" => 0)

data["branchdc"]=Dict{String, Any}()
data["branchdc"]["1"]=Dict{String, Any}("c" => 0, "r" => 0.001, "status" => 1, "rateB" => 1575, "fbusdc" => 1, "source_id" => Any["branchdc", 1, 2, "R" ], "rateA" => 1575, "l" => 0, "index" => 1, "rateC" => 1575, "tbusdc" => 2)
# data["branchdc"]["2"]=Dict{String, Any}("c" => 0, "r" => 0.001, "status" => 1, "rateB" => 1575, "fbusdc" => 1, "source_id" => Any["branchdc", 1, 2, "R" ], "rateA" => 1575, "l" => 0, "index" => 1, "rateC" => 1575, "tbusdc" => 2)
data["convdc"]=Dict{String, Any}()
data["convdc"]["1"]=Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 95, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -2000, "Qacmax" => 1000, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
data["convdc"]["2"]=Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 21.9013, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 96, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -2000, "Qacmax" => 1000, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["3"]=Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 1533, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -2000, "Qacmax" => 1000, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["4"]=Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 21.9013, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 1545, "tm" => 1, "type_dc" => 3, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -2000, "Qacmax" => 1000, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)


# for (i,branch) in data["branch"]
#     branch["rate_a"] = min(branch["rate_a"], branch["rate_b"], branch["rate_c"])
#     branch["rate_c"] = max(branch["rate_a"], branch["rate_b"], branch["rate_c"])
# end

# data["dcpol"] = 2
# data["busdc"] = Dict{String, Any}()
# data["busdc"]["1"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 1], "area"=>1, "busdc_i"=>1, "grid"=>1, "index"=>1, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["2"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 2], "area"=>1, "busdc_i"=>2, "grid"=>1, "index"=>2, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["3"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 3], "area"=>1, "busdc_i"=>3, "grid"=>1, "index"=>3, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["4"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 4], "area"=>1, "busdc_i"=>4, "grid"=>1, "index"=>4, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["5"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 5], "area"=>1, "busdc_i"=>5, "grid"=>1, "index"=>5, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["6"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 6], "area"=>1, "busdc_i"=>6, "grid"=>1, "index"=>6, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["7"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 7], "area"=>1, "busdc_i"=>7, "grid"=>1, "index"=>7, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["8"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 8], "area"=>1, "busdc_i"=>8, "grid"=>1, "index"=>8, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["9"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 9], "area"=>1, "busdc_i"=>9, "grid"=>1, "index"=>9, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
# data["busdc"]["10"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 10], "area"=>1, "busdc_i"=>10, "grid"=>1, "index"=>10, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)


# data["branchdc"] = Dict{String, Any}()
# data["branchdc"]["1"] = Dict{String, Any}("c"=>0, "r"=>0.052,"status"=>1, "rateB"=>100, "fbusdc"=>1, "source_id"=>Any["branchdc", 1], "rateA"=>100, "l"=>0, "index"=>1, "rateC"=>110, "tbusdc" => 2) #3
# data["branchdc"]["2"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>2, "source_id"=>Any["branchdc", 2], "rateA"=>100, "l"=>0, "index"=>2, "rateC"=>110, "tbusdc" => 3)
# data["branchdc"]["3"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>1, "source_id"=>Any["branchdc", 3], "rateA"=>100, "l"=>0, "index"=>3, "rateC"=>110, "tbusdc" => 5)
# data["branchdc"]["4"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>2, "source_id"=>Any["branchdc", 4], "rateA"=>100, "l"=>0, "index"=>4, "rateC"=>110, "tbusdc" => 6)
# data["branchdc"]["5"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>4, "source_id"=>Any["branchdc", 5], "rateA"=>100, "l"=>0, "index"=>6, "rateC"=>110, "tbusdc" => 5)
# data["branchdc"]["6"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>4, "source_id"=>Any["branchdc", 6], "rateA"=>100, "l"=>0, "index"=>7, "rateC"=>110, "tbusdc" => 6)
# data["branchdc"]["7"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>4, "source_id"=>Any["branchdc", 7], "rateA"=>100, "l"=>0, "index"=>8, "rateC"=>110, "tbusdc" => 7)
# data["branchdc"]["8"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>5, "source_id"=>Any["branchdc", 8], "rateA"=>100, "l"=>0, "index"=>9, "rateC"=>110, "tbusdc" => 7)
# data["branchdc"]["9"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>6, "source_id"=>Any["branchdc", 9], "rateA"=>100, "l"=>0, "index"=>10, "rateC"=>110, "tbusdc" => 7)
# data["branchdc"]["10"] = Dict{String, Any}("c"=>0, "r"=>0.072, "status"=>1, "rateB"=>100, "fbusdc"=>8, "source_id"=>Any["branchdc", 10], "rateA"=>100, "l"=>0, "index"=>11, "rateC"=>110, "tbusdc" => 9)
# data["branchdc"]["11"] = Dict{String, Any}("c"=>0, "r"=>0.072, "status"=>1, "rateB"=>100, "fbusdc"=>8, "source_id"=>Any["branchdc", 11], "rateA"=>100, "l"=>0, "index"=>12, "rateC"=>110, "tbusdc" => 10)
# data["branchdc"]["12"] = Dict{String, Any}("c"=>0, "r"=>0.072, "status"=>1, "rateB"=>100, "fbusdc"=>3, "source_id"=>Any["branchdc", 12], "rateA"=>100, "l"=>0, "index"=>13, "rateC"=>110, "tbusdc" => 10)
# data["branchdc"]["13"] = Dict{String, Any}("c"=>0, "r"=>0.072, "status"=>1, "rateB"=>100, "fbusdc"=>6, "source_id"=>Any["branchdc", 13], "rateA"=>100, "l"=>0, "index"=>14, "rateC"=>110, "tbusdc" => 9)

# data["convdc"]=Dict{String, Any}()
# data["convdc"]["1"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 2, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["2"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 20, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 3, "tm" => 1, "type_dc" => 3, "Q_g" => -32.09, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -19.79, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["3"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -71.80176606605387, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 3], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 3, "busac_i" => 3, "tm" => 1, "type_dc" => 3, "Q_g" => -52.67, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 3, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -49.99, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["4"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -26.803780303012843, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 4], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 4, "busac_i" => 4, "tm" => 1, "type_dc" => 3, "Q_g" => -52.67, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 4, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -49.99, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["5"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -20.35929061609132, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 5], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 5, "busac_i" => 5, "tm" => 1, "type_dc" => 3, "Q_g" => -20.29, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 5, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -49.99, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["6"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -19.687343429031596, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 6], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 6, "busac_i" => 6, "tm" => 1, "type_dc" => 3, "Q_g" => -57.5, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 6, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -49.99, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["7"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 11.846242042946567, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 7], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 7, "busac_i" => 7, "tm" => 1, "type_dc" => 3, "Q_g" => -14.39, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 7, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -29.29, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["8"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 8], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 8, "busac_i" => 8, "tm" => 1, "type_dc" => 3, "Q_g" => -39.75, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 8, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -49.99, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["9"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 9], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 9, "busac_i" => 9, "tm" => 1, "type_dc" => 3, "Q_g" => -59.30, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 9, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -24.52, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
# data["convdc"]["10"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 10], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 10, "busac_i" => 10, "tm" => 1, "type_dc" => 3, "Q_g" => -50.13, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 10, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -10.08, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)



for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end

# for i=1:length(data["load"])
#     data["load"]["$i"]["pd"] = data["load"]["$i"]["pd"] * 0.8
#     data["load"]["$i"]["qd"] = data["load"]["$i"]["qd"] * 0.8
# end


PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 


# result_acdcopf = PM_acdc.run_acdcopf(data, PM.ACPPowerModel, nlp_solver, setting=setting)
# solution = result_acdcopf["solution"]
# PM.update_data!(data, solution)
# # update dc part
# for (i,conv) in data["convdc"]
#     conv["P_g"] = -solution["convdc"][i]["pgrid"]
#     conv["Q_g"] = solution["convdc"][i]["qgrid"]
#     if conv["type_dc"] == 2
#         conv["type_dc"] == 2
#     else
#         conv["type_dc"] == 1
#     end
#     conv["Pdcset"] = solution["convdc"][i]["pdc"]
# end

# for (i, branch) in data["branch"]
#     if haskey(solution["branch"], i)
#         branch["tap"] = solution["branch"][i]["tm"]
#         branch["shift"] = solution["branch"][i]["ta"]
#     end
# end
# for (i,conv) in result_acdcopf["solution"]["convdc"]
#     println("$i ......................pdc = $(conv["pdc"]*100)")
#     end
# for (i,busdc) in result_acdcopf["solution"]["busdc"]
#     println("$i ...................... vdc = $(busdc["vm"])")
#     end

# result_acdcpf = PM_acdc_sc.run_acdcpf_GM(data, PM.ACPPowerModel, nlp_solver, setting=setting)


# data_SI = deepcopy(data)
@time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 
# @time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations_SI, nlp_solver, setting) 

# for (i, convdc) in result_acdcopf["solution"]["convdc"]
#     println("$i .............................. pconv = $(convdc["pconv"]) ............. qconv = $(convdc["qconv"]).........................pdc = $(convdc["pdc"])\n")
# end