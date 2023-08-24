
# Test script for PowerModelsACDCsecurityconstrained on SNEM2000acdc

using Ipopt
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained


const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer,"print_level"=>0, "tol"=>1e-6)

## Include some helper functions
include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/scripts/extra/SNEM2000.jl")

file = "./data/snem2000_acdc.m"
data = parse_file(file)

# Adding contingencies

data["branchdc_contingencies"] = Vector{Any}(undef, 1)
data["branchdc_contingencies"][1] = (idx = 3, label = "TERRANORA_HVDC_2", type = "branchdc")

data["branch_contingencies"] = Vector{Any}(undef, 1)
data["branch_contingencies"][1] = (idx = 1647, label = "xf_1392_to_1612_2_2winding_transformer", type = "branch")
# data["branch_contingencies"][2] = (idx = 960, label = "line_3560_to_3578_2_cp_merged_with_xf_3578_to_3429_2_2winding_transformer", type = "branch")
# data["branch_contingencies"][2] = (idx = 674, label = "line_3078_to_3643_2_cp", type = "branch")
# data["branch_contingencies"][4] = (idx = 1275, label = "line_5095_to_5100_1_cp", type = "branch")
# data["branch_contingencies"][5] = (idx = 290, label = "line_1261_to_1438_1_cp", type = "branch")
   
data["gen_contingencies"] = Vector{Any}(undef, 1)
data["gen_contingencies"][1] = (idx = 80, label = "gen_2093_2__4.2MW", type = "gen")

data["convdc_contingencies"] = Vector{Any}(undef, 1)
data["convdc_contingencies"][1] = (idx = 6, label = "MURRAY_HVDC_VIC", type = "convdc")

# Defining generator areas: area_gens

set1 = Set{Int64}()
set2 = Set{Int64}()
set3 = Set{Int64}()
set4 = Set{Int64}()
set5 = Set{Int64}()

for i = 1:length(data["gen"])
    gen_bus = data["gen"]["$i"]["gen_bus"]
    if data["bus"]["$gen_bus"]["area"] == 1
        push!(set1, data["gen"]["$i"]["index"])
    elseif data["bus"]["$gen_bus"]["area"] == 2
        push!(set2, data["gen"]["$i"]["index"])
    elseif data["bus"]["$gen_bus"]["area"] == 3
        push!(set3, data["gen"]["$i"]["index"])
    elseif data["bus"]["$gen_bus"]["area"] == 4
        push!(set4, data["gen"]["$i"]["index"])
    elseif data["bus"]["$gen_bus"]["area"] == 5
        push!(set5, data["gen"]["$i"]["index"])
    end
end

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = set1
data["area_gens"][2] = set2
data["area_gens"][3] = set3
data["area_gens"][4] = set4
data["area_gens"][5] = set5

gen_total1 = sum(data["gen"]["$i"]["pmax"] for i in collect(set1))
gen_total2 = sum(data["gen"]["$i"]["pmax"] for i in collect(set2))
gen_total3 = sum(data["gen"]["$i"]["pmax"] for i in collect(set3))
gen_total4 = sum(data["gen"]["$i"]["pmax"] for i in collect(set4))
gen_total5 = sum(data["gen"]["$i"]["pmax"] for i in collect(set5))

for i in collect(set1)
    if data["gen"]["$i"]["type"] != "VAr support"
        data["gen"]["$i"]["alpha"] = gen_total1/data["gen"]["$i"]["pmax"]
    else
        data["gen"]["$i"]["alpha"] = 0.0
    end 
end

for i in collect(set2)
    if data["gen"]["$i"]["type"] != "VAr support"
        data["gen"]["$i"]["alpha"] = gen_total2/data["gen"]["$i"]["pmax"] 
    else
        data["gen"]["$i"]["alpha"] = 0.0
    end  
end

for i in collect(set3)
    if data["gen"]["$i"]["type"] != "VAr support"
        data["gen"]["$i"]["alpha"] = gen_total3/data["gen"]["$i"]["pmax"]
    else
        data["gen"]["$i"]["alpha"] = 0.0
    end   
end

for i in collect(set4)
    if data["gen"]["$i"]["type"] != "VAr support"
        data["gen"]["$i"]["alpha"] = gen_total4/data["gen"]["$i"]["pmax"]
    else
        data["gen"]["$i"]["alpha"] = 0.0
    end  
end

for i in collect(set5)
    if data["gen"]["$i"]["type"] != "VAr support"
        data["gen"]["$i"]["alpha"] = gen_total5/data["gen"]["$i"]["pmax"]
    else
        data["gen"]["$i"]["alpha"] = 0.0
    end   
end

# Adding emergency ac branch ratings and transformer tap bounds 

