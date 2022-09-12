############################################# Base Case Plots ################################################
using Plots
const _P = Plots

result = result_ACDC_scopf_exact

### gen
pg_l = Dict(i => gen["pmax"] for (i, gen) in data["gen"])
pg_u = Dict(i => gen["pmax"] for (i, gen) in data["gen"])
qg_l = Dict(i => gen["qmin"] for (i, gen) in data["gen"])
qg_u = Dict(i => gen["qmax"] for (i, gen) in data["gen"])

pg_b = Dict(i => gen["pg"] for (i, gen) in result["base"]["solution"]["nw"]["0"]["gen"])
qg_b = Dict(i => gen["qg"] for (i, gen) in result["base"]["solution"]["nw"]["0"]["gen"])

### bus
vm_ac_b = Dict(i => bus["vm"] for (i, bus) in result["base"]["solution"]["nw"]["0"]["bus"])
va_ac_b = Dict(i => bus["va"] for (i, bus) in result["base"]["solution"]["nw"]["0"]["bus"])
vm_dc_b = Dict(i => bus["vm"] for (i, bus) in result["base"]["solution"]["nw"]["0"]["busdc"])

### branch
pf_b = Dict(i => branch["pf"] for (i, branch) in result["base"]["solution"]["nw"]["0"]["branch"])
pt_b = Dict(i => branch["pt"] for (i, branch) in result["base"]["solution"]["nw"]["0"]["branch"])
qf_b = Dict(i => branch["qf"] for (i, branch) in result["base"]["solution"]["nw"]["0"]["branch"])
qt_b = Dict(i => branch["qt"] for (i, branch) in result["base"]["solution"]["nw"]["0"]["branch"])
s_u = Dict(i => branch["rate_c"] for (i, branch) in data["branch"])

ploss_b = Dict(i => pf + pt_b[i] for (i,pf) in pf_b)
qloss_b = Dict(i => qf + qt_b[i] for (i,qf) in qf_b)
sloss_b = Dict(i => ploss^2 + qloss_b[i]^2 for (i,ploss) in ploss_b)

sf_b = Dict(i => sqrt(pf^2 + qf_b[i]^2) for (i,pf) in pf_b)
st_b = Dict(i => sqrt(pt^2 + qt_b[i]^2) for (i,pt) in pt_b)
s_b = Dict(i => max(sf, st_b[i]) for (i,sf) in sf_b)

If_b = [sqrt(pf_b[i]^2 + qf_b[i]^2) * data["baseMVA"] /  (vm_ac_b["$(branch["f_bus"])"] * data["bus"]["$(branch["f_bus"])"]["base_kv"]) for (i, branch) in data["branch"] ]

### branchdc
pfdc_b = Dict(i => branchdc["pf"] for (i, branchdc) in result["base"]["solution"]["nw"]["0"]["branchdc"])
ptdc_b = Dict(i => branchdc["pt"] for (i, branchdc) in result["base"]["solution"]["nw"]["0"]["branchdc"])
sdc_u = Dict(i => branchdc["rateC"] for (i, branchdc) in data["branchdc"])
sdc_b = Dict(i => max(pfdc, ptdc_b[i]) for (i,pfdc) in pfdc_b)
pdcloss_b = Dict(i => pfdc + ptdc_b[i] for (i,pfdc) in pfdc_b)

Ifdc_b = [pfdc_b[i] * data["baseMVA"] / (vm_dc_b["$(branchdc["fbusdc"])"] * data["busdc"]["$(branchdc["fbusdc"])"]["basekVdc"]) for (i, branchdc) in data["branchdc"] ]

###

