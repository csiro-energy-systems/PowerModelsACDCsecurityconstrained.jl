

using Ipopt
using Cbc
using Juniper
using HiGHS
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained
using Plots
using CalculusWithJulia
using LaTeXStrings



const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "max_cpu_time" => 3600.0, "tol"=>1e-6)  # "print_level"=>0, "tol"=>1e-6
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)
# "hsllib" => "C:/Users/moh050/ThirdParty-HSL/.libs", "linear_solver" => "ma86",

file = "./data/case5_acdc_scopf.m"
data = parse_file(file)

idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]

data["convdc_contingencies"] = Vector{Any}(undef, 3)
data["convdc_contingencies"][1] = (idx = 1, label = "13", type = "convdc")
data["convdc_contingencies"][2] = (idx = 2, label = "14", type = "convdc")
data["convdc_contingencies"][3] = (idx = 3, label = "15", type = "convdc")

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([2, 1])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
end

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-3
end

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end

data["gen"]["1"]["alpha"] = 15.92 
data["gen"]["2"]["alpha"] = 11.09 

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
data["shunt"] = Dict{String, Any}()
data["shunt"]["1"] = Dict{String, Any}("b2" => 0.0, "n1" => 1, "adjm" => 0, "modsw" => 2, "shunt_bus" => 3, "b8" => 0.0, "status" => 1, "n5" => 0, "vswlo"  => 1.01462, "gs" => 0.0, "n3" => 0, "bs" => 0.0, "n8" => 0, "b7" => 0.0, "source_id" => Any["switched shunt", 129, 0], "n7" => 0, "rmpct" => 100.0, "b3" => 0.0, "bmax" => 0.6, "dispatchable" => true, "bmin" => 0.0, "n2" => 0, "b5" => 0.0, "index"  => 1, "n6" => 0, "rmidnt" => " 123", "b4"  => 0.0, "vswhi" => 1.01462, "b6" => 0.0, "n4" => 0, "b1" => 60.0)

data["slack"] = Dict{String, Any}()
data["slack"]["1"] = Dict{String, Any}()
data["slack"]["1"]["cost"] = [1E-13, 1000, 0.01, 5E5, 0.1, 5E7, 10, 5E15]
data["slack"]["1"]["ncost"] = 4

# data["branch"]["1"]["tm_min"] = 0.9; data["branch"]["1"]["tm_max"] = 1.1; 
# data["branch"]["2"]["tm_min"] = 0.9; data["branch"]["2"]["tm_max"] = 1.1; 
# data["branch"]["7"]["ta_min"] = -15.0; data["branch"]["7"]["ta_max"] = 15.0

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 
# results = PM_acdc_sc.run_acdc_scopf_ptdf_dcdf_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_acdc_scopf_cuts, nlp_solver)

# data_SI = deepcopy(data)

data_minlp = deepcopy(data)
result_ACDC_scopf_soft_ndc = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 

@time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations_SI, nlp_solver, setting) 

@time result_ACDC_scopf_soft_minlp = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data_minlp, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft_minlp, PM_acdc_sc.check_contingency_violations, minlp_solver, setting)

@time result_ACDC_scopf_re_dispatch_oltc_pst = PM_acdc_sc.run_ACDC_scopf_re_dispatch(data, result_ACDC_scopf_soft_ndc, PM.ACPPowerModel, nlp_solver)    


## visuallization !!!

f4(vdc) = pref_dc + (   -(1 / k_droop * (vdchigh - vdc)) + ep*log(1 + exp(((1 / k_droop * (vdchigh - vdc) ) - vdcmax + vdc)/ep)) 
        +(1 / k_droop * (vdcmax - vdc)) - ep*log(1 + exp(((1 / k_droop * (vdcmax - vdc)  ) - 2*vdcmax + vdchigh + vdc)/ep)) 
        -(1 / k_droop * (vdclow - vdc)) - ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc) ) - vdc + vdcmin)/ep))
        +(1 / k_droop * (vdcmin - vdc)) + ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) ) - vdc + 2*vdcmin - vdclow )/ep)) )


