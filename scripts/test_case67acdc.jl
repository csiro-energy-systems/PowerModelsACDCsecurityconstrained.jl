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

file = "./data/case67acdc_scopf.m"
data = parse_file(file)

#for i=1:length(data["contingencies"])
#    if data["contingencies"]["$i"]["branch_id1"] == 0 && data["contingencies"]["$i"]["dcbranch_id1"] == 0 && data["contingencies"]["$i"]["gen_id1"] == 0
#    delete!(data["contingencies"], "$i")
#    end
#end


branch_counter_ac = 0
branch_counter_dc = 0
gen_counter = 0
idx_ac = zeros(Int64, length(data["contingencies"]))
label_ac = zeros(Int64, length(data["contingencies"]))
idx_dc = zeros(Int64, length(data["contingencies"]))
label_dc = zeros(Int64, length(data["contingencies"]))
idx_gen = zeros(Int64, length(data["contingencies"]))
label_gen = zeros(Int64, length(data["contingencies"]))

for i=1:length(data["contingencies"])
    if data["contingencies"]["$i"]["dcbranch_id1"] == 0 && data["contingencies"]["$i"]["branch_id1"] != 0
        
        idx_ac[i] = data["contingencies"]["$i"]["branch_id1"]
        label_ac[i] = data["contingencies"]["$i"]["source_id"][2]

        idx_dc[i] = 0
        label_dc[i] = 0
        idx_gen[i] = 0
        label_gen[i] = 0

        # branch_counter_ac += 1
    elseif data["contingencies"]["$i"]["branch_id1"] == 0 && data["contingencies"]["$i"]["dcbranch_id1"] != 0
        idx_dc[i] = data["contingencies"]["$i"]["dcbranch_id1"]
        label_dc[i] = data["contingencies"]["$i"]["source_id"][2]

        idx_ac[i] = 0
        label_ac[i] = 0
        idx_gen[i] = 0
        label_gen[i] = 0

        # branch_counter_dc += 1

    elseif data["contingencies"]["$i"]["branch_id1"] == 0 && data["contingencies"]["$i"]["dcbranch_id1"] == 0 && data["contingencies"]["$i"]["gen_id1"] != 0
        idx_gen[i] = data["contingencies"]["$i"]["gen_id1"]
        label_gen[i] = data["contingencies"]["$i"]["source_id"][2]

        idx_ac[i] = 0
        label_ac[i] = 0
        idx_dc[i] = 0
        label_dc[i] = 0

        # gen_counter += 1

    end
end
branch_counter_ac = 11
branch_counter_dc = 2
gen_counter = 0
data["branch_contingencies"]=Vector{Any}(undef, branch_counter_ac)
data["branchdc_contingencies"]=Vector{Any}(undef, branch_counter_dc)
data["gen_contingencies"] = Vector{Any}(undef, gen_counter)


for i=1:branch_counter_ac
    data["branch_contingencies"][i] = (idx = idx_ac[i], label = string(label_ac[i]), type = "branch")
end
for i = 1:branch_counter_dc
    data["branchdc_contingencies"][i] = (idx = idx_dc[i+branch_counter_ac], label = string(label_dc[i+branch_counter_ac]), type = "branchdc")
end
for i = 1:gen_counter
    data["gen_contingencies"][i] = (idx = idx_gen[i+branch_counter_ac+branch_counter_dc], label = string(label_gen[i+branch_counter_ac+branch_counter_dc]), type = "gen")
end


#for i=1:length(data["gen"])
#    data["gen"]["$i"]["ncost"] = 1
#end
#data["branch_contingencies"]= []
#data["branchdc_contingencies"] = []
for i=1:length(data["gen"])
    data["gen"]["$i"]["model"] = 1
    data["gen"]["$i"]["pg"] = 0
    data["gen"]["$i"]["qg"] = 0
    data["gen"]["$i"]["pmin"] = 0
    data["gen"]["$i"]["qmin"] = -data["gen"]["$i"]["qmax"]
    data["gen"]["$i"]["ncost"] = 10
    data["gen"]["$i"]["cost"] = [0.114610934721, 148.906997825, 0.224657803731, 203.163028589, 0.33470467274, 257.869865285, 0.44475154175, 313.027507911, 0.5547984107589999, 368.635956469, 0.664845279769, 424.695210957, 0.774892148778, 481.205271377, 0.884939017788, 538.166137728, 0.9949858867970001, 595.57781001, 1.10503275581, 653.440288223]
end
data["contingencies"] = []
#data["gen"]["1"]["cost"] = [0.37965, 9706.86, 0.610183, 17694.8]
#data["gen"]["2"]["cost"] = [0.0, 0.0, 0.0, 0.0]
#data["gen"]["3"]["cost"] = [0.0580178826582, 3409.77768201, 0.143237964633, 4639.70192051]
#data["gen"]["4"]["cost"] = [0.0, 0.0, 0.0, 0.0]

