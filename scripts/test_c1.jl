using Pkg
Pkg.activate("./scripts")
#Pkg.develop(PackageSpec(path = "/Users/moh050/OneDrive - CSIRO/Documents/GitHub/ChargingStationOpt"))
using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained
using LinearAlgebra

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
c1_networks["branchdc"]["1"]=Dict("c" => 0, "r" => 0.052, "status" => 1, "rateB" => 100, "fbusdc" => 1, "source_id" => Any["branchdc", 1, 2, "R" ], "rateA" => 100, "l" => 0, "index" => 1, "rateC" => 100, "tbusdc" => 2)
c1_networks["convdc"]=Dict{String, Any}()
c1_networks["convdc"]["1"]=Dict{String, Any}()
c1_networks["convdc"]["2"]=Dict{String, Any}()
c1_networks["convdc"]["1"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 2, "tm" => 1, "type_dc" => 1, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 50, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)
c1_networks["convdc"]["2"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => 21.9013, "islcc" => 0, "LossA" => 1.103, "Qacmin" => -50, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 3, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.007, "Pacmin" => -100, "Qacmax" => 50, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 1, "bf" => 0.01, "LossCinv" => 2.885)

c1_networks["branchdc_contingencies"]=Vector{Any}(undef, 1)
c1_networks["branchdc_contingencies"][1]=(idx = 1, label = "LINE-1-2-R", type = "branchdc")
c1_networks["branch_contingencies"]=Vector{Any}(undef, 3)
c1_networks["branch_contingencies"][1]=(idx = 7, label = "LINE-4-5-BL", type = "branch")
c1_networks["branch_contingencies"][2]=(idx = 9, label = "LINE-6-12-BL", type = "branch")
c1_networks["branch_contingencies"][3]=(idx = 10, label = "LINE-6-13-BL", type = "branch")
#c1_networks["branch_contingencies"][4]=(idx = 6, label = "LINE-3-4-BL", type = "branch")
#c1_networks["branch_contingencies"][5]=(idx = 1, label = "LINE-1-2-BL", type = "branch")
#c1_networks["branch_contingencies"][6]=(idx = 2, label = "LINE-1-5-BL", type = "branch")
#c1_networks["branch_contingencies"][7]=(idx = 3, label = "LINE-2-3-BL", type = "branch")
#c1_networks["branch_contingencies"][8]=(idx = 4, label = "LINE-2-4-BL", type = "branch")
#c1_networks["branch_contingencies"][9]=(idx = 5, label = "LINE-2-5-BL", type = "branch")
#c1_networks["branch_contingencies"][10]=(idx = 8, label = "LINE-6-11-BL", type = "branch")
#c1_networks["branch_contingencies"][11]=(idx = 11, label = "LINE-7-8-BL", type = "branch")

c1_networks["gen_contingencies"]=Vector{Any}(undef, 2)
c1_networks["gen_contingencies"][1]=(idx = 3, label = "GEN-3-1", type = "gen")
c1_networks["gen_contingencies"][2]=(idx = 1, label = "GEN-1-1", type = "gen")
#c1_networks["gen_contingencies"][3]=(idx = 2, label = "GEN-2-1", type = "gen")


#result = PowerModels.run_opf(c1_networks, PowerModels.ACPPowerModel, nlp_solver)
#PowerModels.update_data!(c1_networks, result["solution"])
#delete!(c1_networks["branch"], "7")
#s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
#PowerModelsACDC.process_additional_data!(c1_networks)
#solution = PowerModelsACDCsecurityconstrained.run_acdcpf_GM(c1_networks, PowerModels.DCPPowerModel, lp_solver; setting = s)
#PowerModels.update_data!(c1_networks, solution)
#flow = PowerModels.calc_branch_flow_dc(c1_networks)


#ref_bus_id = PowerModels.reference_bus(c1_networks)["index"]
#am = PowerModels.calc_susceptance_matrix(c1_networks)
#branch = c1_networks["branch"]["7"]

#bus_injection = PowerModelsACDCsecurityconstrained.calc_c1_branch_ptdf_single_GM(am, ref_bus_id, branch)

