
############################################# Base Case Plots ################################################

vm_ac_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["bus"]))
va_ac_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["bus"]))
vm_dc_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["busdc"]))
pg_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["gen"]))
qg_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["gen"]))
x = 1 : 1 : length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["bus"])
y = 1 : 1 : length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["gen"])
pg_u = zeros(Float64, length(data["gen"]))
pg_l = zeros(Float64, length(data["gen"]))
qg_u = zeros(Float64, length(data["gen"]))
qg_l = zeros(Float64, length(data["gen"]))
pf_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
pt_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"])) 
qf_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
qt_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
sf_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
st_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
If_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
fbus = zeros(Int64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
s_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
s_u = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
s_l = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
pfdc_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]))
ptdc_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]))
sdc_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]))
sdc_u = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]))
sdc_l = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]))
ploss_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
qloss_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
pdcloss_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]))
sloss_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]))
fbusdc_b = zeros(Int64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]))
Ifdc_b = zeros(Float64, length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]))
for i=1:length(data["gen"])
    pg_u[i] = data["gen"]["$i"]["pmax"]
    pg_l[i] = data["gen"]["$i"]["pmin"]
    qg_u[i] = data["gen"]["$i"]["qmax"]
    qg_l[i] = data["gen"]["$i"]["qmin"]
end
for i=1:length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["bus"])   
    vm_ac_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["bus"]["$i"]["vm"]
    va_ac_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["bus"]["$i"]["va"]
end
for i=1:length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["busdc"])   
    vm_dc_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["busdc"]["$i"]["vm"]
end
for i=1:length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["gen"])   
    pg_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["gen"]["$i"]["pg"]
    qg_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["gen"]["$i"]["qg"]