f4s(vdc) = pref_dc + (   (1 / k_droop * (vdcmax-vdchigh-vdclow+vdcmin)) + ep*log(1 + exp(((1 / k_droop * (vdchigh - vdc) ) - vdcmax + vdc)/ep)) 
         - ep*log(1 + exp(((1 / k_droop * (vdcmax - vdc)  ) - 2*vdcmax + vdchigh + vdc)/ep)) 
         - ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc) ) - vdc + vdcmin)/ep))
         + ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) ) - vdc + 2*vdcmin - vdclow )/ep)) )

f4st(vdc) = pref_dc + (    ep*log(1 + exp(((1 / k_droop * (vdchigh - vdc) ) - vdcmax + vdc)/ep)) 
         - ep*log(1 + exp(((1 / k_droop * (vdcmax - vdc)  ) - 2*vdcmax + vdchigh + vdc)/ep)) 
         - ep*log(1 + exp((-(1 / k_droop * (vdclow - vdc) ) - vdc + vdcmin)/ep))
         + ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) ) - vdc + 2*vdcmin - vdclow )/ep)) )


f6(vdc) = pref_dc + ( vdc> vdcmax ? (-1 / k_droop*(vdchigh -vdcmax)) : vdc > vdchigh && vdc <= vdcmax ? (-1 / k_droop * (vdchigh - vdc)) : vdc >= vdcmin && vdc < vdclow ? (-1 / k_droop * (vdclow - vdc)) : vdc < vdcmin ? (-1 / k_droop * (vdclow - vdcmin)) : 0)        
# plot(size = (600,400), grid = false, legend = false)
# vspan!([vdclow, vdchigh], linecolor = :grey90, fillcolor = :grey90)
# plot!(f6, 0.85, 1.15, linewidth=1.4, linecolor = :black)
# plot!(f4, 0.85, 1.15, linewidth=1.4, linecolor = :black)
fig = plot(f4, 0.85, 1.15, linewidth=1.4, linecolor = :black, grid = false, legend = false, dpi = 600)
plot!(f4s, 0.85, 1.15)
plot!(f4st, 0.85, 1.15)
savefig(fig, "./plots/fig.png")

