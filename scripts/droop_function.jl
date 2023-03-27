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