end
for i=1:length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"])
    pf_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]["$i"]["pf"]
    pt_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]["$i"]["pt"]
    qf_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]["$i"]["qf"]
    qt_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branch"]["$i"]["qt"]
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
for i=1:length(result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"])
    pfdc_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]["$i"]["pf"]
    ptdc_b[i] = result_ACDC_scopf_exact["b"]["solution"]["nw"]["0"]["branchdc"]["$i"]["pt"]
    sdc_u[i] = data["branchdc"]["$i"]["rateC"]
    fbusdc_b[i] = Int(data["branchdc"]["$i"]["fbusdc"])
   
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
using Plots
const _P = Plots
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
#for k = 1 : 4
    if k == 1
        i = 1
        m = 1
        n = 6
    elseif k == 2
        i = 7
        m = 2
        n = 7
    elseif k == 3
        i = 8
        m = 3
        n = 12
    elseif k == 4
        i = 13
        m = 4
        n = 13
    end
    i = 1
    m = 1
    n = 1
   for i = 1 : n     #length(data["gen_contingencies"]) + length( data["branch_contingencies"]) + length(data["branchdc_contingencies"])
        vm_ac_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["bus"]))
        vm_dc_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["busdc"]))
        pg_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["gen"]))
        qg_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["gen"]))
        pf_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        pt_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        qf_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        qt_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        sf_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        st_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        s_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        pfdc_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"]))
        ptdc_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"]))
        sdc_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"]))
        fbus_c = zeros(Int64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        If_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]))
        fbusdc_c = zeros(Int64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"]))
        Ifdc_c = zeros(Float64, length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"]))

        for j=1:length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["bus"])   
            vm_ac_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["bus"]["$j"]["vm"]
        end
        for j=1:length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["busdc"]) 
            vm_dc_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["busdc"]["$j"]["vm"]
        end
        for j=1:length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["gen"])   
            pg_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["gen"]["$j"]["pg"]
            qg_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["gen"]["$j"]["qg"]
        end
        for j=1:length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"])   
            if haskey(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"], "$j")

                pf_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]["$j"]["pf"]
                pt_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]["$j"]["pt"]
                qf_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]["$j"]["qf"]
                qt_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branch"]["$j"]["qt"]
                sf_c[j] = sqrt(pf_c[j]^2 + qf_c[j]^2)
                st_c[j] = sqrt(pt_c[j]^2 + qt_c[j]^2)
                if sf_c[j] > st_c[j]
                    s_c[j] = sf_c[j]
                else
                    s_c[j] = st_c[j]
                end
                fbus_c[j] = Int(data["branch"]["$j"]["f_bus"])
                If_c[j] = (sf_c[j]*data["baseMVA"])/(vm_ac_c[fbus_c[j]]*data["bus"][string(fbus_c[j])]["base_kv"])
            else
                pf_c[j] = 0 
                pt_c[j] = 0
                qf_c[j] = 0
                qt_c[j] = 0
                sf_c[j] = 0
                st_c[j] = 0
            end
        end
        for j=1:length(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"])
            if haskey(result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"], "$j")
                pfdc_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"]["$j"]["pf"]
                ptdc_c[j] = result_ACDC_scopf_exact[string(m)]["sol_c"]["c$i"]["branchdc"]["$j"]["pt"]
                if pfdc_c[j] > ptdc_c[j]
                    sdc_c[j] = pfdc_c[j]
                else
                    sdc_c[j] = ptdc_c[j]
                end
                fbusdc_c[j] = Int(data["branchdc"]["$j"]["fbusdc"])
                Ifdc_c[j] = (pfdc_c[j]*data["baseMVA"])/(vm_dc_c[fbusdc_c[j]]*data["busdc"][string(fbusdc_c[j])]["basekVdc"])
            else
                pfdc_c[j] = 0
                ptdc_c[j] = 0
                sdc_c[j] = 0
            end
        end

        ########### Voltage magnitude
        _P.plot(vm_ac_c, seriestype = :scatter, color = "blue", label = "vm_ac_c$i", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [0.85,1.15],  title = "Voltage Magnitude in C$i")        # framestyle = :box,
        _P.plot!(vm_dc_c, seriestype = :scatter, color = "red", label = "vm_dc_c$i")
        _P.plot!(ones(67)*1.1, linestyle = :dash, color = "blue", label = false)
        _P.plot!(ones(67)*0.9, linestyle = :dash, color = "blue", label = false)
        _P.plot!(ones(9)*1.05, linestyle = :dash, color = "red", label = false)
        _P.plot!(ones(9)*0.95, linestyle = :dash, color = "red", label = false)
        _P.xlabel!("Bus No.")
        _P.ylabel!("Voltage (p.u)")
        _P.savefig("vm_c$i.png")

        ########### Active/Reactive Power Generators
        _P.plot(pg_c, seriestype = :bar, bar_width = 0.4, color = "blue", label = "pg_c$i", grid = true, gridalpha = 0.2, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-10, 16], title = "Active & Reactive Power of Generators in C$i")
        _P.plot!(qg_c, seriestype = :bar, bar_width = 0.4, color = "brown",label = "qg_c$i")
        _P.plot!(pg_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
        _P.plot!(pg_l, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
        _P.plot!(qg_u, seriestype = :stepmid, linestyle = :dash, color = "brown", label = false)
        _P.plot!(qg_l, seriestype = :stepmid, linestyle = :dash, color = "brown", label = false)
        _P.xlabel!("Generator No.")
        _P.ylabel!("Power (p.u)")
        _P.savefig("pg_qg_c$i.png")

        ########### Branch flows
        _P.plot(s_c, seriestype = :scatter, color = "blue", label = "s_c$i", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-20, 20],title = "Branch Flows in C$i")        # framestyle = :box,
        _P.plot!(sdc_c, seriestype = :scatter, color = "red", label = "sdc_c$i")
        _P.plot!(s_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
        _P.plot!(-s_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
        _P.plot!(sdc_u, seriestype = :stepmid, linestyle = :dash, color = "red", label = false)
        _P.plot!(-sdc_u, seriestype = :stepmid, linestyle = :dash, color = "red", label = false)
        _P.xlabel!("Branch No.")
        _P.ylabel!("Power (p.u)")
        _P.savefig("s_sdc_c$i.png")

        ########### Branch Currents
        _P.plot(If_c*1000, seriestype = :scatter, color = "blue", label = "If_c$i", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [],title = "Branch Currents in C$i")        # framestyle = :box,
        _P.plot!(Ifdc_c*1000, seriestype = :scatter, color = "red", label = "Ifdc_c$i")
        _P.plot!(ones(102)*3500, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
        _P.plot!(-ones(102)*3500, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
        _P.xlabel!("Branch No.")
        _P.ylabel!("Current (A)")
        _P.savefig("If_Ifdc_c$i.png")
   end
#end

############################################# Final Solution Plots ################################################

vm_ac_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["bus"]))
va_ac_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["bus"]))
vm_dc_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["busdc"]))
pg_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["gen"]))
qg_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["gen"]))
pf_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
pt_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
qf_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
qt_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
sf_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
st_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
s_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
pfdc_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branchdc"]))
ptdc_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branchdc"]))
sdc_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branchdc"]))
fbus_f = zeros(Int64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
If_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
fbusdc_f = zeros(Int64, length(result_ACDC_scopf_exact["f"]["solution"]["branchdc"]))
Ifdc_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branchdc"]))
ploss_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
qloss_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))
pdcloss_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branchdc"]))
sloss_f = zeros(Float64, length(result_ACDC_scopf_exact["f"]["solution"]["branch"]))

