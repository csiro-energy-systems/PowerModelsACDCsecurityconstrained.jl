##
f0(vdc) = (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))
f0new(vdc) = (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - (vdcmax - vdc)*(vdc-vdchigh))/ep))
f0d(vdc) = -f0(vdc)

f(v, v1, p1, R) =  R * (v1 - v) + p1
g(v, v1, v2) = (v - v1) * (v - v2)
h(v, v1, v2, R, p1, ep) = f(v, v1, p1, R) - ep * log( 1 + exp( (f(v, v1, p1, R) - g(v, v1, v2)) / ep) )

vrange = collect(0.8:0.01:1.2)
plot(vrange, [h(v, 1.02, 1.1, 50, 2, 1E-2) for v in vrange])

pmin = -3
pmax = 3
p0 = 1
vmax = 1.1
vhigh = 1.02
vlow = 0.98
vmin = 0.9

R1 = (pmax-p0) / (vmax-vhigh)
R2 = (p0-pmin) / (vlow-vmin)

# curve = -h(v, vhigh, vmax, R1, p0, 1E-2) + h(v, vmax, vmax+0.1, R1, p0, 1E-2)
#         h(2-v, vlow, vmin, R2, p0, 1E-2) + h(2-v, vmin, vmin-0.1, R2, p0, 1E-2)

plot(vrange, -[h(v, vhigh, vmax, R1, p0, 1E-2) for v in vrange])
plot(vrange, [h(2-v, vlow, vmin, R2, p0, 1E-2) for v in vrange])
plot(vrange, [h(2-v, vmin, vmin-0.1, R2, p0, 1E-2) for v in vrange])


plot(vrange, [-h(v, vhigh, vmax, R1, p0, 1E-2) + h(v, vmax, vmax+0.1, R1, p0, 1E-2)  for v in vrange] .+ p0)
plot!(vrange, [-h(2-v, vmin, vlow, R2, p0, 1E-2) + h(2-v, vmin-0.1, vmin, R2, p0, 1E-2)  for v in vrange] .+ p0)

plot(vrange, [-h(2-v, vlow, vmin, R2, p0, 1E-2)  for v in vrange] .+ p0)
plot!(vrange, [ h(2-v, vmin+0.1, vmin, R2, p0, 1E-2)  for v in vrange] .+ p0)

plot(vrange, [-h(v, vhigh, vmax, R1, p0, 1E-2) + h(v, vmax, vmax+0.1, R1, p0, 1E-2) - h(2-v, vmin, vlow, R2, p0, 1E-2) + h(2-v, vlow, vmin-0.1, R2, p0, 1E-2) .+ 2*p0  for v in vrange])



f0n(vdc) = -(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep))

f0n(vdc) = -f0(vdc+(vdchigh - vdcmax))
# f0n(vdc) = (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) + vdchigh - vdc)/ep))
plot(f0, 0.89, 1.11)
plot!(f0d, 0.89, 1.11)
plot(f0n, 0.89, 1.11)


# f1(vdc) = (1 / k_droop * (vdchigh - vdc)) - ep*log(1 + exp(((1 / k_droop * (vdchigh - vdc)) - (vdc - (vdcmax - epsilon)) * (vdc - (vdchigh + epsilon)))/ep))
# plot!(f1, 0.89, 1.11)
ep = 1
a=0
k_droop1 = 0.005
k_droop  = 0.005
f1(vdc) = (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))
plot(f1, 0.8, 1.2)
# f2(vdc) =  (1 / k_droop * (vdchigh - vdc)) - ep*log(1 + exp(((1 / k_droop * (vdchigh - vdc)) - (vdc - (vdcmax - epsilon)) * (vdc - (vdchigh + epsilon)))/ep)) 
# plot!(f2, 0.8, 1.2)   
# f3(vdc) =  - ep*log(1 + exp((- (vdc - vdchigh) * (vdc - vdclow))/ep)) 
# plot!(f3, 0.8, 1.2) 
# f4(vdc) =  (1 / k_droop * (vdclow - vdc)) - ep*log(1 + exp(((1 / k_droop * (vdclow - vdc)) - (vdc - (vdclow - epsilon)) * (vdc - (vdcmin + epsilon)))/ep))
# plot!(f4, 0.8, 1.2) 
# f5(vdc) =  (1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - ep*log(1 + exp(((1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - vdc + vdcmin)/ep))
# plot!(f5, 0.8, 1.2)