# droop Curve Plot
plt = Plots.plot(layout=(2,1), size = (600,400), xformatter=:latex, yformatter=:latex, legend = :outertop)
sp=2
    i=3
    pref_dc = data["convdc"]["$i"]["Pdcset"] 
    Vdcset = data["convdc"]["$i"]["Vdcset"]
    vdcmax = data["convdc"]["$i"]["Vmmax"]
    vdcmin = data["convdc"]["$i"]["Vmmin"]
    vdchigh = data["convdc"]["$i"]["Vdchigh"] 
    vdclow = data["convdc"]["$i"]["Vdclow"]
    k_droop = data["convdc"]["$i"]["droop"] 
    ep = data["convdc"]["$i"]["ep"] 
 
    vdc = [nw["busdc"]["$i"]["vm"] for (j, nw) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"] if j !=="0"]
    pdc = [nw["convdc"]["$i"]["pdc"] for (j, nw) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"] if j !=="0"]
    
    vdco =  result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
    pdco = result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

    vdcf = result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
    pdcf = result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

    vdcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["branch1"]["solution"]["busdc"]["$i"]["vm"]
    pdcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["branch1"]["solution"]["convdc"]["$i"]["pdc"]

    # vdcr2 = result_ACDC_scopf_re_dispatch_oltc_pst["branch2"]["solution"]["busdc"]["$i"]["vm"]
    # pdcr2 = result_ACDC_scopf_re_dispatch_oltc_pst["branch2"]["solution"]["convdc"]["$i"]["pdc"]

    # vdcr3 = result_ACDC_scopf_re_dispatch_oltc_pst["convdc2"]["solution"]["busdc"]["$i"]["vm"]
    # pdcr3 = result_ACDC_scopf_re_dispatch_oltc_pst["convdc2"]["solution"]["convdc"]["$i"]["pdc"]

    pmax =  pref_dc + ((1/k_droop * (vdcmax -vdcmin))/2) + 1
    pmin =  pref_dc - ((1/k_droop * (vdcmax -vdcmin))/2) - 1

    using Plots.PlotMeasures
        
    vspan!([vdclow, vdchigh], linecolor = :grey90, fillcolor = :grey90, xformatter=:latex, yformatter=:latex, label = false, subplot=sp) # top_margin=5mm,
    plot!(f6, 0.85, 1.15, ylims =[pmin, pmax], linewidth=1, color="black", dpi = 600, xformatter=:latex, yformatter=:latex, label = false, legend = :outertop, legend_columns= -1, grid = false, gridalpha = 0.5, gridstyle = :dash, subplot=sp)  #framestyle = :box  #legend_columns= -1,
    vline!([vdcmin, vdcmax], linestyle = :dash, linecolor = :grey0, xformatter=:latex, yformatter=:latex, label = false, subplot=sp)
    scatter!([(vdco,pdco)],  markershape = :rect, markersize = 8, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", subplot=sp)
    annotate!([(vdcmin+0.005,pdco, (L"v^{dc,l}_e", :black, :left, 12))], subplot=sp)
    annotate!([(vdcmax+0.005,pdco, (L"v^{dc,u}_e", :black, :left, 12))], subplot=sp)
    scatter!([(vdcf,pdcf)],  markershape = :circle, markersize = 7, markercolor = :orange, markerstrokecolor = :blue, label = L"{\mathrm{final}}", subplot=sp)
    scatter!([(vdc,pdc)],  markershape = :star4, markersize = 7, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label = L"{\mathrm{contingency}}", subplot=sp)
    scatter!([(vdcr1,pdcr1)],  markershape = :x, markersize = 5, markercolor = :red, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=sp)
    # scatter!([(vdcr2,pdcr2)],  markershape = :x, markersize = 5, markercolor = :red, markeralpha = 1, markerstrokecolor = :gold, label = false, subplot=sp)
    # scatter!([(vdcr3,pdcr3)],  markershape = :x, markersize = 5, markercolor = :red, markeralpha = 1, markerstrokecolor = :gold, label = false, subplot=sp)
    plot!(xlabel=L"{V^{\mathrm{dc}}_e(\mathrm{p.u})}", labelfontsize= 10,subplot=sp)
    plot!(ylabel=L"{{P^{\mathrm{cv,dc}}_c}^ϵ(\mathrm{p.u})}", labelfontsize= 10, subplot=sp)
    plot!(title=L"{\mathrm{Converter}\;3}", titlefontsize= 10, subplot=sp)

   # legend
    # scatter!((1:3'), xlim = (4,5), markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", legend=:topleft, framestyle = :none, subplot=8)
    # scatter!((1:3'), xlim = (4,5), markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label = L"{\mathrm{final}}", subplot=8)
    # scatter!((1:3'), xlim = (4,5), markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label = L"{\mathrm{contingencies}}", subplot=8)
    # scatter!((1:3'), xlim = (4,5), markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=8)
    # scatter!((1:3'), xlim = (4,5), markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=8)

savefig(plt, "./plots/droop_curve_case5acdc_sc_minlpf.png")


# gen P response Plot
f1(delta_k) = Pglb + ep_g * log( 1 + ( exp((Pgub-Pglb)/ep_g) / (1 + exp((Pgub - Pgo - alpha_g * delta_k)/ep_g)) ) )

plot(f1, delta_k_min, delta_k_max, ylims=[Pglb-0.1, Pgub+0.1])
plt = Plots.plot(layout=(1,2), size = (600,400), xformatter=:latex, yformatter=:latex, legend = :outertop)

sp=2
Pgo = result_ACDC_scopf_soft_ndc["base"]["solution"]["nw"]["0"]["gen"]["$sp"]["pg"]
Pgf = result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["0"]["gen"]["$sp"]["pg"]
Pgub = data["gen"]["$sp"]["pmax"]
Pglb = data["gen"]["$sp"]["pmin"]
alpha_g = data["gen"]["$sp"]["alpha"]
ep_g = data["gen"]["$sp"]["ep"] = 0.1
delta_kf = (Pgf .- Pgo)./alpha_g
delta_k_max = (Pgub .- Pgo)./alpha_g .+ 0.1
delta_k_min = (Pglb .- Pgo)./alpha_g .-0.1


Pgc = [nw["gen"]["$sp"]["pg"] for (j, nw) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"] if j !=="0" && haskey(nw["gen"],"$sp")]
delta_kc = (Pgc .- Pgo) ./ alpha_g

# Pgcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["branch1"]["solution"]["gen"]["$sp"]["pg"]
# delta_kcr1 = (Pgcr1 .- Pgo) ./ alpha_g

# Pgcr2 = result_ACDC_scopf_re_dispatch_oltc_pst["branch2"]["solution"]["gen"]["$sp"]["pg"]
# delta_kcr2 = (Pgcr2 .- Pgo) ./ alpha_g

# Pgcr3 = result_ACDC_scopf_re_dispatch_oltc_pst["convdc2"]["solution"]["gen"]["$sp"]["pg"]
# delta_kcr3 = (Pgcr3 .- Pgo) ./ alpha_g
 

using Plots.PlotMeasures

# vspan!([delta_k_min+0.09, delta_k_max-0.09], linecolor = :lightgrey, fillcolor = :grey90, label = false, subplot=sp)
# Plots.hline!([Pglb, Pgub], xlims=[delta_k_min, delta_k_max], linestyle = :dash, linecolor = :grey0, label = false, subplot=sp)
# Plots.vline!([0, Pgub], linestyle = :dash, linecolor = :grey0, label = false, subplot=sp)
Plots.plot!(f1, delta_k_min, delta_k_max, ylims=[Pglb-0.1, Pgub+0.1], xformatter=:latex, yformatter=:latex, linewidth=1,color="black", dpi = 600, label = false, legend = :outertop, legend_columns= -1, grid = true, gridalpha = 0.5, gridstyle = :dash, subplot=sp)  # left_margin = 8mm, right_margin = 2mm, legend = :outerright, legend_columns= -1,
# Plots.annotate!([(delta_k_max-0.08,Pglb+0.15, (L"\Re\;(s^\mathrm{gl}_n)", :black, :left, 12))], subplot=sp)
# Plots.annotate!([(delta_k_min+0.01,Pgub-0.15, (L"\Re\;(s^\mathrm{gu}_n)", :black, :left, 12))], subplot=sp)
Plots.scatter!([(0,Pgo)], markershape = :rect, markersize = 8, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", subplot=sp)
Plots.scatter!([(delta_kf, Pgf)], markershape = :circle, markersize = 7, markercolor = :orange, markerstrokecolor = :blue, label =L"{\mathrm{final}}", subplot=sp)
Plots.scatter!([(delta_kc,Pgc)], markershape = :star4, markersize = 7, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label =L"{\mathrm{contingency}}", subplot=sp)
# Plots.scatter!([(delta_kcr1,Pgcr1)], markershape = :x, markersize = 5, markercolor = :red, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=sp)
# Plots.scatter!([(delta_kcr2,Pgcr2)], markershape = :x, markersize = 5, markercolor = :red, markeralpha = 1, markerstrokecolor = :gold, label = false, subplot=sp)
# Plots.scatter!([(delta_kcr3,Pgcr3)], markershape = :x, markersize = 5, markercolor = :red, markeralpha = 1, markerstrokecolor = :gold, label = false, subplot=sp)
Plots.plot!(xlabel=L"{\Delta_k}", labelfontsize= 10,subplot=sp)
Plots.plot!(ylabel=L"{\Re\;(S^{\mathrm{g}}_{nk})^{\epsilon}(\mathrm{p.u})}", labelfontsize= 10, subplot=sp)

Plots.plot!(title=L"{\mathrm{Generator}\;1}", titlefontsize= 10, subplot=1)
Plots.plot!(title=L"{\mathrm{Generator}\;2}", titlefontsize= 10, subplot=2)
Plots.annotate!([(-0.15586725907245516,1.25, (L"\alpha = 15.92", :black, :left, 12))], subplot=1)
Plots.annotate!([(-0.07,1.5, (L"\alpha = 11.09", :black, :left, 12))], subplot=2)

# Plots.scatter!((1:3'), xlim = (4,5), markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", legend=:topleft, framestyle = :none, subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label =L"{\mathrm{final}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label =L"{\mathrm{contingencies}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=18)
 

savefig(plt, "./plots/genp_response_case5acdc_sc_ndcf.png")


# gen Q response Plot
f5(qg) =  Vmo + ep_g*log(1 + exp(((vmub-Vmo) - qg + qglb)/ep_g)) -  ep_g*log(1 + exp(((Vmo-vmlb) + qg - qgub)/ep_g))
f2(qg) =  (qg < qglb ? (Vmo + (vmub-Vmo)) : qg > qgub ? (Vmo - (Vmo-vmlb)) : Vmo)

plt = Plots.plot(layout=(1,2), size = (600,400), xformatter=:latex, yformatter=:latex, legend = :outertop)

sp=2
vmub = 1.1
vmlb = 0.9
ep_g = data["gen"]["$sp"]["ep"] = 0.001
gen_bus = data["gen"]["$sp"]["gen_bus"]
qgb = result_ACDC_scopf_soft_ndc["base"]["solution"]["nw"]["0"]["gen"]["$sp"]["qg"]
qgo = result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["0"]["gen"]["$sp"]["qg"]
Vmb = result_ACDC_scopf_soft_ndc["base"]["solution"]["nw"]["0"]["bus"]["$gen_bus"]["vm"]
Vmo = result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["0"]["bus"]["$gen_bus"]["vm"]

qgub = data["gen"]["$sp"]["qmax"]
qglb = data["gen"]["$sp"]["qmin"] 


Vmc = [nw["bus"]["$gen_bus"]["vm"] for (j, nw) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"] if j!=="0" && haskey(nw["gen"],"$sp")]
qgc = [nw["gen"]["$sp"]["qg"] for (j, nw) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"] if j!=="0" && haskey(nw["gen"],"$sp")]

# qgcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["gen"]["$i"]["qg"]
# Vmcr1 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["bus"]["$gen_bus"]["vm"]

# qgcr2 = result_ACDC_scopf_re_dispatch_ots_oltc_pst["solution"]["gen"]["$i"]["qg"]
# Vmcr2 = result_ACDC_scopf_re_dispatch_oltc_pst["solution"]["bus"]["$gen_bus"]["vm"]


using Plots.PlotMeasures
# vspan!([qglb, qgub], ylims = [vmlb, vmub], linecolor = :lightgrey, fillcolor = :grey90, label = false, subplot=sp)
# Plots.vline!([qglb, qgub], ylims = [vmlb, vmub], linestyle = :dash, linecolor = :grey0, label = false, subplot=sp) # xlims=[delta_k_min, delta_k_max]
# Plots.hline!([vmlb, vmub], xlims = [qglb-0.5, qgub+0.5], linestyle = :dash, linecolor = :grey0, label = false, subplot=sp)
Plots.plot!(f5, qglb, qgub, xlims=[qglb-1, qgub+1], ylims = [vmlb-0.05, vmub+0.05], xformatter=:latex, yformatter=:latex, linewidth=1,color="black", dpi = 600, label = false, legend = :outertop, legend_columns= -1, grid = true, gridalpha = 0.5, gridstyle = :dash, subplot=sp)  #  ylims=[0, Pgub+1] legend = :outerright, legend_columns= -1, left_margin = 9mm, right_margin = 2mm,
# Plots.annotate!([(qglb,vmlb+0.1, (L"\Im(s^\mathrm{gl}_n)", :black, :left, 12))], subplot=1)
# Plots.annotate!([(qgub-3,vmub-0.1, (L"\Im(s^\mathrm{gu}_n)", :black, :left, 12))], subplot=1)
# Plots.annotate!([(qglb+0.2,vmlb+0.1, (L"\Im(s^\mathrm{gl}_n)", :black, :left, 12))], subplot=2)
# Plots.annotate!([(qgub-2,vmub-0.1, (L"\Im(s^\mathrm{gu}_n)", :black, :left, 12))], subplot=2)
# Plots.annotate!([(0,vmlb, (L"v^{l}_i", :black, :left, 12))], subplot=sp)
# Plots.annotate!([(0,vmub+0.02, (L"v^{u}_i", :black, :left, 12))], subplot=sp)
Plots.scatter!([(qgb,Vmb+0.003)], markershape = :rect, markersize = 8, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", subplot=sp)
Plots.scatter!([(qgo,Vmo)], markershape = :circle, markersize = 7, markercolor = :orange, markerstrokecolor = :blue, label =L"{\mathrm{final}}", subplot=sp)
Plots.scatter!([(qgc,Vmc)], markershape = :star4, markersize = 7, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label =L"{\mathrm{contingencies}}", subplot=sp)

# Plots.scatter!([(qgcr1,Vmcr1)], markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=sp)
# Plots.scatter!([(qgcr2,Vmcr2)], markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=sp)
    

Plots.plot!(xlabel=L"{\Im(S^{\mathrm{g}}_{n})^{\epsilon}(\mathrm{p.u})}", labelfontsize= 10,subplot=sp)
Plots.plot!(ylabel=L"{|V_i|(\mathrm{p.u})}", labelfontsize= 10, subplot=sp)
str = string(sp) 
Plots.plot!(title=L"{\mathrm{Generator}\;%$str}", titlefontsize= 10, subplot=sp)


# Plots.scatter!((1:3'), xlim = (4,5), markershape = :rect, markersize = 7, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{final}\;case\;0}", legend=:topleft, framestyle = :none, subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :circle, markersize = 6, markercolor = :orange, markerstrokecolor = :blue, label =L"{\mathrm{final}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :star4, markersize = 4, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label =L"{\mathrm{contingencies}\;cases\;1,2,...}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :rtriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch}}", subplot=18)
# Plots.scatter!((1:3'), xlim = (4,5), markershape = :ltriangle, markersize = 5, markercolor = :Blue, markeralpha = 1, markerstrokecolor = :gold, label = L"{\mathrm{re-dispatch + OTS}}", subplot=18)
 

Plots.savefig(plt, "./plots/genq_response_case5acdc_sc_ndcpf.png")


for j = 0:1:3

    println("nw=\t $j\n")

    for (i, bus) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["$j"]["bus"]
        println("pb_ac_pos_vio =", bus["pb_ac_pos_vio"], "\t pb_ac_neg_vio =", bus["pb_ac_neg_vio"], "\t qb_ac_pos_vio =", bus["qb_ac_pos_vio"],"\t qb_ac_neg_vio =", bus["qb_ac_neg_vio"])
    end
    for (i, branch) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["$j"]["branch"]
        println("bf_vio_fr =", branch["bf_vio_fr"], "\t bf_vio_to =", branch["bf_vio_to"])
    end
    for (i, busdc) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["$j"]["busdc"]
        println("pb_dc_pos_vio =", busdc["pb_dc_pos_vio"])
    end
    for (i, branchdc) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["$j"]["branchdc"]
        println("bdcf_vio_fr =", branchdc["bdcf_vio_fr"], "\t bdcf_vio_to =", branchdc["bdcf_vio_to"])
    end
end

for j = 0:1:3

    println("nw=\t $j\n")

    for (i, bus) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["$j"]["bus"]
        println("pb_ac_pos_vio =", bus["pb_ac_pos_vio"], "\t pb_ac_neg_vio =", bus["pb_ac_neg_vio"], "\t qb_ac_pos_vio =", bus["qb_ac_pos_vio"],"\t qb_ac_neg_vio =", bus["qb_ac_neg_vio"])
    end
    for (i, branch) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["$j"]["branch"]
        println("bf_vio_fr =", branch["bf_vio_fr"], "\t bf_vio_to =", branch["bf_vio_to"])
    end
    for (i, busdc) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["$j"]["busdc"]
        println("pb_dc_pos_vio =", busdc["pb_dc_pos_vio"])
    end
    for (i, branchdc) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["$j"]["branchdc"]
        println("bdcf_vio_fr =", branchdc["bdcf_vio_fr"], "\t bdcf_vio_to =", branchdc["bdcf_vio_to"])
    end
end


# nw =1 
# nlp,  pb_ac_neg_vio = 0.1417526858662829, cost = 70876.34293314145
# minlp, pb_ac_neg_vio = 0.26747357787616727, cost = 133736.78893808363

gen_p_adp_ndc = sum([gen["pg"] for (i,gen) in result_ACDC_scopf_soft_ndc["base"]["solution"]["nw"]["0"]["gen"]] - [gen["pg"] for (i,gen) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["0"]["gen"]])
gen_q_adp_ndc = sum([gen["qg"] for (i,gen) in result_ACDC_scopf_soft_ndc["base"]["solution"]["nw"]["0"]["gen"]] - [gen["qg"] for (i,gen) in result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["0"]["gen"]])

gen_p_adp_minlp = sum([gen["pg"] for (i,gen) in result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["gen"]] - [gen["pg"] for (i,gen) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["gen"]])
gen_q_adp_minlp = sum([gen["qg"] for (i,gen) in result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["gen"]] - [gen["qg"] for (i,gen) in result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["gen"]])

line_loading_ac_base = []
for i=1:length(data["branch"])
push!(line_loading_ac_base, (sqrt(result_ACDC_scopf_soft_ndc["base"]["solution"]["nw"]["0"]["branch"]["$i"]["pf"]^2 + result_ACDC_scopf_soft_ndc["base"]["solution"]["nw"]["0"]["branch"]["$i"]["qf"]^2) /data["branch"]["$i"]["rate_c"] )*100)
end

line_loading_ac_final = []
for i=1:length(data["branch"])
push!(line_loading_ac_final, (sqrt(result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["0"]["branch"]["$i"]["pf"]^2 + result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["0"]["branch"]["$i"]["qf"]^2) /data["branch"]["$i"]["rate_c"] )*100)
end

line_loading_ac_re_dispatch = []
for i=2:length(data["branch"])
push!(line_loading_ac_re_dispatch, (sqrt(result_ACDC_scopf_re_dispatch_oltc_pst["branch1"]["solution"]["branch"]["$i"]["pt"]^2 + result_ACDC_scopf_re_dispatch_oltc_pst["branch1"]["solution"]["branch"]["$i"]["qt"]^2) / data["branch"]["$i"]["rate_c"]) * 100)
end

line_loading_dc_base = []
for i=1:length(data["branchdc"])
push!(line_loading_dc_base, (result_ACDC_scopf_soft_ndc["base"]["solution"]["nw"]["0"]["branchdc"]["$i"]["pf"] /data["branchdc"]["$i"]["rateC"] )*100)
end

line_loading_dc_final = []
for i=1:length(data["branchdc"])
push!(line_loading_dc_final, (result_ACDC_scopf_soft_ndc["final"]["solution"]["nw"]["0"]["branchdc"]["$i"]["pf"] /data["branchdc"]["$i"]["rateC"] )*100)
end

line_loading_dc_re_dispatch = []
for i=1:length(data["branchdc"])
push!(line_loading_dc_re_dispatch, result_ACDC_scopf_re_dispatch_oltc_pst["branch1"]["solution"]["branchdc"]["$i"]["pf"] / data["branch"]["$i"]["rate_c"] * 100)
end

line_loading_ac_base_minlp = []
for i=1:length(data["branch"])
push!(line_loading_ac_base_minlp, (sqrt(result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["branch"]["$i"]["pf"]^2 + result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["branch"]["$i"]["qf"]^2) /data["branch"]["$i"]["rate_c"] )*100)
end

line_loading_ac_final_minlp = []
for i=1:length(data["branch"])
push!(line_loading_ac_final_minlp, (sqrt(result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["branch"]["$i"]["pf"]^2 + result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["branch"]["$i"]["qf"]^2) /data["branch"]["$i"]["rate_c"] )*100)
end

line_loading_dc_base_minlp = []
for i=1:length(data["branchdc"])
push!(line_loading_dc_base_minlp, (result_ACDC_scopf_soft_minlp["base"]["solution"]["nw"]["0"]["branchdc"]["$i"]["pf"] /data["branchdc"]["$i"]["rateC"] )*100)
end

line_loading_dc_final_minlp = []
for i=1:length(data["branchdc"])
push!(line_loading_dc_final_minlp, (result_ACDC_scopf_soft_minlp["final"]["solution"]["nw"]["0"]["branchdc"]["$i"]["pf"] /data["branchdc"]["$i"]["rateC"] )*100)
end