for i=1:length(result_ACDC_scopf_exact["f"]["solution"]["bus"])   
    vm_ac_f[i] = result_ACDC_scopf_exact["f"]["solution"]["bus"]["$i"]["vm"]
    va_ac_f[i] = result_ACDC_scopf_exact["f"]["solution"]["bus"]["$i"]["va"]
end
for i=1:length(result_ACDC_scopf_exact["f"]["solution"]["busdc"])   
    vm_dc_f[i] = result_ACDC_scopf_exact["f"]["solution"]["busdc"]["$i"]["vm"]
end
for i=1:length(result_ACDC_scopf_exact["f"]["solution"]["gen"])   
    pg_f[i] = result_ACDC_scopf_exact["f"]["solution"]["gen"]["$i"]["pg"]
    qg_f[i] = result_ACDC_scopf_exact["f"]["solution"]["gen"]["$i"]["qg"]
end
for i=1:length(result_ACDC_scopf_exact["f"]["solution"]["branch"])
    pf_f[i] = result_ACDC_scopf_exact["f"]["solution"]["branch"]["$i"]["pf"]
    pt_f[i] = result_ACDC_scopf_exact["f"]["solution"]["branch"]["$i"]["pt"]
    qf_f[i] = result_ACDC_scopf_exact["f"]["solution"]["branch"]["$i"]["qf"]
    qt_f[i] = result_ACDC_scopf_exact["f"]["solution"]["branch"]["$i"]["qt"]
    sf_f[i] = sqrt(pf_f[i]^2 + qf_f[i]^2)
    st_f[i] = sqrt(pt_f[i]^2 + qt_f[i]^2)
    
    fbus_f[i] = Int(data["branch"]["$i"]["f_bus"])
    If_f[i] = (sf_f[i]*data["baseMVA"])/(vm_ac_f[fbus_f[i]]*data["bus"][string(fbus_f[i])]["base_kv"])
    
    if sf_f[i] > st_f[i]
        s_f[i] = sf_f[i]
    else
        s_f[i] = st_f[i]
    end
    if abs(pf_f[i]) > abs(pt_f[i])
        ploss_f[i] = abs(pf_f[i]) - abs(pt_f[i])
    else
        ploss_f[i] = abs(pt_f[i]) - abs(pf_f[i])
    end
    if abs(qf_f[i]) > abs(qt_f[i])
        qloss_f[i] = abs(qf_f[i]) - abs(qt_f[i])
    else
        qloss_f[i] = abs(qt_f[i]) - abs(qf_f[i])
    end
    sloss_f[i] = sqrt(ploss_f[i]^2 + qloss_f[i]^2)
