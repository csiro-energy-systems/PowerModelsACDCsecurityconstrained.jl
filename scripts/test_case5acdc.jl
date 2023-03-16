using Pkg
Pkg.activate("./scripts")

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

const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-6)  
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)

##

file = "./data/case5_acdc_scopf.m"
data = parse_file(file)

idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([1])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    # data["gen"]["$i"]["model"] = 2
    # data["gen"]["$i"]["pg"] = 0
    # data["gen"]["$i"]["qg"] = 0
    # data["gen"]["$i"]["ncost"] = 2
    # data["gen"]["1"]["cost"] = [10, 25, 25, 45]
    # data["gen"]["2"]["cost"] = [5, 20, 20, 40]
    data["gen"]["$i"]["alpha"] = 10
    data["gen"]["$i"]["ep"] = 1e-1
end

#data["branch"]["1"]["rate_a"] = 0.5; data["branch"]["1"]["rate_b"] = 0.5; data["branch"]["1"]["rate_c"] = 0.5
#data["branch"]["2"]["rate_a"] = 0.5; data["branch"]["2"]["rate_b"] = 0.5; data["branch"]["2"]["rate_c"] = 0.5
#data["branch"]["5"]["rate_a"] = 0.5; data["branch"]["5"]["rate_b"] = 0.5; data["branch"]["5"]["rate_c"] = 0.5

# #data["branchdc"]["1"]["rateA"] = 0.5; data["branchdc"]["1"]["rateB"] = 0.5; data["branchdc"]["1"]["rateC"] = 0.5
# data["branchdc"]["2"]["rateA"] = 35; data["branchdc"]["2"]["rateB"] =35; data["branchdc"]["2"]["rateC"] = 35
# #data["branchdc"]["3"]["rateA"] = 80; data["branchdc"]["3"]["rateB"] = 80; data["branchdc"]["3"]["rateC"] = 80

# data["load"]["1"]["pd"] = data["load"]["1"]["pd"] * 2
# data["load"]["1"]["qd"] = data["load"]["1"]["qd"] * 2
# data["load"]["2"]["pd"] = data["load"]["2"]["pd"] * 2
# data["load"]["2"]["qd"] = data["load"]["2"]["qd"] * 2
# data["load"]["3"]["pd"] = data["load"]["3"]["pd"] * 2
# data["load"]["3"]["qd"] = data["load"]["3"]["qd"] * 2

#add new columns to "branch" matrix column_names tm_min tm_max	ta_min	ta_max
data["branch"]["1"]["tm_min"] = 0.9; data["branch"]["1"]["tm_max"] = 1.1; data["branch"]["1"]["ta_min"] = 0.0;   data["branch"]["1"]["ta_max"] = 0.0
data["branch"]["2"]["tm_min"] = 0.9; data["branch"]["2"]["tm_max"] = 1.1; data["branch"]["2"]["ta_min"] = 0.0;   data["branch"]["2"]["ta_max"] = 0.0
data["branch"]["3"]["tm_min"] = 1;   data["branch"]["3"]["tm_max"] = 1;   data["branch"]["3"]["ta_min"] = 0.0;   data["branch"]["3"]["ta_max"] = 0.0
data["branch"]["4"]["tm_min"] = 1;   data["branch"]["4"]["tm_max"] = 1;   data["branch"]["4"]["ta_min"] = 0.0;   data["branch"]["4"]["ta_max"] = 0.0 
data["branch"]["5"]["tm_min"] = 1;   data["branch"]["5"]["tm_max"] = 1;   data["branch"]["5"]["ta_min"] = 0.0;   data["branch"]["5"]["ta_max"] = 0.0
data["branch"]["6"]["tm_min"] = 1;   data["branch"]["6"]["tm_max"] = 1;   data["branch"]["6"]["ta_min"] = 0.0;   data["branch"]["6"]["ta_max"] = 0.0
data["branch"]["7"]["tm_min"] = 1;   data["branch"]["7"]["tm_max"] = 1;   data["branch"]["7"]["ta_min"] = -15.0; data["branch"]["7"]["ta_max"] = 15.0

# 
for i=1:length(data["convdc"])
    # data["convdc"]["$i"]["alpha"] = 5
    data["convdc"]["$i"]["ep"] = 1e-1
end

##
PM_acdc.process_additional_data!(data)

setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

resultpf_droop = PM_acdc_sc.run_acdcpf_GM( data, PM.ACPPowerModel, nlp_solver; setting = setting)

result_droop = PM_acdc_sc.run_acdcopf_droop( data, PM.ACPPowerModel, nlp_solver; setting = setting)









#result = PM_acdc.run_acdcpf( data, PM.DCPPowerModel, lp_solver; setting = setting)

######result_ACDC_scopf_exact = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf, nlp_solver, setting)

result_ACDC_scopf_soft_w = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, nlp_solver, setting)

#result_ACDC_scopf_dcp_exact = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.DCPPowerModel, PM_acdc_sc.run_scopf, lp_solver, setting)

#result_ACDC_scopf_dcp_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.DCPPowerModel, PM_acdc_sc.run_scopf_soft, lp_solver, setting)

# updating reference point 
for i = 1:length(data["gen"])
    data["gen"]["$i"]["pgref"] = result_ACDC_scopf_exact["final"]["solution"]["gen"]["$i"]["pg"]
end 
# embedding unsecure contingencies
if haskey(result_ACDC_scopf_exact, "gen_contingencies_unsecure") 
    for (idx, label, type) in result_ACDC_scopf_exact["gen_contingencies_unsecure"]
        data["gen"]["$idx"]["status"] = 0
    end
end
if haskey(result_ACDC_scopf_exact, "branch_contingencies_unsecure")
    for (idx, label, type) in result_ACDC_scopf_exact["branch_contingencies_unsecure"]
        data["branch"]["$idx"]["br_status"] = 0
    end
end
if haskey(result_ACDC_scopf_exact, "branchdc_contingencies_unsecure") 
    for (idx, label, type) in result_ACDC_scopf_exact["branchdc_contingencies_unsecure"]
        data["branchdc"]["$idx"]["status"] = 0
    end
end
# Re-dispatch
result_ACDC_scopf_re_dispatch =  PM_acdc_sc.run_acdcreopf(data, PM.ACPPowerModel, nlp_solver)
# Re-dispatch_ots
result_ACDC_scopf_re_dispatch_ots =  PM_acdc_sc.run_acdcreopf_ots(data, PM.ACPPowerModel, minlp_solver)
# Re-dispatch_ots_oltc_pst
result_ACDC_scopf_re_dispatch_ots_oltc_pst =  PM_acdc_sc.run_acdcreopf_ots_oltc_pst(data, PM.ACPPowerModel, minlp_solver)

Pdc_ref = data["convdc"]["1"]["Pdcset"]
vdcmax = data["convdc"]["1"]["Vmmax"]
vdcmin = data["convdc"]["1"]["Vmmin"]
vdchigh = data["convdc"]["1"]["Vdchigh"]
vdclow = data["convdc"]["1"]["Vdclow"]
k_droop = data["convdc"]["1"]["droop"]
ep = data["convdc"]["1"]["ep"]
epsilon =1E-19

pconv_dc_base = result_ACDC_scopf_soft_w["base"]["solution"]["nw"]["0"]["convdc"]["1"]["pdc"]
pconv_dc_final = result_ACDC_scopf_soft_w["final"]["solution"]["convdc"]["1"]["pdc"]
vdc_final = result_ACDC_scopf_soft_w["final"]["solution"]["busdc"]["1"]["vm"]

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