for i=1:length(data["branch"])
    data["branch"]["$i"]["rate_a"] = 1.3 * data["branch"]["$i"]["rate_a"]
    data["branch"]["$i"]["rate_b"] = 1.3 * data["branch"]["$i"]["rate_b"]
    data["branch"]["$i"]["rate_c"] = 1.3 * data["branch"]["$i"]["rate_c"]
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

# Correcting generator cost co-efficients

# for i=1:length(data["gen"])
#     data["gen"]["$i"]["ep"] = 1e-1
#     if data["gen"]["$i"]["ncost"] == 0
#         data["gen"]["$i"]["ncost"] = 2 
#         push!(data["gen"]["$i"]["cost"], 0)
#         push!(data["gen"]["$i"]["cost"], 0)
#         push!(data["gen"]["$i"]["cost"], 0)
#         push!(data["gen"]["$i"]["cost"], 0)
#     end
#     if data["gen"]["$i"]["ncost"] == 2 && length(data["gen"]["$i"]["cost"]) == 2
#         push!(data["gen"]["$i"]["cost"], 0)
#         push!(data["gen"]["$i"]["cost"], 0)
#     end
# end
for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
end

# Ading converter dead band voltage bounds

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end

for (i, branch) in data["branch"]
    if branch["br_x"] == 0
        branch["br_x"] = 1E-3
    end
end
data["contingencies"] = []

split_large_coal_powerplants_to_units!(data)

for (i,conv) in data["convdc"]
    data["busdc"]["$(conv["busdc_i"])"]["area"] = data["bus"]["$(conv["busac_i"])"]["area"]
end




PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

# result_acdcopf = PM_acdc.run_acdcpf(data, PM.ACPPowerModel, nlp_solver, setting=setting)

# PM.update_data!(data, result_acdcopf["solution"])
# for (i,conv) in data["convdc"]
#     conv["P_g"] = -result_acdcopf["solution"]["convdc"][i]["pgrid"]
#     conv["Q_g"] = -result_acdcopf["solution"]["convdc"][i]["qgrid"]
#     println("$i ... $(conv["P_g"]*100), $(conv["Q_g"]*100)")
#     # type_dc = 3 (droop control)
#     # conv["Pdcset"] = solution["convdc"][i]["pdc"]
# end

# data["branchdc"]["3"]["status"] = 1
# data["convdc"]["6"]["status"] = 1
# data["gen"]["1"]["gen_status"] = 0

# result_acdcpf = PM_acdc.run_acdcpf(data, PM.ACPPowerModel, nlp_solver, setting=setting)


result_ACDC_scopf_soft_SI = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations_SI, nlp_solver, setting) 


@time result_ACDC_scopf_soft_ndc = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 

@time result_ACDC_scopf_re_dispatch_oltc_pst = PM_acdc_sc.run_ACDC_scopf_re_dispatch(data, result_ACDC_scopf_soft, PM.ACPPowerModel, nlp_solver) 

# plots

data = parse_file(file)
PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)



PM.update_data!(data, result_ACDC_scopf_soft_SI["base"]["solution"]["nw"]["0"])
for (i,conv) in data["convdc"]
    conv["P_g"] = -result_ACDC_scopf_soft_SI["base"]["solution"]["nw"]["0"]["convdc"][i]["pgrid"]
    conv["Q_g"] = -result_ACDC_scopf_soft_SI["base"]["solution"]["nw"]["0"]["convdc"][i]["qgrid"]
    # println("$i ... $(conv["P_g"]*100), $(conv["Q_g"]*100)")
    # type_dc = 3 (droop control)
    # conv["Pdcset"] = solution["convdc"][i]["pdc"]
end

data["branch"]["1647"]["status"] = 0

# data["branchdc"]["3"]["status"] = 1
data["convdc"]["6"]["status"] = 1
# data["gen"]["80"]["gen_status"] = 1


result_acdcpf = PM_acdc.run_acdcpf(data, PM.ACPPowerModel, nlp_solver, setting=setting)

using Plots
using Plots.PlotMeasures
using LaTeXStrings

##
# k = "gen"
k = "branch"
# k = "conv"

vm = [ result_acdcpf["solution"]["bus"][i]["vm"] for (i, bus) in data["bus"] ]
pg = [ 100*result_acdcpf["solution"]["gen"][i]["pg"]/data["gen"][i]["pmax"] for (i, gen) in result_acdcpf["solution"]["gen"]]
sij = [ 100*( (sqrt( (result_acdcpf["solution"]["branch"][i]["pf"])^2 + (result_acdcpf["solution"]["branch"][i]["qf"])^2)) / data["branch"][i]["rate_c"] ) for (i, branch) in result_acdcpf["solution"]["branch"] ]
pij = [ 100*((result_acdcpf["solution"]["branch"][i]["pf"])/data["branch"][i]["rate_c"]) for (i, branch) in result_acdcpf["solution"]["branch"] ]
pijdc = [ result_acdcpf["solution"]["branchdc"][i]["pf"] for (i, branchdc) in data["branchdc"] ]
vmdc = [ result_acdcpf["solution"]["busdc"][i]["vm"] for (i, busdc) in data["busdc"] ]



