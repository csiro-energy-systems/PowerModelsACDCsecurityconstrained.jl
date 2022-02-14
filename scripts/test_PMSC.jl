using Pkg
Pkg.activate("./scripts")


using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained

nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6)
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
#lp_solver = optimizer_with_attributes(Cbc.Optimizer)



c1_ini_file = "./data/c1/inputfiles.ini"
c1_scenarios = "scenario_01"  #, "scenario_02"]
c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
c1_networks = build_c1_pm_model(c1_cases)

c1_networks["dcpol"] = 2
c1_networks["busdc"]=Dict{String, Any}()
c1_networks["busdc"]["1"]=Dict{String, Any}()
c1_networks["busdc"]["2"]=Dict{String, Any}()
c1_networks["busdc"]["1"]=Dict("basekVdc" => 345, "source_id" => Any["busdc", 1], "Vdc" => 1, "busdc_i" => 1, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 1, "Pdc" => 0)
c1_networks["busdc"]["2"]=Dict("basekVdc" => 345, "source_id" => Any["busdc", 2], "Vdc" => 1, "busdc_i" => 2, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 2, "Pdc" => 0)
c1_networks["dcline"]=Dict{String, Any}()
c1_networks["branchdc"]=Dict{String, Any}()
c1_networks["branchdc"]["1"]=Dict{String, Any}()
c1_networks["branchdc"]["1"]=Dict("c" => 0, "r" => 0.052, "status" => 1, "rateB" => 100, "fbusdc" => 1, "source_id" => Any["branchdc", 1], "rateA" => 100, "l" => 0, "index" => 1, "rateC" => 100, "tbusdc" => 2)
c1_networks["convdc"]=Dict{String, Any}()
c1_networks["convdc"]["1"]=Dict{String, Any}()
c1_networks["convdc"]["2"]=Dict{String, Any}()
c1_networks["convdc"]["1"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 2, "tm" => 1, "type_dc" => 1, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 50, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
c1_networks["convdc"]["2"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 21.9013, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 3, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.007, "Pacmin" => -100, "Qacmax" => 50, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
#c1_networks["settings"]=Dict{String, Any}()
#c1_networks["settings"] = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)            # Update_GM

# c1_networks["bus"]["15"]=Dict()
# c1_networks["bus"]["16"]=Dict()
# c1_networks["bus"]["15"]=deepcopy(c1_networks["bus"]["3"])
# c1_networks["bus"]["16"]=deepcopy(c1_networks["bus"]["3"])
# c1_networks["bus"]["15"]["bus_i"]=15
# c1_networks["bus"]["15"]["name"]="BUS-15"
# c1_networks["bus"]["15"]["source_id"][2]="15"
# c1_networks["bus"]["15"]["index"]=15


# c1_networks["bus"]["16"]["bus_i"]=16
# c1_networks["bus"]["16"]["name"]="BUS-16"
# c1_networks["bus"]["16"]["source_id"][2]="16"
# c1_networks["bus"]["16"]["index"]=16




# data=parse_file("./data/case5_tnep.m")
# dcline=data["dcline"]
# c1_networks["dcline"]=copy(dcline)
# c1_networks["dcline"]["1"]["f_bus"]=15
# c1_networks["dcline"]["1"]["t_bus"]=16

# data1=parse_file("./data/case5_acdc.m")
# convdc = data1["convdc"]["1"]
# c1_networks["convdc"]=Dict()
# c1_networks["convdc"]["1"]=Dict()
# c1_networks["convdc"]["1"]=deepcopy(convdc)
# c1_networks["convdc"]["2"]=Dict()
# c1_networks["convdc"]["2"]=deepcopy(convdc)
# c1_networks["convdc"]["1"]["busdc_i"]=15
# c1_networks["convdc"]["1"]["busac_i"]=13
# c1_networks["convdc"]["2"]["busdc_i"]=16
# c1_networks["convdc"]["2"]["busac_i"]=5
# c1_networks["convdc"]["2"]["index"]=2
# c1_networks["convdc"]["2"]["source_id"][2]=2

##
#PowerModelsACDC.process_additional_data!(c1_networks)
#s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)            settings=s
resultACDCSCOPF=PowerModelsACDCsecurityconstrained.run_c1_scopf_contigency_cuts_GM(c1_networks, PowerModels.DCPPowerModel, lp_solver)