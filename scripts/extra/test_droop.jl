
using Ipopt
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained

const _PM = PowerModels
const _PMACDC = PowerModelsACDC
const _PMSC = PowerModelsSecurityConstrained
const _PMACDCSC = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "constr_viol_tol" => 0.000001) 



file = "./data/case5_acdc.m"
file = "./data/snem2000_acdc.m"
data = _PM.parse_file(file)
_PMACDCSC.fix_scopf_data_case5_acdc!(data)
_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true) 

result = _PMACDC.run_sacdcpf(data)
result = _PMACDC.run_acdcpf(data, _PM.ACPPowerModel, nlp_solver, setting = setting)

data["branch"]["1"]["rate_a"] = data["branch"]["1"]["rate_b"] = data["branch"]["1"]["rate_c"] = 0.3;
data["branch"]["2"]["rate_a"] = data["branch"]["2"]["rate_b"] = data["branch"]["2"]["rate_c"] = 0.35;
data["branch"]["5"]["rate_a"] = data["branch"]["5"]["rate_b"] = data["branch"]["5"]["rate_c"] = 0.3;

data["branchdc"]["1"]["rateA"] = data["branchdc"]["1"]["rateB"] = data["branchdc"]["1"]["rateC"] = 50;
data["branchdc"]["2"]["rateA"] = data["branchdc"]["2"]["rateB"] = data["branchdc"]["2"]["rateC"] = 50;
data["branchdc"]["3"]["rateA"] = data["branchdc"]["3"]["rateB"] = data["branchdc"]["3"]["rateC"] = 50;

data["gen_contingencies"] = []
data["branch_contingencies"] = []
# data["convdc_contingencies"] = [] 

for (i, conv) in data["convdc"]
    conv["ep"] = 0.1
end


result_scopf_droop_linear = _PMACDCSC.run_ACDC_scopf_contigency_cuts(data, _PM.ACPPowerModel, _PMACDCSC.run_scopf_soft, _PMACDCSC.check_contingency_violations_SI, nlp_solver, setting) 
result_scopf_droop_smooth = _PMACDCSC.run_ACDC_scopf_contigency_cuts(data, _PM.ACPPowerModel, _PMACDCSC.run_scopf_soft, _PMACDCSC.check_contingency_violations_SI, nlp_solver, setting) 



using Plots
using CalculusWithJulia
using LaTeXStrings
using Plots.PlotMeasures


f2(vdc) = ((pref_dc - (sign(pref_dc) * 1 / k_droop * (vdc -  Vdcset))) > pdcmax ? (pref_dc - (sign(pref_dc) * 1 / k_droop * (vdc_at_pdcmax -  Vdcset))) : (pref_dc - (sign(pref_dc) * 1 / k_droop * (vdc -  Vdcset))) < pdcmin ? (pref_dc - (sign(pref_dc) * 1 / k_droop * (vdc_at_pdcmin -  Vdcset))) : (pref_dc - (sign(pref_dc) * 1 / k_droop * (vdc -  Vdcset))))

f6(vdc) = pref_dc + sign(pref_dc)*( vdc> vdcmax ? (-1 / k_droop*(vdchigh -vdcmax)) : vdc > vdchigh && vdc <= vdcmax ? (-1 / k_droop * (vdchigh - vdc)) : vdc >= vdcmin && vdc < vdclow ? (-1 / k_droop * (vdclow - vdc)) : vdc < vdcmin ? (-1 / k_droop * (vdclow - vdcmin)) : 0)        
f7(vdc) = (f6(vdc)>=pdcmax ? sign(pref_dc)*f6(vdc_at_pdcmax) : f6(vdc)<=pdcmin ? sign(pref_dc)*f6(vdc_at_pdcmin) : f6(vdc))