# f_tot(vdc) = f1(vdc) + f2(vdc) + f3(vdc) + f4(vdc) + f5(vdc)
# plot!(f_tot, 0.8, 1.2)

f1n(vdc) = -(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep))
plot(f1n, 0.8, 1.2)
f1n(vdc) = -f1(vdc+(vdchigh - vdcmax))

f2(vdc) = (1 / k_droop1 * (vdcmin - vdc) + 1 / k_droop1 * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop1 * (vdcmin - vdc) + 1 / k_droop1 * (vdclow - vdcmin)) - vdc + vdcmin)/ep))
plot(f2, 0.8, 1.2)
f2n(vdc) = -((1 / k_droop1 * (2*vdcmin - vdc - vdclow) + 1 / k_droop1 * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop1 * (2*vdcmin - vdc - vdclow) + 1 / k_droop1 * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep)))
plot(f2n, 0.8, 1.2)

f2n(vdc) = -f2(vdc - vdcmin + vdclow)

f_tot(vdc) = -f1(vdc) - f1n(vdc) - f2(vdc) - f2n(vdc)
plot(f_tot, 0.8, 1.2)

f_tot2(vdc) =  -f1n(vdc) - f2n(vdc)
plot!(f_tot2, 0.8, 1.2)

f_tot3(vdc) =  -f1(vdc) - f2(vdc)
plot(f_tot3, 0.8, 1.2)

f_tot4(vdc) = -f1(vdc) - f1n(vdc) - f2(vdc) - f2n(vdc) + 5
plot!(f_tot4, 0.8, 1.2)

f_tot3(vdc) = (   -((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
-(-(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
-((1 / k_droop1 * (vdcmin - vdc) + 1 / k_droop1 * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop1 * (vdcmin - vdc) + 1 / k_droop1 * (vdclow - vdcmin)) - vdc + vdcmin)/ep)))
-(-((1 / k_droop1 * (2*vdcmin - vdc - vdclow) + 1 / k_droop1 * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop1 * (2*vdcmin - vdc - vdclow) + 1 / k_droop1 * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep)))   ))

ft(vdc) = -((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax)) - ep * log(1 + exp(((1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - vdcmax + vdc)/ep))) 
        -(-(1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax)) + ep * log(1 + exp(((1 / k_droop * (2*vdcmax - vdchigh - vdc) + 1 / k_droop * (vdchigh - vdcmax) ) - 2*vdcmax + vdchigh + vdc)/ep)) )
        -((1 / k_droop1 * (vdcmin - vdc) + 1 / k_droop1 * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop1 * (vdcmin - vdc) + 1 / k_droop1 * (vdclow - vdcmin)) - vdc + vdcmin)/ep)))
        -(-((1 / k_droop1 * (2*vdcmin - vdc - vdclow) + 1 / k_droop1 * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop1 * (2*vdcmin - vdc - vdclow) + 1 / k_droop1 * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep)))   )

plot(f_tot3, 0.8, 1.2)

plot(f2,  0.89, 1.11)
plot(f2n, 0.89, 1.11)

f(vdc) = f0(vdc) + f2(vdc)
f_tot(vdc) = f0(vdc) +  f0n(vdc) + f2(vdc) + f2n(vdc)
f_tot2(vdc) = -f0(vdc) -  f0n(vdc) - f2(vdc) - f2n(vdc)
plot(f,  0.89, 1.11)
plot(f_tot, 0.8, 1.2)
plot!(f_tot2,  0.8, 1.2)
plot!(f_tot3,  0.8, 1.2)


#@constraint(model, [m1 in M, m2 in M], y[m1,m2] >= z[m1]*(m1 !== m2))

