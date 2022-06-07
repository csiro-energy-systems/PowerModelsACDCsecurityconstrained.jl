using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained
using Plots

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
data["area_gens"]=Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([4, 3, 2, 1])




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
    data["gen"]["$i"]["alpha"] = 1
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

############################################# Base Case Plots ################################################

vm_ac_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["bus"]))
va_ac_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["bus"]))
vm_dc_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["busdc"]))
pg_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["gen"]))
qg_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["gen"]))
x = 1 : 1 : length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["bus"])
y = 1 : 1 : length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["gen"])
pg_u = zeros(Float64, length(data["gen"]))
pg_l = zeros(Float64, length(data["gen"]))
qg_u = zeros(Float64, length(data["gen"]))
qg_l = zeros(Float64, length(data["gen"]))
pf_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
pt_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"])) 
qf_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
qt_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
sf_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
st_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
If_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
fbus = zeros(Int64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
s_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
s_u = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
s_l = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
pfdc_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]))
ptdc_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]))
sdc_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]))
sdc_u = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]))
sdc_l = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]))
ploss_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
qloss_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
pdcloss_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]))
sloss_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]))
fbusdc_b = zeros(Int64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]))
Ifdc_b = zeros(Float64, length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]))
for i=1:length(data["gen"])
    pg_u[i] = data["gen"]["$i"]["pmax"]
    pg_l[i] = data["gen"]["$i"]["pmin"]
    qg_u[i] = data["gen"]["$i"]["qmax"]
    qg_l[i] = data["gen"]["$i"]["qmin"]
end
for i=1:length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["bus"])   
    vm_ac_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["bus"]["$i"]["vm"]
    va_ac_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["bus"]["$i"]["va"]
end
for i=1:length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["busdc"])   
    vm_dc_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
end
for i=1:length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["gen"])   
    pg_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["gen"]["$i"]["pg"]
    qg_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["gen"]["$i"]["qg"]
end
for i=1:length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"])
    pf_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]["$i"]["pf"]
    pt_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]["$i"]["pt"]
    qf_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]["$i"]["qf"]
    qt_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branch"]["$i"]["qt"]
    sf_b[i] = sqrt(pf_b[i]^2 + qf_b[i]^2)
    st_b[i] = sqrt(pt_b[i]^2 + qt_b[i]^2)
    s_u[i] = data["branch"]["$i"]["rate_c"]
    fbus[i] = Int(data["branch"]["$i"]["f_bus"])
    If_b[i] = (sf_b[i]*data["baseMVA"])/(vm_ac_b[fbus[i]]*data["bus"][string(fbus[i])]["base_kv"])
    
    if sf_b[i] > st_b[i]
        s_b[i] = sf_b[i]
    else
        s_b[i] = st_b[i]
    end
    if abs(pf_b[i]) > abs(pt_b[i])
        ploss_b[i] = abs(pf_b[i]) - abs(pt_b[i])
    else
        ploss_b[i] = abs(pt_b[i]) - abs(pf_b[i])
    end
    if abs(qf_b[i]) > abs(qt_b[i])
        qloss_b[i] = abs(qf_b[i]) - abs(qt_b[i])
    else
        qloss_b[i] = abs(qt_b[i]) - abs(qf_b[i])
    end
    sloss_b[i] = sqrt(ploss_b[i]^2 + qloss_b[i]^2)
end
for i=1:length(resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"])
    pfdc_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]["$i"]["pf"]
    ptdc_b[i] = resultACDCSCOPF2["b"]["solution"]["nw"]["0"]["branchdc"]["$i"]["pt"]
    sdc_u[i] = data["branchdc"]["$i"]["rateC"]
    fbusdc_b[i] = Int(data["branchdc"]["$i"]["fbusdc"])
    #@show fbusdc_b[i], typeof(fbusdc_b[i])
    Ifdc_b[i] = (pfdc_b[i]*data["baseMVA"])/(vm_dc_b[fbusdc_b[i]]*data["busdc"][string(fbusdc_b[i])]["basekVdc"])
    
    if pfdc_b[i] > ptdc_b[i]
        sdc_b[i] = pfdc_b[i]
    else
        sdc_b[i] = ptdc_b[i]
    end
    if abs(pfdc_b[i]) > abs(ptdc_b[i])
        pdcloss_b[i] =  abs(pfdc_b[i]) - abs(ptdc_b[i])
    else
        pdcloss_b[i] =  abs(ptdc_b[i]) - abs(pfdc_b[i])
    end
end