#data = PowerModels.make_basic_network(c1_networks)
file = "./data/case5_acdc_scopf.m"
data = parse_file(file)
#data["dcline"] = data["branchdc"]
#data["dcline"]["1"]["f_bus"] = Dict()
#data["dcline"]["1"]["f_bus"] =data["branchdc"]["1"]["fbusdc"]
#data["dcline"]["2"]["f_bus"] = data["branchdc"]["2"]["fbusdc"]
#data["dcline"]["3"]["f_bus"] = Dict()
#data["dcline"]["3"]["f_bus"] = data["branchdc"]["3"]["fbusdc"]
#data["dcline"]["1"]["t_bus"] = Dict()
#data["dcline"]["1"]["t_bus"] = data["branchdc"]["1"]["tbusdc"]
#data["dcline"]["2"]["t_bus"] = Dict()
#data["dcline"]["2"]["t_bus"] = data["branchdc"]["2"]["tbusdc"]
#data["dcline"]["3"]["t_bus"] = Dict()
#data["dcline"]["3"]["t_bus"] = data["branchdc"]["3"]["tbusdc"]
#p1 =powerplot(data; width=1000, height=1000, node_size=1000, gen_size = 500, branch_color = "blue", dcline_color = "green", edge_size=3)
#PowerPlots.Experimental.add_zoom!(p1)

#I = Int[]
#J = Int[]   
#V = Int[]

#b = [branchdc for (i,branchdc) in data["branchdc"] if branchdc["status"] != 0]
#branchdc_ordered = sort(b, by=(x) -> x["index"])
#for (i,branchdc) in enumerate(branchdc_ordered)
#    fbusdc_conv = [convdc["busac_i"] for (j,convdc) in data["convdc"] if convdc["busdc_i"] == branchdc["fbusdc"]]
#    tbusdc_conv = [convdc["busac_i"] for (j,convdc) in data["convdc"] if convdc["busdc_i"] == branchdc["tbusdc"]]
    
#    push!(I, i); push!(J, fbusdc_conv[1]); push!(V,  1)
#    push!(I, i); push!(J, tbusdc_conv[1]); push!(V, -1)

#    for k in length(J):length(data["bus"])
#        push!(I, i); push!(J, k); push!(V, 0)
#    end
#end
PowerModelsACDC.process_additional_data!(data)
data["dcline"] = Dict{String, Any}() 
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
results1 = PowerModelsACDC.run_acdcopf(data, PowerModels.DCPPowerModel, lp_solver, setting=setting);
inc_matrix_ac = PowerModels.calc_basic_incidence_matrix(data)
#data = c1_networks
ptdf_matrix = PowerModels.calc_basic_ptdf_matrix(data)
inc_matrix_dc = PowerModelsACDCsecurityconstrained.calc_incidence_matrix_dc(data)
dcdf_matrix = - ptdf_matrix * transpose(inc_matrix_dc)

Pinj = [1.64308 -0.0508445 -0.45 0.4 0.6]'
Pinj = [1.64308 0.149155 0 0 0]'
pijdc = [-0.446609 0.408857 -0.0297137]'
ptdf_matrix * Pinj + dcdf_matrix *pijdc



inc_matrix_ac*ptdf_matrix'

am = PowerModelsACDCsecurityconstrained.calc_susceptance_matrix_GM(data)

branch = data["branch"]["6"];
ref_bus = 1;
bus_injection = PowerModelsACDCsecurityconstrained.calc_c1_branch_ptdf_single_GM(am, ref_bus, branch)



inc_matrix_dc = PowerModelsACDCsecurityconstrained.calc_incidence_matrix_dc(data)
dcdf_matrix = - ptdf_matrix * transpose(inc_matrix_dc)
LinearAlgebra.pinv(dcdf_matrix)
ptdf_branch_wr = Dict(1:length(ptdf_matrix[7, :]) .=> - ptdf_matrix[7, :])
dcdf_branch = Dict(1:length(dcdf_matrix[7, :]) .=> - dcdf_matrix[7, :])
ptdf_branch = Dict(k => v for (k, v) in ptdf_branch_wr if k != ref_bus)    # remove reference

bus_injection = Dict(i => -b*(get(va_fr, i, 0.0) - get(va_to, i, 0.0)) for i in union(keys(va_fr), keys(va_to)))
#PowerModelsACDC.process_additional_data!(c1_networks)
#s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)            settings=s

#resultACDCSCOPF1=PowerModelsACDCsecurityconstrained.run_scopf_contigency_cuts(c1_networks, PowerModels.DCPPowerModel, lp_solver)
resultACDCSCOPF2=PowerModelsSecurityConstrained.run_c1_scopf_ptdf_cuts!(c1_networks, PowerModels.ACPPowerModel, nlp_solver)
#resultACDCSCOPF3=PowerModelsACDCsecurityconstrained.run_scopf_contigency_cuts(c1_networks, PowerModels.ACRPowerModel, nlp_solver)   # Constraints required constraint_ohms_dc_branch(::ACRPowerModel, ::Int64, ...


   