# f3(vdc) = (1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - ep*log(1 + exp(((1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin)) - vdc + vdcmin)/ep))
# plot!(f3,  0.89, 1.11)


function droop_curve(vdc, pconv_dc_base)
    if vdc >= vdcmax
        return (1 / k_droop * (vdcmax - vdc) + 1 / k_droop * (vdchigh - vdcmax) + pconv_dc_base)
    elseif vdc < vdcmax && vdc > vdchigh
        return (1 / k_droop * (vdchigh - vdc) + pconv_dc_base)
    elseif vdc <= vdchigh && vdc >= vdclow
        return pconv_dc_base
    elseif vdc < vdclow && vdc > vdcmin
        return (1 / k_droop * (vdclow - vdc) + pconv_dc_base)
    elseif vdc <= vdcmin
        return (1 / k_droop * (vdcmin - vdc) + 1 / k_droop * (vdclow - vdcmin) + pconv_dc_base)
    end
end

vdc = 0.8:0.1:1.2
pconv_dc_base = 10
plot!(i, droop_curve.(vdc, pconv_dc_base))
# #huber(a,delta)= abs(a) <= delta ? 1/2*a^2 : delta*(abs(a)-1/2*delta)
# i = 0.89:0.01:1.11
# plot!(i, droop_curve.(i, 0))
# scatter!([(vdc_final,pconv_dc_final)], markershape = :cross, markersize = 10, markercolor = :red)

# qglb = data["gen"]["1"]["qmin"]
# qgub = data["gen"]["1"]["qmax"]
# vm_pos = 0.2
# vm_neg = 0.2
# ep = 0.001

# fv1(qg) = vm_pos - ep*log(1 + exp((vm_pos - qg + qglb)/ep)) 
# fv2(qg) = vm_neg - ep*log(1 + exp((vm_neg + qg - qgub)/ep)) 

# vdcmax = 5
# vdcmin = 4
# vdchigh = 3
# vdclow = 0


# f0new2(vdc) = 0.08 - ep*log(1 + exp((0.08 - vdcmax + vdc)/ep))
# f0new3(vdc) = 0.08 - ep*log(1 + exp((0.08 + vdchigh - vdc)/ep))

# f0new4(vdc) = 0.08 - ep*log(1 + exp((0.08 - vdclow + vdc)/ep))
# f0new5(vdc) = 0.08 - ep*log(1 + exp((0.08 + vdcmin - vdc)/ep))


# fv(qg) = fv1(qg) - fv2(qg)
# plot(fv1)
# plot!(fv2)
# plot!(fv)

# plot(f0new2)
# plot!(f0new3)
# plot!(f0new4)
# plot!(f0new5)

# f0newn(vdc) = -f0new2(vdc) + f0new3(vdc) + f0new4(-vdc) #- f0new5(-vdc)  
# plot(f0newn)


fi(vdc) = (1 / k_droop1 * (vdcmin - vdc) + 1 / k_droop1 * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop1 * (vdcmin - vdc) + 1 / k_droop1 * (vdclow - vdcmin)) - vdc + vdcmin)/ep))
f2n(vdc) = -f2(vdc - vdcmin + vdclow)
fi(vdc) = (1 / k_droop1 * (2*vdcmin - vdc - vdclow) + 1 / k_droop1 * (vdclow - vdcmin)) + ep*log(1 + exp((-(1 / k_droop1 * (2*vdcmin - vdc - vdclow) + 1 / k_droop1 * (vdclow - vdcmin)) - vdc + 2*vdcmin - vdclow )/ep))




fr(vdc) = ((1 / k_droop1 * (vdclow - vdc)) + ep*log(1 + exp((-(1 / k_droop1 * (vdclow - vdc)) - (vdc - (vdclow - epsilon)) * (vdc - (vdcmin + epsilon)))/ep)))
plot(fi, 0.8, 1.2)
plot!(fr, 0.8, 1.2)