#data["gen"]["5"]["cost"] = [0.0031982867047199996, 295.865088134, 0.091892677618, 1913.60850411]
#data["gen"]["6"]["cost"] = [0.114610934721, 148.906997825, 0.224657803731, 203.163028589]
#data["gen"]["7"]["cost"] = [0.37965, 9706.86, 0.610183, 17694.8]
#data["gen"]["8"]["cost"] = [0.481482663648, 353.162814895, 0.6029874303430001, 435.023619633]
#data["gen"]["9"]["cost"] = [0.0580178826582, 3409.77768201, 0.143237964633, 4639.70192051]
#data["gen"]["10"]["cost"] = [0.114610934721, 148.906997825, 0.224657803731, 203.163028589]
#data["gen"]["11"]["cost"] = [0.0031982867047199996, 295.865088134, 0.091892677618, 1913.60850411]
#data["gen"]["12"]["cost"] = [0.114610934721, 148.906997825, 0.224657803731, 203.163028589]
#data["gen"]["13"]["cost"] = [0.0580178826582, 3409.77768201, 0.143237964633, 4639.70192051]
#data["gen"]["14"]["cost"] = [0.114610934721, 148.906997825, 0.224657803731, 203.163028589]
#data["gen"]["15"]["cost"] = [0.0031982867047199996, 295.865088134, 0.091892677618, 1913.60850411]
#data["gen"]["16"]["cost"] = [0.114610934721, 148.906997825, 0.224657803731, 203.163028589]
#data["gen"]["17"]["cost"] = [0.37965, 9706.86, 0.610183, 17694.8]
#data["gen"]["18"]["cost"] = [0.481482663648, 353.162814895, 0.6029874303430001, 435.023619633]
#data["gen"]["19"]["cost"] = [0.0580178826582, 3409.77768201, 0.143237964633, 4639.70192051]
#data["gen"]["20"]["cost"] = [0.0, 0.0, 0.0, 0.0]
#data["conv_cost"] = []

##
#c1_networks["dcpol"] = 2
#c1_networks["busdc"]=Dict{String, Any}()
#c1_networks["busdc"]["1"]=Dict{String, Any}()
#c1_networks["busdc"]["2"]=Dict{String, Any}()
#c1_networks["busdc"]["1"]=Dict("basekVdc" => 345, "source_id" => Any["busdc", 1], "Vdc" => 1, "busdc_i" => 1, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 1, "Pdc" => 0)
#c1_networks["busdc"]["2"]=Dict("basekVdc" => 345, "source_id" => Any["busdc", 2], "Vdc" => 1, "busdc_i" => 2, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 2, "Pdc" => 0)
#c1_networks["dcline"]=Dict{String, Any}()
#c1_networks["branchdc"]=Dict{String, Any}()
#c1_networks["branchdc"]["1"]=Dict{String, Any}()
#c1_networks["branchdc"]["1"]=Dict("c" => 0, "r" => 0.052, "status" => 1, "rateB" => 100, "fbusdc" => 1, "source_id" => Any["branchdc", 1, 2, "R" ], "rateA" => 100, "l" => 0, "index" => 1, "rateC" => 100, "tbusdc" => 2)
#c1_networks["convdc"]=Dict{String, Any}()
#c1_networks["convdc"]["1"]=Dict{String, Any}()
#c1_networks["convdc"]["2"]=Dict{String, Any}()
#c1_networks["convdc"]["1"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 2, "tm" => 1, "type_dc" => 1, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 50, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
#c1_networks["convdc"]["2"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 21.9013, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 3, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.007, "Pacmin" => -100, "Qacmax" => 50, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)

#c1_networks["branchdc_contingencies"]=Vector{Any}(undef, 1)
#c1_networks["branchdc_contingencies"][1]=(idx = 1, label = "LINE-1-2-R", type = "branchdc")
#c1_networks["branch_contingencies"]=Vector{Any}(undef, 11)
#c1_networks["branch_contingencies"][1]=(idx = 7, label = "LINE-4-5-BL", type = "branch")
#c1_networks["branch_contingencies"][2]=(idx = 9, label = "LINE-6-12-BL", type = "branch")
#c1_networks["branch_contingencies"][3]=(idx = 10, label = "LINE-6-13-BL", type = "branch")
#c1_networks["branch_contingencies"][4]=(idx = 6, label = "LINE-3-4-BL", type = "branch")
#c1_networks["branch_contingencies"][5]=(idx = 1, label = "LINE-1-2-BL", type = "branch")
#c1_networks["branch_contingencies"][6]=(idx = 2, label = "LINE-1-5-BL", type = "branch")
#c1_networks["branch_contingencies"][7]=(idx = 3, label = "LINE-2-3-BL", type = "branch")
#c1_networks["branch_contingencies"][8]=(idx = 4, label = "LINE-2-4-BL", type = "branch")
#c1_networks["branch_contingencies"][9]=(idx = 5, label = "LINE-2-5-BL", type = "branch")
#c1_networks["branch_contingencies"][10]=(idx = 8, label = "LINE-6-11-BL", type = "branch")
#c1_networks["branch_contingencies"][11]=(idx = 11, label = "LINE-7-8-BL", type = "branch")

#c1_networks["gen_contingencies"]=Vector{Any}(undef, 3)
#c1_networks["gen_contingencies"][1]=(idx = 3, label = "GEN-3-1", type = "gen")
#c1_networks["gen_contingencies"][2]=(idx = 1, label = "GEN-1-1", type = "gen")
#c1_networks["gen_contingencies"][3]=(idx = 2, label = "GEN-2-1", type = "gen")

##



#PowerModelsACDC.process_additional_data!(c1_networks)
#s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)            settings=s

#resultACDCSCOPF1=PowerModelsACDCsecurityconstrained.run_c1_scopf_contigency_cuts_GM(c1_networks, PowerModels.DCPPowerModel, lp_solver)
PowerModelsACDC.process_additional_data!(data)
resultACDCSCOPF2=PowerModelsACDCsecurityconstrained.run_c1_scopf_contigency_cuts_GM(data, PowerModels.ACPPowerModel, nlp_solver)


    