########### Voltage magnitude
_P.plot(x, vm_ac_b, seriestype = :scatter, color = "blue", label = "vm_ac_b", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [0.85,1.15],  title = "Voltage Magnitude Base Case")        # framestyle = :box,
_P.plot!(vm_dc_b, seriestype = :scatter, color = "red", label = "vm_dc_b")
_P.plot!(ones(67)*1.1, linestyle = :dash, color = "blue", label = false)
_P.plot!(ones(67)*0.9, linestyle = :dash, color = "blue", label = false)
_P.plot!(ones(9)*1.05, linestyle = :dash, color = "red", label = false)
_P.plot!(ones(9)*0.95, linestyle = :dash, color = "red", label = false)
_P.xlabel!("Bus No.")
_P.ylabel!("Voltage (p.u)")
_P.savefig("vm_b_plot.png")

########### Voltage angle
_P.plot(x, va_ac_b, seriestype = :scatter, color = "blue", label = "va_ac_b", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-pi/8, pi/8], title = "Voltage Angle Base Case")        # framestyle = :box,
_P.plot!(ones(67)*pi/12, linestyle = :dash, color = "blue", label = false)
_P.plot!(ones(67)*-pi/12, linestyle = :dash, color = "blue", label = false)
_P.xlabel!("Bus No.")
_P.ylabel!("Angle (Rad)")
_P.savefig("va_b_plot.png")