#priliminiary data in c1



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
#file = "./data/case5_acdc_scopf.m"
#data = parse_file(file)
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
#PowerModelsACDC.process_additional_data!(data)
#data["dcline"] = Dict{String, Any}() 
#setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
#results1 = PowerModelsACDC.run_acdcopf(data, PowerModels.DCPPowerModel, lp_solver, setting=setting);
#inc_matrix_ac = PowerModels.calc_basic_incidence_matrix(data)
#data = c1_networks
#ptdf_matrix = PowerModels.calc_basic_ptdf_matrix(data)
#inc_matrix_dc = PowerModelsACDCsecurityconstrained.calc_incidence_matrix_dc(data)
#dcdf_matrix = - ptdf_matrix * transpose(inc_matrix_dc)

#Pinj = [1.64308 -0.0508445 -0.45 0.4 0.6]'
#Pinj = [1.64308 0.149155 0 0 0]'
#pijdc = [-0.446609 0.408857 -0.0297137]'
#ptdf_matrix * Pinj + dcdf_matrix *pijdc



#inc_matrix_ac*ptdf_matrix'

#am = PowerModelsACDCsecurityconstrained.calc_susceptance_matrix_GM(data)

#branch = data["branch"]["6"];
#ref_bus = 1;
#bus_injection = PowerModelsACDCsecurityconstrained.calc_c1_branch_ptdf_single_GM(am, ref_bus, branch)



#inc_matrix_dc = PowerModelsACDCsecurityconstrained.calc_incidence_matrix_dc(data)
#dcdf_matrix = - ptdf_matrix * transpose(inc_matrix_dc)
#LinearAlgebra.pinv(dcdf_matrix)
#ptdf_branch_wr = Dict(1:length(ptdf_matrix[7, :]) .=> - ptdf_matrix[7, :])
#dcdf_branch = Dict(1:length(dcdf_matrix[7, :]) .=> - dcdf_matrix[7, :])
#ptdf_branch = Dict(k => v for (k, v) in ptdf_branch_wr if k != ref_bus)    # remove reference

#bus_injection = Dict(i => -b*(get(va_fr, i, 0.0) - get(va_to, i, 0.0)) for i in union(keys(va_fr), keys(va_to)))
#PowerModelsACDC.process_additional_data!(c1_networks)
#s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)            settings=s

#resultACDCSCOPF1=PowerModelsACDCsecurityconstrained.run_scopf_contigency_cuts(c1_networks, PowerModels.DCPPowerModel, lp_solver)
#resultACDCSCOPF2=PowerModelsSecurityConstrained.run_c1_scopf_ptdf_cuts!(c1_networks, PowerModels.ACPPowerModel, nlp_solver)
resultSCOPF3=PowerModelsSecurityConstrained.run_c1_scopf_contigency_cuts(c1_networks, PowerModels.ACPPowerModel, nlp_solver)   # Constraints required constraint_ohms_dc_branch(::ACRPowerModel, ::Int64, ...


resultSCOPF4=PowerModelsACDCsecurityconstrained.run_c1_scopf_contigency_cuts_check(c1_networks, PowerModels.ACPPowerModel, nlp_solver)

plot([i["pg"] for (gen, i) in resultSCOPF4["base_case"]["solution"]["gen"]], label = "pg_b",seriestype = :scatter)
plot!([i["pg"] for (gen, i) in resultSCOPF3["solution"]["gen"]], label = "pg_f_linear", seriestype = :scatter)
plot!([i["pg"] for (gen, i) in resultSCOPF4["solution"]["gen"]], label = "pg_f_smooth",seriestype = :scatter)
xlabel!("Gen No.")
ylabel!("P(p.u)")
Plots.savefig("pg_plot.png")

plot([i["qg"] for (gen, i) in resultSCOPF4["base_case"]["solution"]["gen"]], label = "qg_b",seriestype = :scatter)
plot!([i["qg"] for (gen, i) in resultSCOPF3["solution"]["gen"]], label = "qg_f_linear",seriestype = :scatter)
plot!([i["qg"] for (gen, i) in resultSCOPF4["solution"]["gen"]], label = "qg_f_smooth",seriestype = :scatter)
xlabel!("Gen No.")
ylabel!("Q (p.u)")
Plots.savefig("qg_plot.png")