f8(vdc) = (pref_dc - sign(pref_dc) * (   -((1 /  k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
        -(-(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
        -((1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - vdc + vdcmin)/ep)))
        -(-((1 / k_droop * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop * (2*vdcmin - vdc - vdclow) + 1 / k_droop * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep)))   ))
        )


# droop Curve Plot linear
pltl = Plots.plot(layout=(3,1), size = (600,600), xformatter=:latex, yformatter=:latex, legend = :outertop)
i = 3
    
    pref_dc = data["convdc"]["$i"]["Pdcset"] 
    Vdcset = data["convdc"]["$i"]["Vdcset"]
    vdcmax = data["convdc"]["$i"]["Vmmax"]
    vdcmin = data["convdc"]["$i"]["Vmmin"]
    vdchigh = data["convdc"]["$i"]["Vdchigh"] 
    vdclow = data["convdc"]["$i"]["Vdclow"]
    k_droop = data["convdc"]["$i"]["droop"] 
    ep = data["convdc"]["$i"]["ep"]
    pdcmax = 1.2*data["convdc"]["$i"]["Pacrated"]
    pdcmin = - pdcmax
    

    vdc_at_pdcmax = (pdcmax  - pref_dc) * (- sign(pref_dc) * k_droop) +  Vdcset
    vdc_at_pdcmin = (pdcmin  - pref_dc) * (- sign(pref_dc) * k_droop) +  Vdcset 
    
    y = zeros(length(0.85:0.001:1.15))
    j = 1
    for i = 0.85:0.001:1.15
        y[j] = f2(i) 
        j += 1
    end
 
    vdc = [nw["busdc"]["$i"]["vm"] for (j, nw) in result_scopf_droop_linear["final"]["solution"]["nw"] if j !="0"]
    pdc = [nw["convdc"]["$i"]["pdc"] for (j, nw) in result_scopf_droop_linear["final"]["solution"]["nw"] if j !="0" && haskey(nw["convdc"],"$i")]
    
    vdco = result_scopf_droop_linear["base"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
    pdco = result_scopf_droop_linear["base"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

    vdcf = result_scopf_droop_linear["final"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
    pdcf = result_scopf_droop_linear["final"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]
    
        
    plot!(y, 0.85:0.001:1.15, ylims =[0.75, 1.25], linewidth=1, color="black", dpi = 600, xformatter=:latex, yformatter=:latex, label = false, legend = :outertop, legend_columns= -1, grid = false, gridalpha = 0.5, gridstyle = :dash, subplot=i)  #framestyle = :box  #legend_columns= -1,
    scatter!([(pdco, vdco)],  markershape = :rect, markersize = 8, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", subplot=i)
    scatter!([(pdcf, vdcf)],  markershape = :circle, markersize = 7, markercolor = :orange, markerstrokecolor = :blue, label = L"{\mathrm{final}}", subplot=i)
    scatter!([(pdc, vdc)],  markershape = :star4, markersize = 7, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label = L"{\mathrm{contingency}}", subplot=i)
    plot!(xlabel=L"{V^{\mathrm{dc}}_e(\mathrm{p.u})}", labelfontsize= 10,subplot=i)
    plot!(ylabel=L"{{P^{\mathrm{cv,dc}}_c}^ϵ(\mathrm{p.u})}", labelfontsize= 10, subplot=i)
    s = string(i)
    plot!(title=L"{\mathrm{Converter}\;%$s}", titlefontsize= 10, subplot=i)
    savefig(pltl, "./plots/case5_linear_k1.png")


# droop Curve Plot Smooth
plts = Plots.plot(layout=(3,1), size = (600,800), xformatter=:latex, yformatter=:latex, legend = :outertop)
i = 1

    pref_dc = result_scopf_droop_smooth["db"]["$i"]["Pdcset"] 
    Vdcset = result_scopf_droop_smooth["db"]["$i"]["Vdcset"]
    vdcmax = data["convdc"]["$i"]["Vmmax"]
    vdcmin = data["convdc"]["$i"]["Vmmin"]
    vdchigh = result_scopf_droop_smooth["db"]["$i"]["Vdchigh"]
    vdclow = result_scopf_droop_smooth["db"]["$i"]["Vdclow"]
    k_droop = data["convdc"]["$i"]["droop"]
    ep = data["convdc"]["$i"]["ep"]
    pdcmax = 1.2*data["convdc"]["$i"]["Pacrated"]
    pdcmin = - pdcmax
    

    vdc_at_pdcmax = vdchigh + k_droop * (pdcmax - sign(pref_dc)*pref_dc)  
    vdc_at_pdcmin = vdclow + k_droop * (pdcmin - sign(pref_dc)*pref_dc)  
    
    y = zeros(length(0.85:0.001:1.15))
    j = 1
    for i = 0.85:0.001:1.15
        y[j] = f7(i) 
        j += 1
    end


    vdc = [nw["busdc"]["$i"]["vm"] for (j, nw) in result_scopf_droop_smooth["final"]["solution"]["nw"] if j !="0"]
    pdc = [nw["convdc"]["$i"]["pdc"] for (j, nw) in result_scopf_droop_smooth["final"]["solution"]["nw"] if j !="0" && haskey(nw["convdc"],"$i")]
    
    vdco = result_scopf_droop_smooth["base"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
    pdco = result_scopf_droop_smooth["base"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]

    vdcf = result_scopf_droop_smooth["final"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
    pdcf = result_scopf_droop_smooth["final"]["solution"]["nw"]["0"]["convdc"]["$i"]["pdc"]
    

    plot!(y, 0.85:0.001:1.15, ylims =[0.85, 1.15], linewidth=1, color="blue", dpi = 600, xformatter=:latex, yformatter=:latex, label = false, legend = :outertop, legend_columns= -1, grid = false, gridalpha = 0.5, gridstyle = :dash, subplot=i)  #framestyle = :box  #legend_columns= -1,
    scatter!([(pdco, vdco)],  markershape = :rect, markersize = 8, markercolor = :skyblue, markerstrokecolor = :orange, label =L"{\mathrm{base}}", subplot=i)
    scatter!([(pdcf, vdcf)],  markershape = :circle, markersize = 7, markercolor = :orange, markerstrokecolor = :blue, label = L"{\mathrm{final}}", subplot=i)
    scatter!([(pdc, vdc)],  markershape = :star4, markersize = 7, markercolor = :LightSkyBlue, markeralpha = 1, markerstrokecolor = :MediumPurple, label = L"{\mathrm{contingency}}", subplot=i)
    plot!(xlabel=L"{{P^{\mathrm{cv,dc}}_c}^ϵ(\mathrm{p.u})}", labelfontsize= 10,subplot=i)
    plot!(ylabel=L"{V^{\mathrm{dc}}_e(\mathrm{p.u})}", labelfontsize= 10, subplot=i)
    s = string(i)
    plot!(title=L"{\mathrm{Converter}\;%$s}", titlefontsize= 10, subplot=i)
    savefig(plts, "./plots/case5_smooth_k1.png")


    vac_b = [result_scopf_droop_smooth["base"]["solution"]["nw"]["0"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_f = [result_scopf_droop_smooth["final"]["solution"]["nw"]["0"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_br3 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["1"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_br1 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["2"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_br2 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["3"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_cv1 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["4"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_cv3 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["5"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_cv2 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["6"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    
    vdc_b = [result_scopf_droop_smooth["base"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_f = [result_scopf_droop_smooth["final"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_br3 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["1"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_br1 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["2"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_br2 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["3"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_cv1 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["4"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_cv3 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["5"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_cv2 = [result_scopf_droop_smooth["final"]["solution"]["nw"]["6"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]

    vac_b = [result_scopf_droop_linear["base"]["solution"]["nw"]["0"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_f = [result_scopf_droop_linear["final"]["solution"]["nw"]["0"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_br3 = [result_scopf_droop_linear["final"]["solution"]["nw"]["1"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_br1 = [result_scopf_droop_linear["final"]["solution"]["nw"]["2"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_br2 = [result_scopf_droop_linear["final"]["solution"]["nw"]["3"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_cv1 = [result_scopf_droop_linear["final"]["solution"]["nw"]["4"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_cv3 = [result_scopf_droop_linear["final"]["solution"]["nw"]["5"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    vac_cv2 = [result_scopf_droop_linear["final"]["solution"]["nw"]["6"]["bus"]["$i"]["vm"] for i = 1:length(data["bus"])]
    
    vdc_b = [result_scopf_droop_linear["base"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_f = [result_scopf_droop_linear["final"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_br3 = [result_scopf_droop_linear["final"]["solution"]["nw"]["1"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_br1 = [result_scopf_droop_linear["final"]["solution"]["nw"]["2"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_br2 = [result_scopf_droop_linear["final"]["solution"]["nw"]["3"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_cv1 = [result_scopf_droop_linear["final"]["solution"]["nw"]["4"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_cv3 = [result_scopf_droop_linear["final"]["solution"]["nw"]["5"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]
    vdc_cv2 = [result_scopf_droop_linear["final"]["solution"]["nw"]["6"]["busdc"]["$i"]["vm"] for i = 1:length(data["busdc"])]


    plot(vac_b, label = L"{\mathrm{base}}")
    plot!(vac_f, label = L"{\mathrm{final}}")
    plot!(vac_br3, label = L"{\mathrm{branchdc\;3\;contingency}}")
    plot!(vac_br1, label = L"{\mathrm{branchdc\;1\;contingency}}")
    plot!(vac_br2, label = L"{\mathrm{branchdc\;2\;contingency}}")
    plot!(vac_cv1, label = L"{\mathrm{convdc\;1\;contingency}}")
    plot!(vac_cv3, label = L"{\mathrm{convdc\;3\;contingency}}")
    plot!(vac_cv2, label = L"{\mathrm{convdc\;2\;contingency}}")
    plot!(ylabel=L"{V^{\mathrm{ac}}_i(\mathrm{p.u})}")
    plot!(xlabel=L"{i(-)}")
    savefig("./plots/case5_nodroop_vac.png")

    
    plot(vdc_b, label = L"{\mathrm{base}}")
    plot!(vdc_f, label = L"{\mathrm{final}}")
    plot!(vdc_br3, label = L"{\mathrm{branchdc\;3\;contingency}}")
    plot!(vdc_br1, label = L"{\mathrm{branchdc\;1\;contingency}}")
    plot!(vdc_br2, label = L"{\mathrm{branchdc\;2\;contingency}}")
    plot!(vdc_cv1, label = L"{\mathrm{convdc\;1\;contingency}}")
    plot!(vdc_cv3, label = L"{\mathrm{convdc\;3\;contingency}}")
    plot!(vdc_cv2, label = L"{\mathrm{convdc\;2\;contingency}}")
    plot!(ylabel=L"{V^{\mathrm{dc}}_e(\mathrm{p.u})}")
    plot!(xlabel=L"{e(-)}")
    
    savefig("./plots/case5_nodroop_vdc.png")



