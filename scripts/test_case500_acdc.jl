

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
# for (i, bus) in data["bus"]
#     if bus["base_kv"] == 345
#     println("$i.........$(bus["base_kv"])...........$(bus["bus_type"])")
#     end
# end
# for (i, branch) in data["branch"]
#     println("$i.........$(branch["rate_c"])")
# end

# data["branchdc_contingencies"] = []
# data["convdc_contingencies"] = []

PM_acdc_sc.fix_scopf_data_case500_acdc!(data)

data["slack"] = Dict{String, Any}()
data["slack"]["1"] = Dict{String, Any}()
data["slack"]["1"]["cost"] = [0, 0, 1E-12, 5E5, 0.1, 5E7, 11, 5E10]
data["slack"]["1"]["ncost"] = 4

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 
# for (i,branch) in data["branch"]
#     if branch["br_status"] == 0
#         delete!(data["branch"], i)
#     end
# end

@time results = PM_acdc_sc.run_acdc_scopf_ptdf_dcdf_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_acdc_scopf_cuts, nlp_solver)

# data_SI = deepcopy(data)
# result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 
@time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 

@time result_ACDC_scopf_re_dispatch_oltc_pst = PM_acdc_sc.run_ACDC_scopf_re_dispatch(data, result_ACDC_scopf_soft, PM.ACPPowerModel, nlp_solver) 

using Plots
scatter([branch["pf"] for (i, branch) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["branch"]])
scatter!([branchdc["pf"] for (i, branchdc) in result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["branchdc"]])

for (i,branch) in data["branch"]
    if branch["br_status"] == 0
        println("$i...........$(branch["br_status"])")
    end
end

## plots 

gen_cont_index = [ i for (i, cont) in data["gen_contingencies"] ]
branch_cont_index = [ i for (i, cont) in data["branch_contingencies"] ]
branchdc_cont_index = [ i for (i, cont) in data["branchdc_contingencies"] ]

pg_cont = [ result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"][i]["pg"] for (i, gen) in data["gen"] if gen["gen_status"] != 0 ]
pg_cut = [  results["final"]["solution"]["gen"][i]["pg"] for (i, gen) in data["gen"] if gen["gen_status"] != 0 ]
pg_diff = abs.(pg_cont.-pg_cut)

qg_cont = [ result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"][i]["qg"] for (i, gen) in data["gen"] if gen["gen_status"] != 0 ]
qg_cut = [  results["final"]["solution"]["gen"][i]["qg"] for (i, gen) in data["gen"] if gen["gen_status"] != 0]
qg_diff = abs.(qg_cont.-qg_cut)

vm_cont = [ result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"][i]["vm"] for (i, bus) in data["bus"] ]
vm_cut = [  results["final"]["solution"]["bus"][i]["vm"] for (i, bus) in data["bus"] ]
vm_diff = abs.(vm_cont.-vm_cut)

va_cont = [ result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["bus"][i]["va"] for (i, bus) in data["bus"] ]
va_cut = [  results["final"]["solution"]["bus"][i]["va"] for (i, bus) in data["bus"] ]
va_diff = abs.(va_cont.-va_cut)

using Plots
using LaTeXStrings
using Plots.PlotMeasures

plot(1:1:length(gen_cont_index), gen_cont_index, seriestype = :scatter, color = "blue", label = "generator contingencies", grid = false, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black")  

plot!(length(gen_cont_index):1:length(branch_cont_index)+length(gen_cont_index), branch_cont_index, seriestype = :scatter, color = "red", label = "branch contingencies", grid = false, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box)  

plot!((length(gen_cont_index)+length(branch_cont_index)):1:length(branchdc_cont_index)+(length(gen_cont_index)+length(branch_cont_index)), branchdc_cont_index, seriestype = :scatter, color = "green", label = "branchdc contingencies", grid = false, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box)  

plot(pg_cont, pg_cut, seriestype = :scatter, dpi = 600, size = (300,200), left_margin = [2mm 0mm], bottom_margin = 10px, color = "blue", label = L"{\mathrm{Active\;Power\;Setpoint\;(pu)}}", xlabel=L"{\mathrm{TSMP\;Model}}", ylabel=L"{\mathrm{Proposed\;Model}}", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black")  

plot!(minimum(pg_cont):0.001:maximum(pg_cont), minimum(pg_cont):0.001:maximum(pg_cont), label=false)
savefig("active_power_setpoint.png")

plot(qg_cont, qg_cut, seriestype = :scatter, color = "blue", label = "generator contingencies", grid = false, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box)  
plot!(minimum(qg_cont):0.001:maximum(qg_cont), minimum(qg_cont):0.001:maximum(qg_cont), label=false)

plot(vm_diff, seriestype = :scatter, color = "blue", label = "generator contingencies", grid = false, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box)  
plot!(minimum(vm_cont):0.001:maximum(vm_cont), minimum(vm_cont):0.001:maximum(vm_cont), label=false)
plot!(0.9:0.001:1.12, 0.9:0.001:1.12, label=false)

plot(va_diff, seriestype = :scatter, color = "blue", label = "generator contingencies", grid = false, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box)  
