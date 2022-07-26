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


file = "./data/nem_2300bus.m"
network = parse_file(file)

network["dcline"]=Dict{String, Any}()
network["dcpol"] = 2
network["busdc"]=Dict{String, Any}()
#network["busdc"]["1"]=Dict{String, Any}()
#network["busdc"]["2"]=Dict{String, Any}()
#network["busdc"]["1"]=Dict("basekVdc" => 345, "source_id" => Any["busdc", 1], "Vdc" => 1, "busdc_i" => 1, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 1, "Pdc" => 0)
#network["busdc"]["2"]=Dict("basekVdc" => 345, "source_id" => Any["busdc", 2], "Vdc" => 1, "busdc_i" => 2, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 2, "Pdc" => 0)
network["branchdc"]=Dict{String, Any}()
#network["branchdc"]["1"]=Dict{String, Any}()
#network["branchdc"]["1"]=Dict("c" => 0, "r" => 0.052, "status" => 1, "rateB" => 100, "fbusdc" => 1, "source_id" => Any["branchdc", 1, 2, "R" ], "rateA" => 100, "l" => 0, "index" => 1, "rateC" => 100, "tbusdc" => 2)
network["convdc"]=Dict{String, Any}()
#network["convdc"]["1"]=Dict{String, Any}()
#network["convdc"]["2"]=Dict{String, Any}()
#network["convdc"]["1"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 2, "tm" => 1, "type_dc" => 1, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 50, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
#network["convdc"]["2"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 21.9013, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 3, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.007, "Pacmin" => -100, "Qacmax" => 50, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)

network["branchdc_contingencies"]=Vector{Any}(undef, 1)
#network["branchdc_contingencies"][1]=(idx = 1, label = "LINE-1-2-R", type = "branchdc")

network["branch_contingencies"]=Vector{Any}(undef, 11)
#network["branch_contingencies"][1]=(idx = 7, label = "LINE-4-5-BL", type = "branch")

network["gen_contingencies"]=Vector{Any}(undef, 3)
#network["gen_contingencies"][1]=(idx = 3, label = "GEN-3-1", type = "gen")

for i=1:length(network["gen"])
    network["gen"]["$i"]["model"] = 1
    #network["gen"]["$i"]["pg"] = 0
    #network["gen"]["$i"]["qg"] = 0
    #network["gen"]["$i"]["pmin"] = 0
    #network["gen"]["$i"]["qmin"] = -network["gen"]["$i"]["qmax"]
    network["gen"]["$i"]["ncost"] = 2
    network["gen"]["$i"]["cost"] = [1000, 10, 1, 0]     #[0.114610934721, 148.906997825, 0.224657803731, 203.163028589, 0.33470467274, 257.869865285, 0.44475154175, 313.027507911, 0.5547984107589999, 368.635956469, 0.664845279769, 424.695210957, 0.774892148778, 481.205271377, 0.884939017788, 538.166137728, 0.9949858867970001, 595.57781001, 1.10503275581, 653.440288223]
    #network["gen"]["$i"]["alpha"] = 1
end



PowerModelsACDC.process_additional_data!(network)
resultACDCSCOPF2=PowerModelsACDCsecurityconstrained.run_scopf_contigency_cuts(network, PowerModels.ACPPowerModel, nlp_solver)