end
for i=1:length(result_ACDC_scopf_exact["f"]["solution"]["branchdc"])
    pfdc_f[i] = result_ACDC_scopf_exact["f"]["solution"]["branchdc"]["$i"]["pf"]
    ptdc_f[i] = result_ACDC_scopf_exact["f"]["solution"]["branchdc"]["$i"]["pt"]
    
    fbusdc_f[i] = Int(data["branchdc"]["$i"]["fbusdc"])
   
    Ifdc_f[i] = (pfdc_f[i]*data["baseMVA"])/(vm_dc_f[fbusdc_f[i]]*data["busdc"][string(fbusdc_f[i])]["basekVdc"])
    
    if pfdc_f[i] > ptdc_f[i]
        sdc_f[i] = pfdc_f[i]
    else
        sdc_f[i] = ptdc_f[i]
    end
    if abs(pfdc_f[i]) > abs(ptdc_f[i])
        pdcloss_f[i] =  abs(pfdc_f[i]) - abs(ptdc_f[i])
    else
        pdcloss_f[i] =  abs(ptdc_f[i]) - abs(pfdc_f[i])
    end
end
########### Voltage magnitude 
_P.plot(vm_ac_f, yerror= (zeros(67),  vm_ac_b - vm_ac_f), seriestype = :scatter, color = "blue", label = "vm_ac_f", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [0.85,1.15],  title = "Voltage Magnitude Final Solution")        # framestyle = :box,
_P.plot!(vm_dc_f, yerror= (zeros(67), vm_dc_b - vm_dc_f), seriestype = :scatter, color = "red", label = "vm_dc_f")
_P.plot!(ones(67)*1.1, linestyle = :dash, color = "blue", label = false)
_P.plot!(ones(67)*0.9, linestyle = :dash, color = "blue", label = false)
_P.plot!(ones(9)*1.05, linestyle = :dash, color = "red", label = false)
_P.plot!(ones(9)*0.95, linestyle = :dash, color = "red", label = false)
_P.xlabel!("Bus No.")
_P.ylabel!("Voltage (p.u)")
_P.savefig("vm_f_plot.png")

########### Voltage angle
_P.plot(va_ac_f, yerror= (zeros(67),  va_ac_b - va_ac_f), seriestype = :scatter, color = "blue", label = "va_ac_f", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-pi/8, pi/8], title = "Voltage Angle Final Solution")        # framestyle = :box,
_P.plot!(ones(67)*pi/12, linestyle = :dash, color = "blue", label = false)
_P.plot!(ones(67)*-pi/12, linestyle = :dash, color = "blue", label = false)
_P.xlabel!("Bus No.")
_P.ylabel!("Angle (Rad)")
_P.savefig("va_f_plot.png")

