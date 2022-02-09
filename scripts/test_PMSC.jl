using Pkg
Pkg.activate("./scripts")


using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained

nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6)
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
#lp_solver = optimizer_with_attributes(Cbc.Optimizer)



c1_ini_file = "./data/c1/inputfiles.ini"
c1_scenarios = "scenario_01"  #, "scenario_02"]
c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
c1_networks = build_c1_pm_model(c1_cases)

c1_networks["bus"]["15"]=Dict()
c1_networks["bus"]["16"]=Dict()
c1_networks["bus"]["15"]=deepcopy(c1_networks["bus"]["3"])
c1_networks["bus"]["16"]=deepcopy(c1_networks["bus"]["3"])
c1_networks["bus"]["15"]["bus_i"]=15
c1_networks["bus"]["15"]["name"]="BUS-15"
c1_networks["bus"]["15"]["source_id"][2]="15"
c1_networks["bus"]["15"]["index"]=15

c1_networks["bus"]["16"]["bus_i"]=16
c1_networks["bus"]["16"]["name"]="BUS-16"
c1_networks["bus"]["16"]["source_id"][2]="16"
c1_networks["bus"]["16"]["index"]=16




data=parse_file("./data/case5_tnep.m")
dcline=data["dcline"]
c1_networks["dcline"]=copy(dcline)
c1_networks["dcline"]["1"]["f_bus"]=15
c1_networks["dcline"]["1"]["t_bus"]=16

data1=parse_file("./data/case5_acdc.m")
convdc = data1["convdc"]["1"]
c1_networks["convdc"]=Dict()
c1_networks["convdc"]["1"]=Dict()
c1_networks["convdc"]["1"]=deepcopy(convdc)
c1_networks["convdc"]["2"]=Dict()
c1_networks["convdc"]["2"]=deepcopy(convdc)
c1_networks["convdc"]["1"]["busdc_i"]=15
c1_networks["convdc"]["1"]["busac_i"]=13
c1_networks["convdc"]["2"]["busdc_i"]=16
c1_networks["convdc"]["2"]["busac_i"]=5
c1_networks["convdc"]["2"]["index"]=2
c1_networks["convdc"]["2"]["source_id"][2]=2

##

PowerModelsACDCsecurityconstrained.run_c1_scopf_contigency_cuts_GM(c1_networks, PowerModels.DCPPowerModel, lp_solver)