plot(parse.(Int,(keys(vm_ac_b))), values(vm_ac_b), seriestype = :scatter, color = "blue", label = "vm_ac_b", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [0.85,1.15],  title = "Voltage Magnitude Base Case")        # framestyle = :box,
plot!(vm_dc_b, seriestype = :scatter, color = "red", label = "vm_dc_b")
plot!(ones(67)*1.1, linestyle = :dash, color = "blue", label = false)
plot!(ones(67)*0.9, linestyle = :dash, color = "blue", label = false)
plot!(ones(9)*1.05, linestyle = :dash, color = "red", label = false)
plot!(ones(9)*0.95, linestyle = :dash, color = "red", label = false)
xlabel!("Bus No.")
ylabel!("Voltage (p.u)")
savefig("vm_b_plot.png")

########### Voltage angle
plot(x, va_ac_b, seriestype = :scatter, color = "blue", label = "va_ac_b", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-pi/8, pi/8], title = "Voltage Angle Base Case")        # framestyle = :box,
plot!(ones(67)*pi/12, linestyle = :dash, color = "blue", label = false)
plot!(ones(67)*-pi/12, linestyle = :dash, color = "blue", label = false)
xlabel!("Bus No.")
ylabel!("Angle (Rad)")
savefig("va_b_plot.png")

########### Active/Reactive Power Generators
plot(pg_b, seriestype = :bar, bar_width = 0.4, color = "blue", label = "pg_b", grid = true, gridalpha = 0.2, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-10, 16], title = "Active & Reactive Power of Generators")
plot!(qg_b,seriestype = :bar, bar_width = 0.4, color = "brown",label = "qg_b")
plot!(pg_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
plot!(pg_l, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
plot!(qg_u, seriestype = :stepmid, linestyle = :dash, color = "brown", label = false)
plot!(qg_l, seriestype = :stepmid, linestyle = :dash, color = "brown", label = false)
xlabel!("Generator No.")
ylabel!("Power (p.u)")
savefig("pg_qg_b_plot.png")

########### Active/Reactive branch flows
plot(pf_b, seriestype = :scatter, color = "blue", label = "pf_b", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-16, 16],title = "Active & Reactive Branch Flows")        # framestyle = :box,
plot!(qf_b, seriestype = :scatter, color = "red", label = "qf_b")
plot!(pfdc_b, seriestype = :scatter, color = "green", label = "pfdc_b")
xlabel!("Branch No.")
ylabel!("Power (p.u)")
savefig("pf_qf_pfdc_b_plot.png")

########### Branch flows
plot(s_b, seriestype = :scatter, color = "blue", label = "s_b", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-16, 16],title = "Branch Flows")        # framestyle = :box,
plot!(sdc_b, seriestype = :scatter, color = "red", label = "sdc_b")
plot!(s_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
plot!(-s_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
plot!(sdc_u, seriestype = :stepmid, linestyle = :dash, color = "red", label = false)
plot!(-sdc_u, seriestype = :stepmid, linestyle = :dash, color = "red", label = false)
xlabel!("Branch No.")
ylabel!("Power (p.u)")
savefig("s_sdc_b_plot.png")

########### Branch flow losses
plot(ploss_b, seriestype = :scatter, color = "blue", label = "ploss_b", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [0,1],title = "Branch Losses")        # framestyle = :box,
plot!(qloss_b, seriestype = :scatter, color = "red", label = "qloss_b")
plot!(sloss_b, seriestype = :scatter, color = "green", label = "sloss_b")
plot!(pdcloss_b, seriestype = :scatter, color = "black", label = "pdcloss_b")
xlabel!("Branch No.")
ylabel!("Power (p.u)")
savefig("pqsloss_pdcloss_b_plot.png")
########### Branch Currents
plot(If_b*1000, seriestype = :scatter, color = "blue", label = "If_b", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [],title = "Branch Currents")        # framestyle = :box,
plot!(Ifdc_b*1000, seriestype = :scatter, color = "red", label = "Ifdc_b")
plot!(ones(102)*3500, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
plot!(-ones(102)*3500, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
xlabel!("Branch No.")
ylabel!("Current (A)")
savefig("If_Ifdc_b_plot.png")