plot([i["vm"] for (bus, i) in resultSCOPF4["base_case"]["solution"]["bus"]], label = "vm_b",  ylims = [0.89,1.11],seriestype = :scatter)
plot!([i["vm"] for (bus, i) in resultSCOPF3["solution"]["bus"]], label = "vm_f_linear",  ylims = [0.89,1.11],seriestype = :scatter)
plot!([i["vm"] for (bus, i) in resultSCOPF4["solution"]["bus"]], label = "vm_f_smooth",  ylims = [0.89,1.11],seriestype = :scatter)
xlabel!("Bus No.")
ylabel!("V (p.u)")
Plots.savefig("vm_plot.png")

plot([resultSCOPF4["base_case"]["solution"]["gen"]["42"]["pg"],  resultSCOPF3["solution"]["gen"]["42"]["pg"]], label = "pg_linear", xticks = false)
plot!([resultSCOPF4["base_case"]["solution"]["gen"]["42"]["pg"],  resultSCOPF4["solution"]["gen"]["42"]["pg"]], label = "pg_smooth", xticks = false)
plot!([c1_networks["gen"]["42"]["pmax"], c1_networks["gen"]["42"]["pmax"]], label = "pgmax", xticks = false)
xlabel!("alpha*delta_k")
ylabel!("P(p.u)")
Plots.savefig("gen42_plot.png")

plot([resultSCOPF4["base_case"]["solution"]["gen"]["32"]["pg"],  resultSCOPF3["solution"]["gen"]["32"]["pg"]], label = "pg_linear", xticks = false)
plot!([resultSCOPF4["base_case"]["solution"]["gen"]["32"]["pg"],  resultSCOPF4["solution"]["gen"]["32"]["pg"]], label = "pg_smooth", xticks = false)
plot!([c1_networks["gen"]["32"]["pmax"], c1_networks["gen"]["32"]["pmax"]], label = "pgmax", xticks = false)
xlabel!("alpha*delta_k")
ylabel!("P(p.u)")
Plots.savefig("gen32_plot.png")

plot([resultSCOPF4["base_case"]["solution"]["gen"]["63"]["pg"],  resultSCOPF3["solution"]["gen"]["63"]["pg"]], label = "pg_linear", xticks = false)
plot!([resultSCOPF4["base_case"]["solution"]["gen"]["63"]["pg"],  resultSCOPF4["solution"]["gen"]["63"]["pg"]], label = "pg_smooth", xticks = false)
plot!([c1_networks["gen"]["63"]["pmax"], c1_networks["gen"]["63"]["pmax"]], label = "pgmax", xticks = false)
xlabel!("alpha*delta_k")
ylabel!("P(p.u)")
Plots.savefig("gen63_plot.png")


Pgo = resultSCOPF4["base_case"]["solution"]["gen"]["42"]["pg"] * 100
Pglin = resultSCOPF3["solution"]["gen"]["42"]["pg"] * 100
Pgsmooth  = resultSCOPF4["solution"]["gen"]["42"]["pg"] * 100
Pgub = c1_networks["gen"]["42"]["pmax"] * 100
Pglb = c1_networks["gen"]["42"]["pmin"] * 100
alpha_g = c1_networks["gen"]["42"]["alpha"]
ep_g = c1_networks["gen"]["42"]["ep"]
ep_g = 20
#f(delta_k) = Pgub - ep_g * log(1 + exp((Pgub - Pgo - alpha_g * delta_k)/ep_g) )

f1(delta_k) = Pglb + ep_g * log( 1 + ( exp((Pgub-Pglb)/ep_g) / (1 + exp((Pgub - Pgo - alpha_g * delta_k)/ep_g)) )      )


#plot(f) 
plot(f1)
delta_kk = (Pgsmooth - Pgo)/alpha_g
scatter!([(delta_kk,Pgsmooth)], markershape = :cross, markersize = 10, markercolor = :red)