########### Active/Reactive Power Generators
_P.plot(pg_f, yerror= (zeros(20),  pg_b - pg_f), seriestype = :bar, bar_width = 0.4, color = "blue", label = "pg_f", grid = true, gridalpha = 0.2, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-10, 16], title = "Active & Reactive Power of Generators Final Solution")
_P.plot!(qg_f, yerror= (zeros(20),  qg_b - qg_f), seriestype = :bar, bar_width = 0.4, color = "brown",label = "qg_f")
_P.plot!(pg_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(pg_l, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(qg_u, seriestype = :stepmid, linestyle = :dash, color = "brown", label = false)
_P.plot!(qg_l, seriestype = :stepmid, linestyle = :dash, color = "brown", label = false)
_P.xlabel!("Generator No.")
_P.ylabel!("Power (p.u)")
_P.savefig("pg_qg_f_plot.png")

########### Active/Reactive branch flows
_P.plot(pf_f, yerror= (zeros(102),  pf_b - pf_f), seriestype = :scatter, color = "blue", label = "pf_f", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-16, 16],title = "Active & Reactive Branch Flows Final Solution")        # framestyle = :box,
_P.plot!(qf_f, yerror= (zeros(102),  qf_b - qf_f), seriestype = :scatter, color = "red", label = "qf_f")
_P.plot!(pfdc_f, yerror= (zeros(9),  pfdc_b - pfdc_f), seriestype = :scatter, color = "green", label = "pfdc_f")
_P.xlabel!("Branch No.")
_P.ylabel!("Power (p.u)")
_P.savefig("pf_qf_pfdc_f_plot.png")

########### Branch flows
_P.plot(s_f, yerror= (zeros(102),  s_b - s_f), seriestype = :scatter, color = "blue", label = "s_f", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [-16, 16],title = "Branch Flows Final Solution")        # framestyle = :box,
_P.plot!(sdc_f, yerror= (zeros(9),  sdc_b - sdc_f),seriestype = :scatter, color = "red", label = "sdc_f")
_P.plot!(s_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(-s_u, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(sdc_u, seriestype = :stepmid, linestyle = :dash, color = "red", label = false)
_P.plot!(-sdc_u, seriestype = :stepmid, linestyle = :dash, color = "red", label = false)
_P.xlabel!("Branch No.")
_P.ylabel!("Power (p.u)")
_P.savefig("s_sdc_f_plot.png")

########### Branch flow losses
_P.plot(ploss_f, yerror= (zeros(102),  ploss_b - ploss_f), seriestype = :scatter, color = "blue", label = "ploss_f", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [0,1],title = "Branch Losses Final Solution")        # framestyle = :box,
_P.plot!(qloss_f, yerror= (zeros(102),  qloss_b - qloss_f), seriestype = :scatter, color = "red", label = "qloss_f")
_P.plot!(sloss_f, yerror= (zeros(102),  sloss_b - sloss_f), seriestype = :scatter, color = "green", label = "sloss_f")
_P.plot!(pdcloss_f, yerror= (zeros(9),  pdcloss_b - pdcloss_f), seriestype = :scatter, color = "black", label = "pdcloss_f")
_P.xlabel!("Branch No.")
_P.ylabel!("Power (p.u)")
_P.savefig("pqsloss_pdcloss_f_plot.png")
########### Branch Currents
_P.plot(If_f*1000, yerror= (zeros(102),  If_b*1000 - If_f*1000), seriestype = :scatter, color = "blue", label = "If_f", grid = true, gridalpha = 0.3, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [],title = "Branch Currents Final Solution")        # framestyle = :box,
_P.plot!(Ifdc_f*1000, yerror= (zeros(9),  Ifdc_b*1000 - Ifdc_f*1000),seriestype = :scatter, color = "red", label = "Ifdc_f")
_P.plot!(ones(102)*3500, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.plot!(-ones(102)*3500, seriestype = :stepmid, linestyle = :dash, color = "blue", label = false)
_P.xlabel!("Branch No.")
_P.ylabel!("Current (A)")
_P.savefig("If_Ifdc_f_plot.png")


############################# 51 contingencies
contingency_ids = zeros(Int64, 51)
vm_cont = zeros(Float64, 51)
pg_cont = zeros(Float64, 51)
qg_cont = zeros(Float64, 51)
sm_cont = zeros(Float64, 51)
smdc_cont = zeros(Float64, 51)
for i=1:51,
    contingency_ids[i] = i
    vm_cont[i] = result_ACDC_scopf_exact["8"]["sol_c"]["vio_c$i"][:vm]
    pg_cont[i] = result_ACDC_scopf_exact["8"]["sol_c"]["vio_c$i"][:pg]
    qg_cont[i]= result_ACDC_scopf_exact["8"]["sol_c"]["vio_c$i"][:qg]
    sm_cont[i] = result_ACDC_scopf_exact["8"]["sol_c"]["vio_c$i"][:sm]
    smdc_cont[i] = result_ACDC_scopf_exact["8"]["sol_c"]["vio_c$i"][:smdc]
end
contingency_ids[49] = 101
contingency_ids[50] = 102
contingency_ids[51] = 1001

########### large set of 51 contingencies 
_P.plot((contingency_ids, sm_cont), seriestype = :scatter, color = "blue", label = "vm_cont", grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", framestyle = :box, ylims = [0.5, 15],  title = "Violations for 51 contingencies")        # framestyle = :box,
_P.plot!((contingency_ids, pg_cont), seriestype = :scatter, color = "red", label = "pg_cont")
_P.plot!((contingency_ids, qg_cont), seriestype = :scatter, color = "green", label = "qg_cont")
_P.plot!((contingency_ids, sm_cont), seriestype = :scatter, color = "black", label = "sm_cont")
_P.plot!((contingency_ids, smdc_cont), seriestype = :scatter, color = "brown", label = "smdc_cont")
_P.xlabel!("contingency_ids")
_P.ylabel!("Violations (p.u)")
_P.savefig("cont51.png")