########### Active/Reactive Power Generators
_P.plot(pg_b, seriestype = :bar, bar_width = 0.4, color = "blue", label = "pg_b", grid = true, gridalpha = 0.2, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-10, 16], title = "Active & Reactive Power of Generators")
_P.plot!(qg_b,seriestype = :bar, bar_width = 0.4, color = "brown",label = "qg_b")
_P.plot!(pg_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(pg_l, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(qg_u, seriestype = :stepmid, linestyle = :dash, color = "brown", label = false)
_P.plot!(qg_l, seriestype = :stepmid, linestyle = :dash, color = "brown", label = false)
_P.xlabel!("Generator No.")
_P.ylabel!("Power (p.u)")
_P.savefig("pg_qg_b_plot.png")

########### Active/Reactive branch flows
_P.plot(pf_b, seriestype = :scatter, color = "blue", label = "pf_b", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-16, 16],title = "Active & Reactive Branch Flows")        # framestyle = :box,
_P.plot!(qf_b, seriestype = :scatter, color = "red", label = "qf_b")
_P.plot!(pfdc_b, seriestype = :scatter, color = "green", label = "pfdc_b")
_P.xlabel!("Branch No.")
_P.ylabel!("Power (p.u)")
_P.savefig("pf_qf_pfdc_b_plot.png")

########### Branch flows
_P.plot(s_b, seriestype = :scatter, color = "blue", label = "s_b", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-16, 16],title = "Branch Flows")        # framestyle = :box,
_P.plot!(sdc_b, seriestype = :scatter, color = "red", label = "sdc_b")
_P.plot!(s_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(-s_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(sdc_u, seriestype = :stepmid, linestyle = :dash, color = "red", label = false)
_P.plot!(-sdc_u, seriestype = :stepmid, linestyle = :dash, color = "red", label = false)
_P.xlabel!("Branch No.")
_P.ylabel!("Power (p.u)")
_P.savefig("s_sdc_b_plot.png")

########### Branch flow losses
_P.plot(ploss_b, seriestype = :scatter, color = "blue", label = "ploss_b", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [0,1],title = "Branch Losses")        # framestyle = :box,
_P.plot!(qloss_b, seriestype = :scatter, color = "red", label = "qloss_b")
_P.plot!(sloss_b, seriestype = :scatter, color = "green", label = "sloss_b")
_P.plot!(pdcloss_b, seriestype = :scatter, color = "black", label = "pdcloss_b")
_P.xlabel!("Branch No.")
_P.ylabel!("Power (p.u)")
_P.savefig("pqsloss_pdcloss_b_plot.png")
########### Branch Currents
_P.plot(If_b*1000, seriestype = :scatter, color = "blue", label = "If_b", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [],title = "Branch Currents")        # framestyle = :box,
_P.plot!(Ifdc_b*1000, seriestype = :scatter, color = "red", label = "Ifdc_b")
_P.plot!(ones(102)*3500, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(-ones(102)*3500, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.xlabel!("Branch No.")
_P.ylabel!("Current (A)")
_P.savefig("If_Ifdc_b_plot.png")

############################################# Contingency Plots ################################################
for i = 1 : length(data["gen_contingencies"]) + length( data["branch_contingencies"]) + length(data["branchdc_contingencies"])
 vm_ac_c = zeros(Float64, length(resultACDCSCOPF2["sol_c"]["c$i"]["bus"]))
 vm_dc_c = zeros(Float64, length(resultACDCSCOPF2["sol_c"]["c$i"]["busdc"]))
 pg_c = zeros(Float64, length(resultACDCSCOPF2["sol_c"]["c$i"]["gen"]))
 qg_c = zeros(Float64, length(resultACDCSCOPF2["sol_c"]["c$i"]["gen"]))
 
 for j=1:length(resultACDCSCOPF2["sol_c"]["c$i"]["bus"])   
     vm_ac_c[j] = resultACDCSCOPF2["sol_c"]["c$i"]["bus"]["$j"]["vm"]
 end
 for j=1:length(resultACDCSCOPF2["sol_c"]["c$i"]["busdc"]) 
     vm_dc_c[j] = resultACDCSCOPF2["sol_c"]["c$i"]["busdc"]["$j"]["vm"]
 end
 for j=1:length(resultACDCSCOPF2["sol_c"]["c$i"]["gen"])   
     pg_c[j] = resultACDCSCOPF2["sol_c"]["c$i"]["gen"]["$j"]["pg"]
     qg_c[j] = resultACDCSCOPF2["sol_c"]["c$i"]["gen"]["$j"]["qg"]
 end
 _P.plot(vm_ac_c, seriestype = :scatter, label = "vm_ac_c", title = "Voltage Magnitude AC Buses for C $i")
 _P.xlabel!("No. of AC Buses")
 _P.ylabel!("Voltage (p.u)")
 _P.savefig("vm_ac_c$i.png")
 
 _P.plot(vm_dc_c, seriestype = :scatter, label = "vm_dc_c", title = "Voltage Magnitude DC Buses for C $i")
 _P.xlabel!("No. of DC Buses")
 _P.ylabel!("Voltage (p.u)")
 _P.savefig("vm_dc_c$i.png")
 
 _P.plot(pg_c, seriestype = :bar, bar_width = 0.5, label = "pg_c", title = "Active/Reactive Power of Generators for C $i")
 _P.plot!(qg_c,seriestype = :bar, bar_width = 0.5, label = "qg_c")
 _P.xlabel!("No. of Generators")
 _P.ylabel!("Power (p.u)")
 _P.savefig("pg_qg_c$i.png")

end
############################################# Final Solution Plots ################################################

vm_ac_f = zeros(Float64, length(resultACDCSCOPF2["f"]["solution"]["bus"]))
vm_dc_f = zeros(Float64, length(resultACDCSCOPF2["f"]["solution"]["busdc"]))
pg_f = zeros(Float64, length(resultACDCSCOPF2["f"]["solution"]["gen"]))
qg_f = zeros(Float64, length(resultACDCSCOPF2["f"]["solution"]["gen"]))


for i=1:length(resultACDCSCOPF2["f"]["solution"]["bus"])   
    vm_ac_f[i] = resultACDCSCOPF2["f"]["solution"]["bus"]["$i"]["vm"]
end
for i=1:length(resultACDCSCOPF2["f"]["solution"]["busdc"])   
    vm_dc_f[i] = resultACDCSCOPF2["f"]["solution"]["busdc"]["$i"]["vm"]
end
for i=1:length(resultACDCSCOPF2["f"]["solution"]["gen"])   
    pg_f[i] = resultACDCSCOPF2["f"]["solution"]["gen"]["$i"]["pg"]
    qg_f[i] = resultACDCSCOPF2["f"]["solution"]["gen"]["$i"]["qg"]
end
_P.plot(vm_ac_f, seriestype = :scatter, label = "vm_ac_f", title = "Voltage Magnitude AC Buses")
_P.xlabel!("No. of AC Buses")
_P.ylabel!("Voltage (p.u)")
_P.savefig("vm_ac_f_plot.png")

_P.plot(vm_dc_f, seriestype = :scatter, label = "vm_dc_f", title = "Voltage Magnitude DC Buses")
_P.xlabel!("No. of DC Buses")
_P.ylabel!("Voltage (p.u)")
_P.savefig("vm_dc_f_plot.png")

_P.plot(pg_f, seriestype = :bar, bar_width = 0.5, label = "pg_f", title = "Active/Reactive Power of Generators")
_P.plot!(qg_f,seriestype = :bar, bar_width = 0.5, label = "qg_f")
_P.xlabel!("No. of Generators")
_P.ylabel!("Power (p.u)")
_P.savefig("pg_qg_f_plot.png")

############################################# Final Solution Plots ################################################