k=0

vm = [ result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["bus"][i]["vm"] for (i, bus) in data["bus"] ]
pg = [ 100*result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["gen"][i]["pg"]/data["gen"][i]["pmax"] for (i, gen) in result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["gen"]]
sij = [ 100*( (sqrt( (result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["branch"][i]["pf"])^2 + (result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["branch"][i]["qf"])^2)) / data["branch"][i]["rate_a"] ) for (i, branch) in result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["branch"] ]
pij = [ 100*((result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["branch"][i]["pf"])/data["branch"][i]["rate_c"]) for (i, branch) in result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["branch"] ]
pijdc = [ result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["branchdc"][i]["pf"] for (i, branchdc) in data["branchdc"] ]
vmdc = [ result_ACDC_scopf_soft_SI["final"]["solution"]["nw"]["$k"]["busdc"][i]["vm"] for (i, busdc) in data["busdc"] ]


vm_lb = [ data["bus"][i]["vmin"] for (i, bus) in data["bus"] ]
vm_ub = [ data["bus"][i]["vmax"] for (i, bus) in data["bus"] ]
s_ub = [ data["branch"][i]["rate_c"] for (i, branch) in data["branch"] ]
sdc_ub = [ data["branchdc"][i]["rateC"] for (i, branchdc) in data["branchdc"] ]
pg_lb = [ data["gen"][i]["pmin"] for (i, gen) in data["gen"] ]
pg_ub = [ data["gen"][i]["pmax"] for (i, gen) in data["gen"] ]
qg_lb = [ data["gen"][i]["qmin"] for (i, gen) in data["gen"] ]
qg_ub = [ data["gen"][i]["qmax"] for (i, gen) in data["gen"] ]

# vm
plot(vm, seriestype = :scatter, markersize = 1.5, color = "blue", label = "vm", grid = true, dpi = 600, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", ylims = [0.88,1.12], legend = false, legend_column = 2)        # framestyle = :box, title = "|V|"
plot!(1.1*ones(length(vm)), linewidth = 1, color = "red", label = false)
plot!(0.9*ones(length(vm)), seriestype = :line, linewidth = 1, color = "red", label = false)
xlabel!("Bus Number")
ylabel!("Voltage Magnitude (p.u)")
savefig("./plots/vm$k.pdf")

# pg
plot(pg, seriestype = :scatter, markersize = 1.5, color = "blue", label = "pg", grid = true, dpi = 600, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", ylims = [], legend = false)        # framestyle = :box, title = "|V|"
plot!(100*ones(length(pg)), seriestype = :line, linewidth = 1, color = "red", label = false)
xlabel!("Generator Number")
ylabel!("Normallized Active Power Generation (%)")
savefig("./plots/pg$k.pdf")

# sij
plot(sij, seriestype = :scatter, markersize = 1.5, color = "blue", label = "sij", grid = true, dpi = 600, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", ylims = [], legend = false)        # framestyle = :box, title = "|V|"
plot!(100*(ones(length(sij))), seriestype = :line, linewidth = 1, color = "red", label = false)
xlabel!("Branch Number")
ylabel!("Normallized Branch Apparent Power (%)")
savefig("./plots/sij$k.pdf")    

# sijdc
plot((pijdc./sdc_ub)*100, seriestype = :scatter, markersize = 5, color = "blue", label = "pijdc", grid = true, dpi = 600, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", ylims = [], legend = false)        # framestyle = :box, title = "|V|"
plot!(100*ones(length(pijdc)), seriestype = :line, linewidth = 1, color = "red", label = false)
xlabel!("DC Branch Number")
ylabel!("Normallized DC Branch Apparent Power (%)")
savefig("./plots/sijdc$k.pdf")  

# vmdc
plot(vmdc, seriestype = :scatter, markersize = 5, color = "blue", label = "pijdc", grid = true, dpi = 600, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", ylims = [], legend = false)        # framestyle = :box, title = "|V|"
plot!(1.1*ones(length(vm)), linewidth = 1, color = "red", label = false)
plot!(0.9*ones(length(vm)), seriestype = :line, linewidth = 1, color = "red", label = false)
xlabel!("DC Bus Number")
ylabel!("DC Voltage (p.u)")
savefig("./plots/vmdc$k.pdf")
