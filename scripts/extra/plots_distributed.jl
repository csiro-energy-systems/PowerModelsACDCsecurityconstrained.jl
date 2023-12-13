    
    using Ipopt
    using PowerModels
    using PowerModelsACDC
    using PowerModelsSecurityConstrained
    using PowerModelsACDCsecurityconstrained
    using InfrastructureModels
    using Memento
    using HDF5, JLD
    using Plots
    using Plots.PlotMeasures
    using LaTeXStrings
    using IterativeSolvers
    using StatsPlots
   
    const _PM = PowerModels
    const _PMSC = PowerModelsSecurityConstrained
    const _PMACDC = PowerModelsACDC
    const _PMSCACDC = PowerModelsACDCsecurityconstrained
    const _IM = InfrastructureModels
    const _LOGGER = Memento.getlogger(@__MODULE__)

    nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)  

    _PMSCACDC.silence()



    # load data
    # data_nem = parse_file("./data/snem2000_acdc.m")
    data_nem = parse_file("./data/snem2000_acdc_mesh.m")
    _PMSCACDC.fix_scopf_data_issues!(data_nem)
    _PMACDC.process_additional_data!(data_nem)

    ##
    data_5 = _PM.parse_file("./data/case5_acdc_scopf.m")
    _PMSCACDC.fix_scopf_data_case5_acdc!(data_5)
    _PMACDC.process_additional_data!(data_5)

    ## 
    data_67 = _PM.parse_file("./data/case67_acdc_scopf.m")
    _PMSCACDC.fix_scopf_data_case67_acdc!(data_67)
    _PMACDC.process_additional_data!(data_67)

    ##
    data_24 = _PM.parse_file("./data/case24_3zones_acdc_sc.m")
    _PMSCACDC.fix_scopf_data_case24_3zones_acdc!(data_24)
    _PMACDC.process_additional_data!(data_24)

    ##
    c1_ini_file = "./data/c1/inputfiles.ini"
    c1_scenarios = "scenario_02"
    c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
    data_500 = build_c1_pm_model(c1_cases)
    _PMSCACDC.fix_scopf_data_case500_acdc!(data_500)
    _PMACDC.process_additional_data!(data_500)



    # load results
    c5_ptdf_f = load("./results/case5_ptdf_wf.jld")["data"]
    c24_ptdf_f = load("./results/case24_ptdf_wf.jld")["data"]
    c67_ptdf_f = load("./results/case67_ptdf_wf.jld")["data"]
    c500_ptdf_f = load("./results/case500_ptdf_wf.jld")["data"]
    

    # c5_ptdf_wof = load("./results/case5_ptdf_wof.jld")["data"]
    # c24_ptdf_wof = load("./results/case24_ptdf_wof.jld")["data"]
    # c67_ptdf_wof = load("./results/case67_ptdf_wof.jld")["data"]
    # c500_ptdf_wof = load("./results/case500_ptdf_wof.jld")["data"]
    # nem_ptdf_wof = load("./results/case_nem_ptdf_wof.jld")["data"]

    nem_ptdf_fpeak = load("./results/case_nem_ptdf_wf_peakload.jld")["data"]
    nem_ptdf_fmin = load("./results/case_nem_ptdf_wf_min.jld")["data"]
    nem_ptdf_frez = load("./results/case_nem_ptdf_wf_REZ.jld")["data"]

    c5 = load("./results/case5_wf.jld")["data"]
    c24 = load("./results/case24_wf.jld")["data"]
    c67 = load("./results/case67_wf.jld")["data"]
    c500 = load("./results/case500_wf.jld")["data"]
    # nem = load("./results/nem.jld")["data"]


    c5_ptdf_wof = load("./results/case5_ptdf_wof.jld")["data"]
    c24_ptdf_wof = load("./results/case24_ptdf_wof.jld")["data"]
    c67_ptdf_wof = load("./results/case67_ptdf_wof.jld")["data"]
    c500_ptdf_wof = load("./results/case500_ptdf_wof.jld")["data"]

    c5_wof = load("./results/case5_wof.jld")["data"]
    c24_wof = load("./results/case24_wof.jld")["data"]
    c67_wof = load("./results/case67_wof.jld")["data"]
    c500_wof = load("./results/case500_wof.jld")["data"]


    nem_benchmark = load("./results/case_nem_ptdf_wf.jld")["data"]
    nem_peak = load("./results/case_nem_ptdf_wf_peakload.jld")["data"]
    nem_min = load("./results/case_nem_ptdf_wf_min.jld")["data"]
    nem_rez = load("./results/case_nem_ptdf_wf_REZ.jld")["data"]



    # collect variables for comparison
    # 5
    pg_p_f5 = [ gen["pg"] for (i, gen) in c5_ptdf_f["rfinal"]["final"]["solution"]["gen"] ]
    pg_f5 = [ gen["pg"] for (i, gen) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["gen"] ]
    pg_diff5 = abs.(pg_p_f5 .- pg_f5)

    pgrid_p_f5 = [ conv["pgrid"] for (i, conv) in c5_ptdf_f["rfinal"]["final"]["solution"]["convdc"] ]
    pgrid_f5 = [ conv["pgrid"] for (i, conv) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"] ]
    pgrid_diff5 = abs.(pgrid_p_f5 .- pgrid_f5)
    
    # 24
    data_24["gen"]["14"]["pmax"] = 1.0
    data_24["gen"]["46"]["pmax"] = 1.0
    pg_p_f24 = [ gen["pg"] for (i, gen) in c24_ptdf_f["rbase"]["solution"]["gen"] ]
    pg_f24 = [ gen["pg"] for (i, gen) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["gen"] ]
    pg_diff24 = abs.(pg_p_f24 .- pg_f24)

    pgrid_p_f24 = [ conv["pgrid"] for (i, conv) in c24_ptdf_f["rbase"]["solution"]["convdc"] ]
    pgrid_f24 = [ conv["pgrid"] for (i, conv) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["convdc"] ]
    pgrid_diff24 = abs.(pgrid_p_f24 .- pgrid_f24)

    # 67
    pg_p_f67 = [ gen["pg"] for (i, gen) in c67_ptdf_f["rfinal"]["final"]["solution"]["gen"] ]
    pg_f67 = [ gen["pg"] for (i, gen) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["gen"] ]
    pg_diff67 = abs.(pg_p_f67 .- pg_f67)

    pgrid_p_f67 = [ conv["pgrid"] for (i, conv) in c67_ptdf_f["rfinal"]["final"]["solution"]["convdc"] ]
    pgrid_f67 = [ conv["pgrid"] for (i, conv) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"] ]
    pgrid_diff67 = abs.(pgrid_p_f67 .- pgrid_f67)

    # 500
    pg_p_f500 = [ gen["pg"] for (i, gen) in c500_ptdf_f["rfinal"]["final"]["solution"]["gen"] ]
    pg_f500 = [ gen["pg"] for (i, gen) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["gen"] ]
    pg_diff500 = abs.(pg_p_f500 .- pg_f500)

    pgrid_p_f500 = [ conv["pgrid"] for (i, conv) in c500_ptdf_f["rfinal"]["final"]["solution"]["convdc"] ]
    pgrid_f500 = [ conv["pgrid"] for (i, conv) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"] ]
    pgrid_diff500 = abs.(pgrid_p_f500 .- pgrid_f500)

    # comparison plot

    # pg, pconv_ac
    plt = plot(layout=(4,2), size = (600,700), left_margin = [2.5mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, 
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :outertop)

    plot!(pg_p_f5, pg_f5, seriestype = :scatter, markersize = 3, color = "blue", label = false, subplot=1)    
    plot!(minimum(pg_p_f5):0.001:maximum(pg_p_f5), minimum(pg_p_f5):0.001:maximum(pg_p_f5), label=false, color = "orange2", subplot=1)
    xlabel!(L"{\mathrm{{g \in \mathcal{G}}}}", subplot=1)
    ylabel!(L"{\mathrm{\~P^{g}\;(pu)}}", subplot=1)
    title!(L"\texttt{case5\_acdc}", titlefontsize = 10, subplot=1)

    plot!(pgrid_p_f5, pgrid_f5, seriestype = :scatter, markersize = 3, color = "blue", label = false, subplot=2)    
    plot!(minimum(pgrid_p_f5):0.001:maximum(pgrid_p_f5), minimum(pgrid_p_f5):0.001:maximum(pgrid_p_f5), label=false, color = "orange2", subplot=2)
    xlabel!(L"{\mathrm{{c \in \mathcal{T}^{cv}}}}",  subplot=2)
    ylabel!(L"{\mathrm{\~P^{cv}\;(pu)}}", subplot=2)
    title!(L"\texttt{case5\_acdc}", titlefontsize = 10, subplot=2)

    plot!(pg_p_f24, pg_f24, seriestype = :scatter, markersize = 3, color = "blue", label = false, subplot=3)    
    plot!(minimum(pg_p_f24):0.001:maximum(pg_p_f24), minimum(pg_p_f24):0.001:maximum(pg_p_f24), label=false, color = "orange2", subplot=3)
    xlabel!(L"{\mathrm{{g \in \mathcal{G}}}}", subplot=3)
    ylabel!(L"{\mathrm{\~P^{g}\;(pu)}}", subplot=3)
    title!(L"\texttt{case24\_3zones\_acdc}", titlefontsize = 10, subplot=3)

    plot!(pgrid_p_f24, pgrid_f24, seriestype = :scatter, markersize = 3, color = "blue", label = false, subplot=4)    
    plot!(minimum(pgrid_p_f24):0.001:maximum(pgrid_p_f24), minimum(pgrid_p_f24):0.001:maximum(pgrid_p_f24), label=false, color = "orange2", subplot=4)
    xlabel!(L"{\mathrm{{c \in \mathcal{T}^{cv}}}}",  subplot=4)
    ylabel!(L"{\mathrm{\~P^{cv}\;(pu)}}", subplot=4)
    title!(L"\texttt{case24\_3zones\_acdc}", titlefontsize = 10, subplot=4)

    plot!(pg_p_f67, pg_f67, seriestype = :scatter, markersize = 3, color = "blue", label = false, subplot=5)    
    plot!(minimum(pg_f67):0.001:maximum(pg_f67), minimum(pg_f67):0.001:maximum(pg_f67), label=false, color = "orange2", subplot=5)
    xlabel!(L"{\mathrm{{g \in \mathcal{G}}}}", subplot=5)
    ylabel!(L"{\mathrm{\~P^{g}\;(pu)}}", subplot=5)
    title!(L"\texttt{case67\_acdc}", titlefontsize = 10, subplot=5)

    plot!(pgrid_p_f67, pgrid_f67, seriestype = :scatter, markersize = 3, color = "blue", label = false, subplot=6)    
    plot!(minimum(pgrid_p_f67):0.001:maximum(pgrid_p_f67), minimum(pgrid_p_f67):0.001:maximum(pgrid_p_f67), label=false, color = "orange2", subplot=6)
    xlabel!(L"{\mathrm{{c \in \mathcal{T}^{cv}}}}",  subplot=6)
    ylabel!(L"{\mathrm{\~P^{cv}\;(pu)}}", subplot=6)
    title!(L"\texttt{case67\_acdc}", titlefontsize = 10, subplot=6)

    plot!(pg_p_f500, pg_f500, seriestype = :scatter, markersize = 3, color = "blue", label = false, subplot=7)    
    plot!(minimum(pg_p_f500):0.001:maximum(pg_p_f500), minimum(pg_p_f500):0.001:maximum(pg_p_f500), label=false, color = "orange2", subplot=7)
    xlabel!(L"{\mathrm{{g \in \mathcal{G}}}}", subplot=7)
    ylabel!(L"{\mathrm{\~P^{g}\;(pu)}}", subplot=7)
    title!(L"\texttt{case500\_acdc}", titlefontsize = 10, subplot=7)

    plot!(pgrid_p_f500, pgrid_f500, seriestype = :scatter, markersize = 3, color = "blue", label = false, subplot=8)    
    plot!(minimum(pgrid_p_f500):0.001:maximum(pgrid_p_f500), minimum(pgrid_p_f500):0.001:maximum(pgrid_p_f500), label=false, color = "orange2", subplot=8)
    xlabel!(L"{\mathrm{{c \in \mathcal{T}^{cv}}}}",  subplot=8)
    ylabel!(L"{\mathrm{\~P^{cv}\;(pu)}}", subplot=8)
    title!(L"\texttt{case500\_acdc}", titlefontsize = 10, subplot=8)

    savefig("./plots_ptdf/Norm_pg_pconv_comparison_ptdf_vs_complete.png")

    # line loadings

    # TSMP Model

    #5  
    sf5_b = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_5["branch"][i]["rate_c"] for (i,branch) in c5["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf5_bdc = 100*[branchdc["pf"]/data_5["branchdc"][i]["rateC"] for (i,branchdc) in c5["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf5_bacdc = [sf5_b; sf5_bdc]
    sf5_f = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_5["branch"][i]["rate_c"] for (i,branch) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["branch"]])
    sf5_fdc = 100*[branchdc["pf"]/data_5["branchdc"][i]["rateC"] for (i,branchdc) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["branchdc"]]
    sf5_facdc = [sf5_f; sf5_fdc]

    #24  
    sf24_b = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_24["branch"][i]["rate_c"] for (i,branch) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf24_bdc = 100*[branchdc["pf"]/data_24["branchdc"][i]["rateC"] for (i,branchdc) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf24_bacdc = [sf24_b; sf24_bdc]
    sf24_f = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_24["branch"][i]["rate_c"] for (i,branch) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf24_fdc = 100*[branchdc["pf"]/data_24["branchdc"][i]["rateC"] for (i,branchdc) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf24_facdc = [sf24_f; sf24_fdc]

    #67  
    sf67_b = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_67["branch"][i]["rate_c"] for (i,branch) in c67["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf67_bdc = 100*[branchdc["pf"]/data_67["branchdc"][i]["rateC"] for (i,branchdc) in c67["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf67_bacdc = [sf67_b; sf67_bdc]
    sf67_f = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_67["branch"][i]["rate_c"] for (i,branch) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["branch"]])
    sf67_fdc = 100*[branchdc["pf"]/data_67["branchdc"][i]["rateC"] for (i,branchdc) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["branchdc"]]
    sf67_facdc = [sf67_f; sf67_fdc]

    #500  
    sf500_b = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_500["branch"][i]["rate_c"] for (i,branch) in c500["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf500_bdc = 100*[branchdc["pf"]/data_500["branchdc"][i]["rateC"] for (i,branchdc) in c500["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf500_bacdc = [sf500_b; sf500_bdc]
    sf500_f = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_500["branch"][i]["rate_c"] for (i,branch) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["branch"]])
    sf500_fdc = 100*[branchdc["pf"]/data_500["branchdc"][i]["rateC"] for (i,branchdc) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["branchdc"]]
    sf500_facdc = [sf500_f; sf500_fdc]

    # Proposed

    #5  
    sf5_bp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_5["branch"][i]["rate_c"] for (i,branch) in c5_ptdf_f["rbase"]["solution"]["branch"]])
    sf5_bdcp = 100*[branchdc["pf"]/data_5["branchdc"][i]["rateC"] for (i,branchdc) in c5_ptdf_f["rbase"]["solution"]["branchdc"]]
    sf5_bacdcp = [sf5_bp; sf5_bdcp]
    sf5_fp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_5["branch"][i]["rate_c"] for (i,branch) in c5_ptdf_f["rfinal"]["final"]["solution"]["branch"]])
    sf5_fdcp = 100*[branchdc["pf"]/data_5["branchdc"][i]["rateC"] for (i,branchdc) in c5_ptdf_f["rfinal"]["final"]["solution"]["branchdc"]]
    sf5_facdcp = [sf5_fp; sf5_fdcp]

    #24  
    sf24_bp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_24["branch"][i]["rate_c"] for (i,branch) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf24_bdcp = 100*[branchdc["pf"]/data_24["branchdc"][i]["rateC"] for (i,branchdc) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf24_bacdcp = [sf24_bp; sf24_bdcp]
    sf24_fp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_24["branch"][i]["rate_c"] for (i,branch) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf24_fdcp = 100*[branchdc["pf"]/data_24["branchdc"][i]["rateC"] for (i,branchdc) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf24_facdcp = [sf24_fp; sf24_fdcp]

    #67  
    sf67_bp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_67["branch"][i]["rate_c"] for (i,branch) in c67_ptdf_f["rbase"]["solution"]["branch"]])
    sf67_bdcp = 100*[branchdc["pf"]/data_67["branchdc"][i]["rateC"] for (i,branchdc) in c67_ptdf_f["rbase"]["solution"]["branchdc"]]
    sf67_bacdcp = [sf67_bp; sf67_bdcp]
    sf67_fp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_67["branch"][i]["rate_c"] for (i,branch) in c67_ptdf_f["rfinal"]["final"]["solution"]["branch"]])
    sf67_fdcp = 100*[branchdc["pf"]/data_67["branchdc"][i]["rateC"] for (i,branchdc) in c67_ptdf_f["rfinal"]["final"]["solution"]["branchdc"]]
    sf67_facdcp = [sf67_fp; sf67_fdcp]

    #500  
    sf500_bp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_500["branch"][i]["rate_c"] for (i,branch) in c500_ptdf_f["rbase"]["solution"]["branch"]])
    sf500_bdcp = 100*[branchdc["pf"]/data_500["branchdc"][i]["rateC"] for (i,branchdc) in c500_ptdf_f["rbase"]["solution"]["branchdc"]]
    sf500_bacdcp = [sf500_bp; sf500_bdcp]
    sf500_fp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_500["branch"][i]["rate_c"] for (i,branch) in c500_ptdf_f["rfinal"]["final"]["solution"]["branch"]])
    sf500_fdcp = 100*[branchdc["pf"]/data_500["branchdc"][i]["rateC"] for (i,branchdc) in c500_ptdf_f["rfinal"]["final"]["solution"]["branchdc"]]
    sf500_facdcp = [sf500_fp; sf500_fdcp]

    # difference in final line loadings

    #5  
    sf5_fd = ([sqrt.(branch["pf"].^2 .+ branch["qf"].^2) for (i,branch) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["branch"]])
    sf5_fdcd = [branchdc["pf"] for (i,branchdc) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["branchdc"]]
    sf5_facdcd = [sf5_fd; sf5_fdcd]
    sf5_fpd = ([sqrt.(branch["pf"].^2 .+ branch["qf"].^2) for (i,branch) in c5_ptdf_f["rfinal"]["final"]["solution"]["branch"]])
    sf5_fdcpd = [branchdc["pf"] for (i,branchdc) in c5_ptdf_f["rfinal"]["final"]["solution"]["branchdc"]]
    sf5_facdcpd = [sf5_fpd; sf5_fdcpd]

    sf5_diff = sf5_facdcd - sf5_facdcpd
    sf5_diff_length = length(sf5_diff)

    # X2 = [fill(x,length(y)) for (x,y) in zip(1:1:sf5_diff_length,sf5_diff)]
    # df5 = DataFrame(X = X2, Y = sf5_diff)

    #24 
    sf24_fd = ([sqrt.(branch["pf"].^2 .+ branch["qf"].^2) for (i,branch) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf24_fdcd = [branchdc["pf"] for (i,branchdc) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf24_facdcd = [sf24_fd; sf24_fdcd]
    sf24_fpd = ([sqrt.(branch["pf"].^2 .+ branch["qf"].^2) for (i,branch) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branch"]])
    sf24_fdcpd = [branchdc["pf"] for (i,branchdc) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["branchdc"]]
    sf24_facdcpd = [sf24_fpd; sf24_fdcpd] 

    sf24_diff_length = length(sf24_diff)
    sf24_diff = sf24_facdc - sf24_facdcp

    #67  
    sf67_fd = ([sqrt.(branch["pf"].^2 .+ branch["qf"].^2) for (i,branch) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["branch"]])
    sf67_fdcd = [branchdc["pf"] for (i,branchdc) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["branchdc"]]
    sf67_facdcd = [sf67_fd; sf67_fdcd]
    sf67_fpd = ([sqrt.(branch["pf"].^2 .+ branch["qf"].^2) for (i,branch) in c67_wof["rfinal"]["final"]["solution"]["nw"]["0"]["branch"]])
    sf67_fdcpd = [branchdc["pf"] for (i,branchdc) in c67_wof["rfinal"]["final"]["solution"]["nw"]["0"]["branchdc"]]
    sf67_facdcpd = [sf67_fpd; sf67_fdcpd]

    sf67_diff_length = length(sf67_diff)
    sf67_diff = (sf67_facdcd - sf67_facdcpd)./10

    #500  
    sf500_fd = ([sqrt.(branch["pf"].^2 .+ branch["qf"].^2) for (i,branch) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["branch"]])
    sf500_fdcd = [branchdc["pf"] for (i,branchdc) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["branchdc"]]
    sf500_facdcd = [sf500_fd; sf500_fdcd]
    sf500_fpd = ([sqrt.(branch["pf"].^2 .+ branch["qf"].^2) for (i,branch) in c500_ptdf_f["rfinal"]["final"]["solution"]["branch"]])
    sf500_fdcpd = [branchdc["pf"] for (i,branchdc) in c500_ptdf_f["rfinal"]["final"]["solution"]["branchdc"]]
    sf500_facdcpd = [sf500_fpd; sf500_fdcpd]

    sf500_diff_length = length(sf500_diff)
    sf500_diff = sf500_facdcd - sf500_facdcpd

    # X500 = [fill(x,length(y)) for (x,y) in zip(1:1:sf500_diff_length,sf500_diff)]
    # df500 = DataFrame(X500 = X500, Y500 = sf500_diff)

    # difference in gen/conv loadings

    #5  
    sg5_fd = [sqrt.(gen["pg"].^2 .+ gen["qg"].^2) for (i,gen) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["gen"]]
    sc5_fdcd = [sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2) for (i,conv) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"]]
    sgc5_facdcd = [sg5_fd; sc5_fdcd]
    sg5_fpd = [sqrt.(gen["pg"].^2 .+ gen["qg"].^2) for (i,gen) in c5_ptdf_f["rfinal"]["final"]["solution"]["gen"]]
    sc5_fdcpd = [sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2) for (i,conv) in c5_ptdf_f["rfinal"]["final"]["solution"]["convdc"]]
    sgc5_facdcpd = [sg5_fpd; sc5_fdcpd]

    sgc5_diff = sgc5_facdcd - sgc5_facdcpd


    #24 
    sg24_fd = ([sqrt.(gen["pg"].^2 .+ gen["qg"].^2) for (i,gen) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["gen"]])
    sc24_fdcd = [sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2) for (i,conv) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["convdc"]]
    sgc24_facdcd = [sg24_fd; sc24_fdcd]
    sg24_fpd = ([sqrt.(gen["pg"].^2 .+ gen["qg"].^2) for (i,gen) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["gen"]])
    sc24_fdcpd = [sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2) for (i,conv) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["convdc"]]
    sgc24_facdcpd = [sg24_fpd; sc24_fdcpd] 

    sgc24_diff = sgc24_facdcd - sgc24_facdcpd

    #67  
    sg67_fd = ([sqrt.(gen["pg"].^2 .+ gen["qg"].^2) for (i,gen) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["gen"]])
    sc67_fdcd = [sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2) for (i,conv) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"]]
    sgc67_facdcd = [sg67_fd; sc67_fdcd]
    sg67_fpd = ([sqrt.(gen["pg"].^2 .+ gen["qg"].^2) for (i,gen) in c67_wof["rfinal"]["final"]["solution"]["nw"]["0"]["gen"]])
    sc67_fdcpd = [sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2) for (i,conv) in c67_wof["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"]]
    sgc67_facdcpd = [sg67_fpd; sc67_fdcpd]

    sgc67_diff = (sgc67_facdcd - sgc67_facdcpd)./12

    #500  
    sg500_fd = ([sqrt.(gen["pg"].^2 .+ gen["qg"].^2) for (i,gen) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["gen"]])
    sc500_fdcd = [sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2) for (i,conv) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"]]
    sgc500_facdcd = [sg500_fd; sc500_fdcd]
    sg500_fpd = ([sqrt.(gen["pg"].^2 .+ gen["qg"].^2) for (i,gen) in c500_ptdf_f["rfinal"]["final"]["solution"]["gen"]])
    sc500_fdcpd = [sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2) for (i,conv) in c500_ptdf_f["rfinal"]["final"]["solution"]["convdc"]]
    sgc500_facdcpd = [sg500_fpd; sc500_fdcpd]

    sgc500_diff = sgc500_facdcd - sgc500_facdcpd


    # line loading diff plot

    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :topright, legendfont = 6)

    # @df df5 boxplot!(:X, :Y, subplot=1, legend = false)
    # plot!(1:sf5_diff_length, sf5_facdcd, yerror = sf5_diff, color = "blue", label = false, subplot=1)
    plot!(Normal(mean(sf5_diff), std(sf5_diff)), markersize =1, markershape = :circle, markerstrokecolor = :blue, markercolor = :blue, xlims=[-0.04,0.04], label = false, subplot=1)
    plot!(Normal(mean(sgc5_diff), std(sgc5_diff)), markersize =1, markershape = :circle, markerstrokecolor = :red, markercolor = :red, label = false, subplot=1)
    ylabel!(L"{\mathrm{pdf()}}", subplot=1)
    title!(L"\texttt{case5}", titlefontsize = 10, subplot=1)

    # histogram!(sf24_bacdc, bins = range(0, 100, length=50), color = "red", label = L"{\mathrm{base}}", yticks=0:2:10, subplot=2)
    plot!(Normal(mean(sf24_diff), std(sf24_diff)), markersize =1, markershape = :circle, markerstrokecolor = :blue, markercolor = :blue, ylims = [0,2], label = L"{\mathrm{ac-dc\;line\;loading}}", subplot=2)
    plot!(Normal(mean(sgc24_diff), std(sgc24_diff)), markersize =1, markershape = :circle, markerstrokecolor = :red, markercolor = :red, label = L"{\mathrm{gen-conv\;loading}}", subplot=2)
    ylabel!(L"{\mathrm{pdf()}}", subplot=2)
    title!(L"\texttt{case24}", titlefontsize = 10, subplot=2)

    plot!(Normal(mean(sf67_diff), std(sf67_diff)), markersize =1, markershape = :circle, markerstrokecolor = :blue, markercolor = :blue, label = false, subplot=3)
    plot!(Normal(mean(sgc67_diff), std(sgc67_diff)), markersize =1, markershape = :circle, markerstrokecolor = :red, markercolor = :red, label = false, subplot=3)
    xlabel!(L"{{\epsilon^\mathrm{TSMP-propsoed}(\mathrm{pu})}}", subplot=3)
    ylabel!(L"{\mathrm{pdf()}}", subplot=3)
    title!(L"\texttt{case67}", titlefontsize = 10, subplot=3)

    # @df df500 boxplot!(:X500, :Y500, subplot=4, legend = false)
    plot!(Normal(mean(sf500_diff), std(sf500_diff)), markersize =1, markershape = :circle, markerstrokecolor = :blue, markercolor = :blue, ylims = [0,4], yticks=(0:1:4, [L"0.0", L"1.0", L"2.0", L"3.0", L"4.0"]), label = false, subplot=4)
    plot!(Normal(mean(sgc500_diff), std(sgc500_diff)), markersize =1, markershape = :circle, markerstrokecolor = :red, markercolor = :red, label = false, subplot=4)
    xlabel!(L"{{\epsilon^\mathrm{TSMP-propsoed}(\mathrm{pu})}}", subplot=4)
    ylabel!(L"{\mathrm{pdf()}}", subplot=4)
    title!(L"\texttt{case500}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/diff_plot_loading.png")


    # iterations vs time plot data

    it5_ptdf_wf = c5_ptdf_f["rfinal"]["final"]["iterations"]
    it5_ptdf_wof = c5_ptdf_wof["rfinal"]["final"]["iterations"]
    it5_wf = 3
    it5_wof = 5

    t5_ptdf_wf = c5_ptdf_f["t_scopf"]
    t5_ptdf_wof = c5_ptdf_wof["t_scopf"]
    t5_wf = c5["t_scopf"]
    t5_wof = c5_wof["t_scopf"]

    it24_ptdf_wf = c24_ptdf_f["rfinal"]["final"]["iterations"]
    it24_ptdf_wof = 1
    it24_wf = 1
    it24_wof = 1

    t24_ptdf_wf = 3.905
    t24_ptdf_wof = 16.905
    t24_wf = c24["t_scopf"]
    t24_wof = 36.408

    it67_ptdf_wf = c67_ptdf_f["rfinal"]["final"]["iterations"]
    it67_ptdf_wof = 7
    it67_wf = 5 
    it67_wof = 8

    t67_ptdf_wf = c67_ptdf_f["t_scopf"]
    t67_ptdf_wof = 28.99
    t67_wf = c67["t_scopf"]
    t67_wof = c67_wof["t_scopf"]

    it500_ptdf_wf = c500_ptdf_f["rfinal"]["final"]["iterations"]
    it500_ptdf_wof = 4
    it500_wf = 3
    it500_wof = 5

    t500_ptdf_wf = 5.7
    t500_ptdf_wof = 20.52
    t500_wf = 49.213
    t500_wof = 392.327
    
    # iterations vs time plot

    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :bottomright, legendfont = 6)

    plot!((0:1:it5_ptdf_wf)*(t5_ptdf_wf/it5_ptdf_wf), 0:1:it5_ptdf_wf, color = "blue", xlims=[0,15], label = false, subplot=1)
    plot!((0:1:it5_ptdf_wof)*(t5_ptdf_wof/it5_ptdf_wof), 0:1:it5_ptdf_wof, linestyle = :dashdot, color = :red, label = false, subplot=1)
    plot!((0:1:it5_wf)*(t5_wf/it5_wf), 0:1:it5_wf, linestyle = :dot, color = :green, label = false, subplot=1)
    plot!((0:1:it5_wof)*(t5_wof/it5_wof), 0:1:it5_wof, linestyle = :dash, color = :orange, label = false, subplot=1)
    ylabel!(L"{\mathrm{iterations(-)}}", subplot=1)
    title!(L"\texttt{case5}", titlefontsize = 10, subplot=1)

    plot!((0:1:it24_ptdf_wf)*(t24_ptdf_wf/it24_ptdf_wf), 0:1:it24_ptdf_wf, color = "blue", xlims =[0,50], yticks=(0:1:1, [L"0", L"1"]), label = L"{\mathrm{proposed\;model\;w\;filter}}", subplot=2)
    plot!((0:1:it24_ptdf_wof)*(t24_ptdf_wof/it24_ptdf_wof), 0:1:it24_ptdf_wof, linestyle = :dashdot, color = :red, label = L"{\mathrm{proposed\;model\;w}\slash\mathrm{o\;filter}}", subplot=2)
    plot!((0:1:it24_wf)*(t24_wf/it24_wf), 0:1:it24_wf, linestyle = :dot, color = :green, label = L"{\mathrm{TSMP\;model\;w\;filter}}", subplot=2)
    plot!((0:1:it24_wof)*(t24_wof/it24_wof), 0:1:it24_wof, linestyle = :dash, color = :orange, label = L"{\mathrm{TSMP\;model\;w}\slash\mathrm{o\;filter}}", subplot=2)
    ylabel!(L"{\mathrm{iterations(-)}}", subplot=2)
    title!(L"\texttt{case24}", titlefontsize = 10, subplot=2)

    plot!((0:1:it67_ptdf_wf)*(t67_ptdf_wf/it67_ptdf_wf), 0:1:it67_ptdf_wf, color = :blue, label = false, subplot=3)
    plot!((0:1:it67_ptdf_wof)*(t67_ptdf_wof/it67_ptdf_wof), 0:1:it67_ptdf_wof, linestyle = :dashdot, color = :red, label = false, subplot=3)
    plot!((0:1:it67_wf)*(t67_wf/it67_wf), 0:1:it67_wf, linestyle = :dot, color = :green, label = false, subplot=3)
    plot!((0:1:it67_wof)*(t67_wof/it67_wof), 0:1:it67_wof, linestyle = :dash, color = :orange, label = false, subplot=3)
    xlabel!(L"{{\mathrm{Time(s)}}}", subplot=3)
    ylabel!(L"{\mathrm{iterations(-)}}", subplot=3)
    title!(L"\texttt{case67}", titlefontsize = 10, subplot=3)

    plot!((0:1:it500_ptdf_wf)*(t500_ptdf_wf/it500_ptdf_wf), 0:1:it500_ptdf_wf, color = :blue, label = false, subplot=4) # ylims = [0,4], yticks=(0:1:4, [L"0.0", L"1.0", L"2.0", L"3.0", L"4.0"])
    plot!((0:1:it500_ptdf_wof)*(t500_ptdf_wof/it500_ptdf_wof), 0:1:it500_ptdf_wof, linestyle = :dashdot, color = :red, label = false, subplot=4)
    plot!((0:1:it500_wf)*(t500_wf/it500_wf), 0:1:it500_wf, linestyle = :dot, color = :green, label = false, subplot=4)
    plot!((0:1:it500_wof)*(t500_wof/it500_wof), 0:1:it500_wof, linestyle = :dash, color = :orange, label = false, subplot=4)
    xlabel!(L"{{\mathrm{Time(s)}}}", subplot=4)
    ylabel!(L"{\mathrm{iterations(-)}}", subplot=4)
    title!(L"\texttt{case500}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/itr_time_plot.png")

    
    # pdef plot

    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :topright, legendfont = 6,)

    histogram!(sf5_bdc, bins = range(0, 100, length=20), bar_width=5, color = "red", label = "base", yticks=0:1:2, subplot=1)
    histogram!(sf5_fdc, bins = range(0, 100, length=20), bar_width=5, color = "blue", label = "final", subplot=1)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=1)
    title!(L"\texttt{case5\_acdc}", titlefontsize = 10, subplot=1)

    histogram!(sf24_bdc, bins = range(0, 100, length=20), bar_width=5, color = "red", label = "base", yticks=0:1:1, subplot=2)
    histogram!(sf24_fdc, bins = range(0, 100, length=20), bar_width=5, color = "blue", label = "final", subplot=2)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=2)
    title!(L"\texttt{case24\_3zones\_acdc}", titlefontsize = 10, subplot=2)

    histogram!(sf67_bdc, bins = range(0, 100, length=20), bar_width=5, color = "red", label = "base", yticks=0:1:1, subplot=3)
    histogram!(sf67_fdc, bins = range(0, 100, length=20), bar_width=5, color = "blue", label = "final", subplot=3)       
    xlabel!(L"{\mathrm{line\;loading(\%)}}", subplot=3)
    ylabel!(L"{\mathrm{count(-)}}", subplot=3)
    title!(L"\texttt{case67\_acdc}", titlefontsize = 10, subplot=3)

    histogram!(sf500_bdc, bins = range(0, 100, length=20), bar_width=5, color = "red", label = "base", yticks=0:1:2, subplot=4)
    histogram!(sf500_fdc, bins = range(0, 100, length=20), bar_width=5, color = "blue", label = "final", subplot=4)       
    xlabel!(L"{\mathrm{line\;loading(\%)}}", subplot=4)
    ylabel!(L"{\mathrm{count(-)}}", subplot=4)
    title!(L"\texttt{case500\_acdc}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/Norm_dcline_loading_ptdf.png")

    # slij plot

    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :topright, legendfont = 6)

    histogram!(sf5_b, bins = range(0, 100, length=20), color = "red", label = "base", yticks=0:1:2, subplot=1)
    histogram!(sf5_f, bins = range(0, 100, length=20), color = "blue", label = "final", subplot=1)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=1)
    title!(L"\texttt{case5\_acdc}", titlefontsize = 10, subplot=1)

    histogram!(sf24_b, bins = range(0, 100, length=20), color = "red", label = "base", yticks=0:2:10, subplot=2)
    histogram!(sf24_f, bins = range(0, 100, length=20), color = "blue", label = "final", subplot=2)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=2)
    title!(L"\texttt{case24\_3zones\_acdc}", titlefontsize = 10, subplot=2)

    histogram!(sf67_b, bins = range(0, 100, length=20), color = "red", label = "base", subplot=3)
    histogram!(sf67_f, bins = range(0, 100, length=20), color = "blue", label = "final", subplot=3)       
    xlabel!(L"{\mathrm{line\;loading(\%)}}", subplot=3)
    ylabel!(L"{\mathrm{count(-)}}", subplot=3)
    title!(L"\texttt{case67\_acdc}", titlefontsize = 10, subplot=3)

    histogram!(sf500_b, bins = range(0, 100, length=20), color = "red", label = "base", subplot=4)
    histogram!(sf500_f, bins = range(0, 100, length=20), color = "blue", label = "final", subplot=4)       
    xlabel!(L"{\mathrm{line\;loading(\%)}}", subplot=4)
    ylabel!(L"{\mathrm{count(-)}}", subplot=4)
    title!(L"\texttt{case500\_acdc}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/Norm_acline_loading_ptdf.png")

    # combined slij/pdef plot

    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :topright, legendfont = 6)

    histogram!(sf5_bacdc, bins = range(0, 100, length=50), color = "red", label = false, yticks=0:1:2, subplot=1)
    histogram!(sf5_facdc, bins = range(0, 100, length=50), color = "blue", label = false, subplot=1)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=1)
    title!(L"\texttt{case5}", titlefontsize = 10, subplot=1)

    histogram!(sf24_bacdc, bins = range(0, 100, length=50), color = "red", label = L"{\mathrm{base}}", yticks=0:2:10, subplot=2)
    histogram!(sf24_facdc, bins = range(0, 100, length=50), color = "blue", label = L"{\mathrm{preventive}}", subplot=2)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=2)
    title!(L"\texttt{case24}", titlefontsize = 10, subplot=2)

    histogram!(sf67_bacdc, bins = range(0, 100, length=50), color = "red", label = false, yticks=0:2:12, subplot=3)
    histogram!(sf67_facdc, bins = range(0, 100, length=50), color = "blue", label = false, subplot=3)       
    xlabel!(L"{\mathrm{ac-dc\;line\;loading(\%)}}", subplot=3)
    ylabel!(L"{\mathrm{count(-)}}", subplot=3)
    title!(L"\texttt{case67}", titlefontsize = 10, subplot=3)

    histogram!(sf500_bacdc, bins = range(0, 100, length=50), color = "red", label = false, subplot=4)
    histogram!(sf500_facdc, bins = range(0, 100, length=50), color = "blue", label = false, subplot=4)       
    xlabel!(L"{\mathrm{ac-dc\;line\;loading(\%)}}", subplot=4)
    ylabel!(L"{\mathrm{count(-)}}", subplot=4)
    title!(L"\texttt{case500}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/Norm_acdcline_loading.png")


    # gen/conv loadings

    #5  
    sg5_b = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_5["gen"][i]["pmax"].^2 .+ data_5["gen"][i]["qmax"].^2) for (i,gen) in c5["rfinal"]["base"]["solution"]["nw"]["0"]["gen"]])
    sc5_bac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_5["convdc"][i]["Pacmax"].^2 .+ data_5["convdc"][i]["Qacmax"].^2) for (i,conv) in c5["rfinal"]["base"]["solution"]["nw"]["0"]["convdc"]])
    sgc5_b = [sg5_b; sc5_bac]
    sg5_f = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_5["gen"][i]["pmax"].^2 .+ data_5["gen"][i]["qmax"].^2) for (i,gen) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["gen"]])
    sc5_fac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_5["convdc"][i]["Pacmax"].^2 .+ data_5["convdc"][i]["Qacmax"].^2) for (i,conv) in c5["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"]])
    sgc5_f = [sg5_f; sc5_fac]

    #24  
    sg24_b = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_24["gen"][i]["pmax"].^2 .+ data_24["gen"][i]["qmax"].^2) for (i,gen) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["gen"]])
    sc24_bac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_24["convdc"][i]["Pacmax"].^2 .+ data_24["convdc"][i]["Qacmax"].^2) for (i,conv) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["convdc"]])
    sgc24_b = [sg24_b; sc24_bac]
    sg24_f = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_24["gen"][i]["pmax"].^2 .+ data_24["gen"][i]["qmax"].^2) for (i,gen) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["gen"]])
    sc24_fac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_24["convdc"][i]["Pacmax"].^2 .+ data_24["convdc"][i]["Qacmax"].^2) for (i,conv) in c24["rfinal"]["base"]["solution"]["nw"]["0"]["convdc"]])
    sgc24_f = [sg24_f; sc24_fac]

    #67  
    sg67_b = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_67["gen"][i]["pmax"].^2 .+ data_67["gen"][i]["qmax"].^2) for (i,gen) in c67["rfinal"]["base"]["solution"]["nw"]["0"]["gen"]])
    sc67_bac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_67["convdc"][i]["Pacmax"].^2 .+ data_67["convdc"][i]["Qacmax"].^2) for (i,conv) in c67["rfinal"]["base"]["solution"]["nw"]["0"]["convdc"]])
    sgc67_b = [sg67_b; sc67_bac]
    sg67_f = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_67["gen"][i]["pmax"].^2 .+ data_67["gen"][i]["qmax"].^2) for (i,gen) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["gen"]])
    sc67_fac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_67["convdc"][i]["Pacmax"].^2 .+ data_67["convdc"][i]["Qacmax"].^2) for (i,conv) in c67["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"]])
    sgc67_f = [sg67_f; sc67_fac]

    #500  
    sg500_b = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_500["gen"][i]["pmax"].^2 .+ data_500["gen"][i]["qmax"].^2) for (i,gen) in c500["rfinal"]["base"]["solution"]["nw"]["0"]["gen"]])
    sc500_bac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_500["convdc"][i]["Pacmax"].^2 .+ data_500["convdc"][i]["Qacmax"].^2) for (i,conv) in c500["rfinal"]["base"]["solution"]["nw"]["0"]["convdc"]])
    sgc500_b = [sg500_b; sc500_bac]
    sg500_f = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_500["gen"][i]["pmax"].^2 .+ data_500["gen"][i]["qmax"].^2) for (i,gen) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["gen"]])
    sc500_fac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_500["convdc"][i]["Pacmax"].^2 .+ data_500["convdc"][i]["Qacmax"].^2) for (i,conv) in c500["rfinal"]["final"]["solution"]["nw"]["0"]["convdc"]])
    sgc500_f = [sg500_f; sc500_fac]

    # plot gen/conv loadings


    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :topright, legendfont = 6)

    histogram!(sgc5_b, bins = range(0, 100, length=50), color = "red", label = L"{\mathrm{base}}", yticks=0:1:2, subplot=1)
    histogram!(sgc5_f, bins = range(0, 100, length=50), color = "blue", label = L"{\mathrm{preventive}}", subplot=1)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=1)
    title!(L"\texttt{case5}", titlefontsize = 10, subplot=1)

    histogram!(sgc24_b, bins = range(0, 100, length=50), color = "red", label = false, yticks=0:2:10, subplot=2)
    histogram!(sgc24_f, bins = range(0, 100, length=50), color = "blue", label = false, subplot=2)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=2)
    title!(L"\texttt{case24}", titlefontsize = 10, subplot=2)

    histogram!(sgc67_b, bins = range(0, 100, length=50), color = "red", label = false, yticks=0:2:12, subplot=3)
    histogram!(sgc67_f, bins = range(0, 100, length=50), color = "blue", label = false, subplot=3)       
    xlabel!(L"{\mathrm{gen-conv\;loading(\%)}}", subplot=3)
    ylabel!(L"{\mathrm{count(-)}}", subplot=3)
    title!(L"\texttt{case67}", titlefontsize = 10, subplot=3)

    histogram!(sgc500_b, bins = range(0, 100, length=50), color = "red", label = false, subplot=4)
    histogram!(sgc500_f, bins = range(0, 100, length=50), color = "blue", label = false, subplot=4)       
    xlabel!(L"{\mathrm{gen-conv\;loading(\%)}}", subplot=4)
    ylabel!(L"{\mathrm{count(-)}}", subplot=4)
    title!(L"\texttt{case500}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/Norm_genconv_loading.png")


    # NEM ac-dc line loading data

    # Proposed

    #1 Benchmark  
    sf1_bp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_benchmark["rbase"]["solution"]["branch"]])
    sf1_bdcp = 100*[branchdc["pf"]/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_benchmark["rbase"]["solution"]["branchdc"]]
    sf1_bacdcp = [sf1_bp; sf1_bdcp]
    sf1_fp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_benchmark["rfinal"]["final"]["solution"]["branch"]])
    sf1_fdcp = 100*[branchdc["pf"]/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_benchmark["rfinal"]["final"]["solution"]["branchdc"]]
    sf1_facdcp = [sf1_fp; sf1_fdcp]

    #2 Peak  
    sf2_bp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_peak["rbase"]["solution"]["branch"]])
    sf2_bdcp = 100*[branchdc["pf"]/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_peak["rbase"]["solution"]["branchdc"]]
    sf2_bacdcp = [sf2_bp; sf2_bdcp]
    sf2_fp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_peak["rfinal"]["final"]["solution"]["branch"]])
    sf2_fdcp = 100*[branchdc["pf"]/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_peak["rfinal"]["final"]["solution"]["branchdc"]]
    sf2_facdcp = [sf2_fp; sf2_fdcp]

    #3 min  
    sf3_bp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_min["rbase"]["solution"]["branch"]])
    sf3_bdcp = 100*[branchdc["pf"]/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_min["rbase"]["solution"]["branchdc"]]
    sf3_bacdcp = [sf3_bp; sf3_bdcp]
    sf3_fp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_min["rfinal"]["final"]["solution"]["branch"]])
    sf3_fdcp = 100*[branchdc["pf"]/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_min["rfinal"]["final"]["solution"]["branchdc"]]
    sf3_facdcp = [sf3_fp; sf3_fdcp]

    #4 rez  
    sf4_bp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_rez["rbase"]["solution"]["branch"]])
    sf4_bdcp = 100*[branchdc["pf"]/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_rez["rbase"]["solution"]["branchdc"]]
    sf4_bacdcp = [sf4_bp; sf4_bdcp]
    sf4_fp = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_rez["rfinal"]["final"]["solution"]["branch"]])
    sf4_fdcp = 100*[branchdc["pf"]/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_rez["rfinal"]["final"]["solution"]["branchdc"]]
    sf4_facdcp = [sf4_fp; sf4_fdcp]


    # nem combined slij/pdef plot

    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :topright, legendfont = 6)

    histogram!(sf1_bacdcp, bins = range(0, 100, length=50), color = "red", alpha = 1, label = false, subplot=1)
    histogram!(sf1_facdcp, bins = range(0, 100, length=50), color = "white", alpha = 1, label = false, subplot=1)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=1)
    title!(L"\mathrm{scenario\;(1)}", titlefontsize = 10, subplot=1)

    histogram!(sf2_bacdcp, bins = range(0, 100, length=50), color = "red", ylims= [0,400], alpha = 1, label = L"{\mathrm{base}}", subplot=2)
    histogram!(sf2_facdcp, bins = range(0, 100, length=50), color = "blue", alpha = 1, label = L"{\mathrm{preventive}}", subplot=2)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=2)
    title!(L"\mathrm{scenario\;(2)}", titlefontsize = 10, subplot=2)

    histogram!(sf3_bacdcp, bins = range(0, 100, length=50), color = "red", alpha = 1,label = false, subplot=3)
    histogram!(sf3_facdcp, bins = range(0, 100, length=50), color = "blue", alpha = 1, label = false, subplot=3)       
    xlabel!(L"{\mathrm{ac-dc\;line\;loading(\%)}}", subplot=3)
    ylabel!(L"{\mathrm{count(-)}}", subplot=3)
    title!(L"\mathrm{scenario\;(3)}", titlefontsize = 10, subplot=3)

    histogram!(sf4_bacdcp, bins = range(0, 100, length=50), color = "red", ylims = [0,400], alpha = 1, label = false, subplot=4)
    histogram!(sf4_facdcp, bins = range(0, 100, length=50), color = "blue", alpha = 1, label = false, subplot=4)       
    xlabel!(L"{\mathrm{ac-dc\;line\;loading(\%)}}", subplot=4)
    ylabel!(L"{\mathrm{count(-)}}", subplot=4)
    title!(L"\mathrm{scenario\;(4)}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/Norm_acdcline_loading_nem.png")

    # NEM gen/conv loadings

    #1 Benchmark   
    sg1_b = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_nem["gen"][i]["pmax"].^2 .+ data_nem["gen"][i]["qmax"].^2) for (i,gen) in nem_benchmark["rbase"]["solution"]["gen"]])
    sc1_bac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_nem["convdc"][i]["Pacmax"].^2 .+ data_nem["convdc"][i]["Qacmax"].^2) for (i,conv) in nem_benchmark["rbase"]["solution"]["convdc"]])
    sgc1_b = [sg1_b; sc1_bac]
    sg1_f = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_nem["gen"][i]["pmax"].^2 .+ data_nem["gen"][i]["qmax"].^2) for (i,gen) in nem_benchmark["rfinal"]["final"]["solution"]["gen"]])
    sc1_fac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_nem["convdc"][i]["Pacmax"].^2 .+ data_nem["convdc"][i]["Qacmax"].^2) for (i,conv) in nem_benchmark["rfinal"]["final"]["solution"]["convdc"]])
    sgc1_f = [sg1_f; sc1_fac]

    #2 Peak  
    sg2_b = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_nem["gen"][i]["pmax"].^2 .+ data_nem["gen"][i]["qmax"].^2) for (i,gen) in nem_peak["rbase"]["solution"]["gen"]])
    sc2_bac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_nem["convdc"][i]["Pacmax"].^2 .+ data_nem["convdc"][i]["Qacmax"].^2) for (i,conv) in nem_peak["rbase"]["solution"]["convdc"]])
    sgc2_b = [sg2_b; sc2_bac]
    sg2_f = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_nem["gen"][i]["pmax"].^2 .+ data_nem["gen"][i]["qmax"].^2) for (i,gen) in nem_peak["rfinal"]["final"]["solution"]["gen"]])
    sc2_fac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_nem["convdc"][i]["Pacmax"].^2 .+ data_nem["convdc"][i]["Qacmax"].^2) for (i,conv) in nem_peak["rfinal"]["final"]["solution"]["convdc"]])
    sgc2_f = [sg2_f; sc2_fac]

    #3 min  
    sg3_b = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_nem["gen"][i]["pmax"].^2 .+ data_nem["gen"][i]["qmax"].^2) for (i,gen) in nem_min["rbase"]["solution"]["gen"]])
    sc3_bac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_nem["convdc"][i]["Pacmax"].^2 .+ data_nem["convdc"][i]["Qacmax"].^2) for (i,conv) in nem_min["rbase"]["solution"]["convdc"]])
    sgc3_b = [sg3_b; sc3_bac]
    sg3_f = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_nem["gen"][i]["pmax"].^2 .+ data_nem["gen"][i]["qmax"].^2) for (i,gen) in nem_min["rfinal"]["final"]["solution"]["gen"]])
    sc3_fac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_nem["convdc"][i]["Pacmax"].^2 .+ data_nem["convdc"][i]["Qacmax"].^2) for (i,conv) in nem_min["rfinal"]["final"]["solution"]["convdc"]])
    sgc3_f = [sg3_f; sc3_fac]

    #4 rez  
    sg4_b = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_nem["gen"][i]["pmax"].^2 .+ data_nem["gen"][i]["qmax"].^2) for (i,gen) in nem_rez["rbase"]["solution"]["gen"]])
    sc4_bac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_nem["convdc"][i]["Pacmax"].^2 .+ data_nem["convdc"][i]["Qacmax"].^2) for (i,conv) in nem_rez["rbase"]["solution"]["convdc"]])
    sgc4_b = [sg4_b; sc4_bac]
    sg4_f = 100*([sqrt.(gen["pg"].^2 .+ gen["qg"].^2)/sqrt.(data_nem["gen"][i]["pmax"].^2 .+ data_nem["gen"][i]["qmax"].^2) for (i,gen) in nem_rez["rfinal"]["final"]["solution"]["gen"]])
    sc4_fac = 100*([sqrt.(conv["pgrid"].^2 .+ conv["qgrid"].^2)/sqrt.(data_nem["convdc"][i]["Pacmax"].^2 .+ data_nem["convdc"][i]["Qacmax"].^2) for (i,conv) in nem_rez["rfinal"]["final"]["solution"]["convdc"]])
    sgc4_f = [sg4_f; sc4_fac]

    # NEM plot gen/conv loadings


    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :topleft, legendfont = 6)

    histogram!(sgc1_b, bins = range(0, 100, length=50), color = "red", ylims = [0,40], label = false, subplot=1)
    histogram!(sgc1_f, bins = range(0, 100, length=50), color = "blue", alpha = 0.5, label = false, subplot=1)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=1)
    title!(L"\mathrm{scenario\;(1)}", titlefontsize = 10, subplot=1)

    histogram!(sgc2_b, bins = range(0, 100, length=50), color = "red", label = L"{\mathrm{base}}", subplot=2)
    histogram!(sgc2_f, bins = range(0, 100, length=50), color = "blue", alpha = 0.5, label = L"{\mathrm{preventive}}", subplot=2)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=2)
    title!(L"\mathrm{scenario\;(2)}", titlefontsize = 10, subplot=2)

    histogram!(sgc3_b, bins = range(0, 100, length=50), color = "red", ylims = [0,40], label = false, subplot=3)
    histogram!(sgc3_f, bins = range(0, 100, length=50), color = "blue", alpha = 0.5, label = false, subplot=3)       
    xlabel!(L"{\mathrm{gen-conv\;loading(\%)}}", subplot=3)
    ylabel!(L"{\mathrm{count(-)}}", subplot=3)
    title!(L"\mathrm{scenario\;(3)}", titlefontsize = 10, subplot=3)

    histogram!(sgc4_b, bins = range(0, 100, length=50), color = "red", label = false, subplot=4)
    histogram!(sgc4_f, bins = range(0, 100, length=50), color = "blue", alpha = 0.5, label = false, subplot=4)       
    xlabel!(L"{\mathrm{gen-conv\;loading(\%)}}", subplot=4)
    ylabel!(L"{\mathrm{count(-)}}", subplot=4)
    title!(L"\mathrm{scenario\;(4)}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/Norm_genconv_loading_nem1.png")

    # nem voltage plot

    #1 Benchmark   
    v1_b = [bus["vm"] for (i,bus) in nem_benchmark["rbase"]["solution"]["bus"]]
    v1_bdc = [busdc["vm"] for (i,busdc) in nem_benchmark["rbase"]["solution"]["busdc"]]
    v1_b = [v1_b; v1_bdc]
    v1_f = [bus["vm"] for (i,bus) in nem_benchmark["rfinal"]["final"]["solution"]["bus"]]
    v1_fdc = [busdc["vm"] for (i,busdc) in nem_benchmark["rfinal"]["final"]["solution"]["busdc"]]
    v1_f = [v1_f; v1_fdc]

    #2 Peak  
    v2_b = [bus["vm"] for (i,bus) in nem_peak["rbase"]["solution"]["bus"]]
    v2_bdc = [busdc["vm"] for (i,busdc) in nem_peak["rbase"]["solution"]["busdc"]]
    v2_b = [v2_b; v2_bdc]
    v2_f = [bus["vm"] for (i,bus) in nem_peak["rfinal"]["final"]["solution"]["bus"]]
    v2_fdc = [busdc["vm"] for (i,busdc) in nem_peak["rfinal"]["final"]["solution"]["busdc"]]
    v2_f = [v2_f; v2_fdc]

    #3 min  
    v3_b = [bus["vm"] for (i,bus) in nem_min["rbase"]["solution"]["bus"]]
    v3_bdc = [busdc["vm"] for (i,busdc) in nem_min["rbase"]["solution"]["busdc"]]
    v3_b = [v3_b; v3_bdc]
    v3_f = [bus["vm"] for (i,bus) in nem_min["rfinal"]["final"]["solution"]["bus"]]
    v3_fdc = [busdc["vm"] for (i,busdc) in nem_min["rfinal"]["final"]["solution"]["busdc"]]
    v3_f = [v3_f; v3_fdc]

    #4 rez  
    v4_b = [bus["vm"] for (i,bus) in nem_rez["rbase"]["solution"]["bus"]]
    v4_bdc = [busdc["vm"] for (i,busdc) in nem_rez["rbase"]["solution"]["busdc"]]
    v4_b = [v4_b; v4_bdc]
    v4_f = [bus["vm"] for (i,bus) in nem_rez["rfinal"]["final"]["solution"]["bus"]]
    v4_fdc = [busdc["vm"] for (i,busdc) in nem_rez["rfinal"]["final"]["solution"]["busdc"]]
    v4_f = [v4_f; v4_fdc]

    # nem plot
    plt = plot(layout=(2,2), size = (500,300), left_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,    
                grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend = :topleft, legendfont = 6)

    histogram!(v1_b, bins = range(0.90, 1.1, length=50), color = "red", ylims = [0,140], label = false, subplot=1)
    histogram!(v1_f, bins = range(0.90, 1.1, length=50), color = "blue", alpha = 1, label = false, subplot=1)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=1)
    title!(L"\mathrm{scenario\;(1)}", titlefontsize = 10, subplot=1)

    histogram!(v2_b, bins = range(0.90, 1.1, length=50), color = "red", ylims = [0,140], label = L"{\mathrm{base}}", subplot=2)
    histogram!(v2_f, bins = range(0.90, 1.1, length=50), color = "blue", alpha = 1, label = L"{\mathrm{preventive}}", subplot=2)       
    ylabel!(L"{\mathrm{count(-)}}", subplot=2)
    title!(L"\mathrm{scenario\;(2)}", titlefontsize = 10, subplot=2)

    histogram!(v3_b, bins = range(0.90, 1.1, length=50), color = "red", ylims = [0,140], label = false, subplot=3)
    histogram!(v3_f, bins = range(0.90, 1.1, length=50), color = "blue", alpha = 1, label = false, subplot=3)       
    xlabel!(L"{\mathrm{ac-dc\;voltage\;magnitude(pu)}}", subplot=3)
    ylabel!(L"{\mathrm{count(-)}}", subplot=3)
    title!(L"\mathrm{scenario\;(3)}", titlefontsize = 10, subplot=3)

    histogram!(v4_b, bins = range(0.90, 1.1, length=50), color = "red", ylims = [0,140], label = false, subplot=4)
    histogram!(v4_f, bins = range(0.90, 1.1, length=50), color = "blue", alpha = 1, label = false, subplot=4)       
    xlabel!(L"{\mathrm{ac-dc\;voltage\;magnitude(pu)}}", subplot=4)
    ylabel!(L"{\mathrm{count(-)}}", subplot=4)
    title!(L"\mathrm{scenario\;(4)}", titlefontsize = 10, subplot=4)

    savefig("./plots_ptdf/voltage_nem.png")




    #5
    gcont5 = [idx for (idx, label, type) in data_5["gen_contingencies"]]
    bcont5 = [idx for (idx, label, type) in data_5["branch_contingencies"]]
    bdccont5 = [idx for (idx, label, type) in data_5["branchdc_contingencies"]]
    gcont5_u = [idx for (idx, label, type) in c5_ptdf_f["rfinal"]["gen_contingencies_unsecure"]]
    bcont5_u = [idx for (idx, label, type) in c5_ptdf_f["rfinal"]["branch_contingencies_unsecure"]]
    bdccont5_u = [idx for (idx, label, type) in c5_ptdf_f["rfinal"]["branchdc_contingencies_unsecure"]]
   

    #24
    gcont24 = [idx for (idx, label, type) in data_24["gen_contingencies"]]
    bcont24 = [idx for (idx, label, type) in data_24["branch_contingencies"]]
    bdccont24 = [idx for (idx, label, type) in data_24["branchdc_contingencies"]]
    gcont24_u = [idx for (idx, label, type) in c24_ptdf_f["rfinal"]["gen_contingencies_unsecure"]]
    bcont24_u = [idx for (idx, label, type) in c24_ptdf_f["rfinal"]["branch_contingencies_unsecure"]]
    bdccont24_u = [idx for (idx, label, type) in c24_ptdf_f["rfinal"]["branchdc_contingencies_unsecure"]]

    #67
    gcont67 = [idx for (idx, label, type) in data_67["gen_contingencies"]]
    bcont67 = [idx for (idx, label, type) in data_67["branch_contingencies"]]
    bdccont67 = [idx for (idx, label, type) in data_67["branchdc_contingencies"]]
    gcont67_u = [idx for (idx, label, type) in c67_ptdf_f["rfinal"]["gen_contingencies_unsecure"]]
    bcont67_u = [idx for (idx, label, type) in c67_ptdf_f["rfinal"]["branch_contingencies_unsecure"]]
    bdccont67_u = [idx for (idx, label, type) in c67_ptdf_f["rfinal"]["branchdc_contingencies_unsecure"]]
    
    #500
    gcont500 = [idx for (idx, label, type) in data_500["gen_contingencies"]]
    bcont500 = [idx for (idx, label, type) in data_500["branch_contingencies"]]
    bdccont500 = [idx for (idx, label, type) in data_500["branchdc_contingencies"]]
    gcont500_u = [idx for (idx, label, type) in c500_ptdf_f["rfinal"]["gen_contingencies_unsecure"]]
    bcont500_u = [idx for (idx, label, type) in c500_ptdf_f["rfinal"]["branch_contingencies_unsecure"]]
    bdccont500_u = [idx for (idx, label, type) in c500_ptdf_f["rfinal"]["branchdc_contingencies_unsecure"]]


    #conts plot
    plt = plot(layout=(1,5), size = (600,400), left_margin = [1mm 0mm], right_margin = [1mm 0mm], dpi = 600, xformatter=:latex, yformatter=:latex, xguidefontsize=8, yguidefontsize=8,
    grid = true, gridalpha = 0.5, gridstyle = :dash, fg_color_grid = "black", fg_color_minorgrid = "black", legend=:topright, legendfont = 7, foreground_color_legend = nothing)

    #5
    plot!(ones(1:length(gcont5)),gcont5, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "blue", label = false, xlims=[0,4], subplot=1)
    plot!(ones(1:length(gcont5_u)),gcont5_u, seriestype = :scatter, markersize = 4, markercolor = "blue", label = false, subplot=1)
    plot!(2*ones(1:length(bcont5)),bcont5, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "red", label = false, subplot=1)
    plot!(2*ones(1:length(bcont5_u)),bcont5_u, seriestype = :scatter, markersize = 4, markercolor = "red", label = false, subplot=1)
    plot!(3*ones(1:length(bdccont5)),bdccont5, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "green", label = false, subplot=1)
    plot!(3*ones(1:length(bdccont5_u)),bdccont5_u, seriestype = :scatter, markersize = 4, markercolor = "green", label = false, subplot=1)
    plot!(xticks=([2], [L"\texttt{case5\_acdc}"]), subplot=1) 
    ylabel!(L"{\mathrm{contingency\;index}}", subplot=1)

    #24
    plot!(ones(1:length(gcont24)),gcont24, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "blue", label = false, xlims=[0,4], ylims=[0,80], subplot=2)
    plot!(ones(1:length(gcont24_u)),gcont24_u, seriestype = :scatter, markersize = 4, markercolor = "blue", label = false, subplot=2)
    plot!(2*ones(1:length(bcont24)),bcont24, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "red", label = false, subplot=2)
    plot!(2*ones(1:length(bcont24_u)),bcont24_u, seriestype = :scatter, markersize = 4, markercolor = "red", label = false, subplot=2)
    plot!(3*ones(1:length(bdccont24)),bdccont24, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "green", label = false, subplot=2)
    plot!(3*ones(1:length(bdccont24_u)),bdccont24_u, seriestype = :scatter, markersize = 4, markercolor = "green", label = false, subplot=2)
    plot!(xticks=([2], [L"\texttt{case24\_3zones\_acdc}"]), subplot=2)
    ylabel!(L"{\mathrm{contingency\;index}}", subplot=2)

    #67
    plot!(ones(1:length(gcont67)),gcont67, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "blue", label = false, xlims=[0,4], subplot=3)
    plot!(ones(1:length(gcont67_u)),gcont67_u, seriestype = :scatter, markersize = 4, markercolor = "blue", label = false, subplot=3)
    plot!(2*ones(1:length(bcont67)),bcont67, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "red", label = false, subplot=3)
    plot!(2*ones(1:length(bcont67_u)),bcont67_u, seriestype = :scatter, markersize = 4, markercolor = "red", label = false, subplot=3)
    plot!(3*ones(1:length(bdccont67)),bdccont67, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "green", label = false, subplot=3)
    plot!(3*ones(1:length(bdccont67_u)),bdccont67_u, seriestype = :scatter, markersize = 4, markercolor = "green", label = false, subplot=3)
    plot!(xticks=([2], [L"\texttt{case67\_acdc}"]), subplot=3)
    ylabel!(L"{\mathrm{contingency\;index}}", subplot=3)

    #500
    plot!(ones(1:length(gcont500)),gcont500, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "blue", color = "blue", label = false, xlims=[0,4], subplot=4)
    plot!(ones(1:length(gcont500_u)),gcont500_u, seriestype = :scatter, markersize = 4, markercolor = "blue", label = false, subplot=4)
    plot!(2*ones(1:length(bcont500)),bcont500, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "red", label = false, subplot=4)
    plot!(2*ones(1:length(bcont500_u)),bcont500_u, seriestype = :scatter, markersize = 4, markercolor = "red", label = false, subplot=4)
    plot!(3*ones(1:length(bdccont500)),bdccont500, seriestype = :scatter, markersize = 4, markercolor = "white", markerstrokecolor = "green", label = false, subplot=4)
    plot!(3*ones(1:length(bdccont500_u)),bdccont500_u, seriestype = :scatter, markersize = 4, markercolor = "green", label = false, subplot=4)
    plot!(xticks=([2], [L"\texttt{case500\_acdc}"]), subplot=4)
    ylabel!(L"{\mathrm{contingency\;index}}", subplot=4)

    #legend fake plot
    plot!(ones(1:length(gcont5)),gcont5, seriestype = :scatter, markersize = 3, markercolor = "white", markerstrokecolor = "blue", label = (L"\;\;\mathrm{secure\;generator}"), subplot=5, grid=false, showaxis=false, xlims=[4,20])
    plot!(ones(1:length(gcont5_u)),gcont5_u, seriestype = :scatter, markersize = 3, markercolor = "blue", label = (L"\;\;\mathrm{unsecure\;generator}"), subplot=5, grid=false, showaxis=false)
    plot!(2*ones(1:length(bcont5)),bcont5, seriestype = :scatter, markersize = 3, markercolor = "white", markerstrokecolor = "red", label = (L"\;\;\mathrm{secure\;ac\;branch}"), subplot=5, grid=false, showaxis=false)
    plot!(2*ones(1:length(bcont5_u)),bcont5_u, seriestype = :scatter, markersize = 3, markercolor = "red", label = (L"\;\;\mathrm{unsecure\;ac\;branch}"), subplot=5, grid=false, showaxis=false)
    plot!(3*ones(1:length(bdccont5)),bdccont5, seriestype = :scatter, markersize = 3, markercolor = "white", markerstrokecolor = "green", label = (L"\;\;\mathrm{secure\;dc\;branch}"), subplot=5, grid=false, showaxis=false)
    plot!(3*ones(1:length(bdccont5_u)),bdccont5_u, seriestype = :scatter, markersize = 3, markercolor = "green", label = (L"\;\;\mathrm{unsecure\;dc\;branch}"), subplot=5, grid=false, showaxis=false)


    savefig("./plots_ptdf/secure_unsecure_contingencies_ptdf.png")
     
    # nem plots and QGIS visualizations
    using CSV, DataFrames, HDF5, JLD
    
    nem_bus_coordinates = c5_ptdf_f = load("./data/nem_bus_coordinates.jld")["data"]

    for (i, bus) in data_nem["bus"]
        if bus["name"] == nem_bus_coordinates[i]["name"]
            bus["x_coordinate"] = nem_bus_coordinates[i]["x_coordinate"]
            bus["y_coordinate"] = nem_bus_coordinates[i]["y_coordinate"]
        end
    end

    cct_type = []
    cct_element =[]
    f_bus = []
    t_bus = []
    f_bus_x = []
    f_bus_y = []
    t_bus_x = []
    t_bus_y = []
    linestring = []

    cct_typedc = []
    cct_elementdc =[]
    f_busdc = []
    t_busdc = []
    f_busdc_x = []
    f_busdc_y = []
    t_busdc_x = []
    t_busdc_y = []
    linestringdc = []

    s = 500

    for (i,branch) in data_nem["branch"]
        push!(cct_type, "branch")
        push!(cct_element, branch["name"])
        push!(f_bus, branch["f_bus"])
        push!(t_bus, branch["t_bus"])
        push!(f_bus_x, data_nem["bus"]["$(branch["f_bus"])"]["x_coordinate"]/s)
        push!(f_bus_y, data_nem["bus"]["$(branch["f_bus"])"]["y_coordinate"]/s)
        push!(t_bus_x, data_nem["bus"]["$(branch["t_bus"])"]["x_coordinate"]/s)
        push!(t_bus_y, data_nem["bus"]["$(branch["t_bus"])"]["y_coordinate"]/s)
        if (data_nem["bus"]["$(branch["f_bus"])"]["name"][5] == '5' || data_nem["bus"]["$(branch["t_bus"])"]["name"][5] == '5') 
            push!(linestring, "LINESTRING($(data_nem["bus"]["$(branch["f_bus"])"]["x_coordinate"]/s) $( (data_nem["bus"]["$(branch["f_bus"])"]["y_coordinate"]/s) -2), $(data_nem["bus"]["$(branch["t_bus"])"]["x_coordinate"]/s) $( (data_nem["bus"]["$(branch["t_bus"])"]["y_coordinate"]/s)-2))")
        else
            push!(linestring, "LINESTRING($(data_nem["bus"]["$(branch["f_bus"])"]["x_coordinate"]/s) $(data_nem["bus"]["$(branch["f_bus"])"]["y_coordinate"]/s), $(data_nem["bus"]["$(branch["t_bus"])"]["x_coordinate"]/s) $(data_nem["bus"]["$(branch["t_bus"])"]["y_coordinate"]/s))")
        end 
    end
    for (i,branchdc) in data_nem["branchdc"]
        push!(cct_typedc, "branchdc")
        push!(cct_elementdc, "branchdc_$i")
        push!(f_busdc, data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])
        push!(t_busdc, data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])
        push!(f_busdc_x, data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["x_coordinate"]/s)
        push!(f_busdc_y, data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["y_coordinate"]/s)
        push!(t_busdc_x, data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["x_coordinate"]/s)
        push!(t_busdc_y, data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["y_coordinate"]/s)
        if (data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["name"][5] == '5' || data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["name"][5] == '5') 
            if data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["name"] == "bus_5150"
                push!(linestringdc, "LINESTRING($(data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["x_coordinate"]/s) $( (data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["y_coordinate"]/s) -0), $(data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["x_coordinate"]/s) $( (data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["y_coordinate"]/s)-2))")
            else
                push!(linestringdc, "LINESTRING($(data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["x_coordinate"]/s) $( (data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["y_coordinate"]/s) -2), $(data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["x_coordinate"]/s) $( (data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["y_coordinate"]/s)-2))")
            end
        else
            push!(linestringdc, "LINESTRING($(data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["x_coordinate"]/s) $(data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["fbusdc"])"]["busac_i"])"]["y_coordinate"]/s), $(data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["x_coordinate"]/s) $(data_nem["bus"]["$(data_nem["convdc"]["$(branchdc["tbusdc"])"]["busac_i"])"]["y_coordinate"]/s))")
        end
    end
    
    # Embedding results
    # Scenario 1 Benchmark
    slijnem_b = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_ptdf_f["rbase"]["solution"]["branch"]])
    slijnem_f = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_ptdf_f["rfinal"]["final"]["solution"]["branch"]])
    pdefnem_b = 100*[abs(branchdc["pf"])/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_ptdf_f["rbase"]["solution"]["branchdc"]]
    pdefnem_f = 100*[abs(branchdc["pf"])/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_ptdf_f["rfinal"]["final"]["solution"]["branchdc"]]
    append!(pdefnem_b,[0 0 0 0 0]')
    append!(pdefnem_f,[0 0 0 0 0]')
    
    # Scenario 2 peak load
    slijnem_b_p = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_ptdf_fpeak["rbase"]["solution"]["branch"]])
    slijnem_f_p = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_ptdf_fpeak["rfinal"]["final"]["solution"]["branch"]])
    pdefnem_b_p = 100*[abs(branchdc["pf"])/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_ptdf_fpeak["rbase"]["solution"]["branchdc"]]
    pdefnem_f_p = 100*[abs(branchdc["pf"])/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_ptdf_fpeak["rfinal"]["final"]["solution"]["branchdc"]]
    append!(pdefnem_b_p,[0 0 0 0 0]')
    append!(pdefnem_f_p,[0 0 0 0 0]')

    # Scenario 3 min load 
    slijnem_b_m = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_ptdf_fmin["rbase"]["solution"]["branch"]])
    slijnem_f_m = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_ptdf_fmin["rfinal"]["final"]["solution"]["branch"]])
    pdefnem_b_m = 100*[abs(branchdc["pf"])/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_ptdf_fmin["rbase"]["solution"]["branchdc"]]
    pdefnem_f_m = 100*[abs(branchdc["pf"])/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_ptdf_fmin["rfinal"]["final"]["solution"]["branchdc"]]
    append!(pdefnem_b_m,[0 0 0 0 0]')
    append!(pdefnem_f_m,[0 0 0 0 0]')

    # Scenario 3 min load 
    slijnem_b_r = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_ptdf_frez["rbase"]["solution"]["branch"]])
    slijnem_f_r = 100*([sqrt.(branch["pf"].^2 .+ branch["qf"].^2)/data_nem["branch"][i]["rate_c"] for (i,branch) in nem_ptdf_frez["rfinal"]["final"]["solution"]["branch"]])
    pdefnem_b_r = 100*[abs(branchdc["pf"])/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_ptdf_frez["rbase"]["solution"]["branchdc"]]
    pdefnem_f_r = 100*[abs(branchdc["pf"])/data_nem["branchdc"][i]["rateC"] for (i,branchdc) in nem_ptdf_frez["rfinal"]["final"]["solution"]["branchdc"]]


    output_ac = DataFrame(cct_type = cct_type, cct_element = cct_element, f_bus = f_bus, t_bus = t_bus, f_bus_x = f_bus_x, f_bus_y = f_bus_y, t_bus_x = t_bus_x, t_bus_y = t_bus_y, linestring = linestring,
    slijnem_b = slijnem_b, slijnem_f = slijnem_f, slijnem_b_p = slijnem_b_p, slijnem_f_p = slijnem_f_p, slijnem_b_m = slijnem_b_m, slijnem_f_m = slijnem_f_m, slijnem_b_r = slijnem_b_r, slijnem_f_r = slijnem_f_r) 
    output_dc = DataFrame(cct_typedc = [], cct_elementdc = [], f_busdc = [], t_busdc = [], f_busdc_x = [], f_busdc_y = [], t_busdc_x = [], t_busdc_y = [], linestringdc = [], pdefnem_b = [], pdefnem_f = [], pdefnem_b_p = [], pdefnem_f_p = [], pdefnem_b_m = [], pdefnem_f_m = [], pdefnem_b_r = [], pdefnem_f_r = [])
    append!(output_dc.cct_typedc, cct_typedc)
    append!(output_dc.cct_elementdc, cct_elementdc)
    append!(output_dc.f_busdc, f_busdc)
    append!(output_dc.t_busdc, t_busdc)
    append!(output_dc.f_busdc_x, f_busdc_x)
    append!(output_dc.f_busdc_y, f_busdc_y)
    append!(output_dc.t_busdc_x, t_busdc_x)
    append!(output_dc.t_busdc_y, t_busdc_y)
    append!(output_dc.linestringdc, linestringdc)
    append!(output_dc.pdefnem_b, pdefnem_b)
    append!(output_dc.pdefnem_f, pdefnem_f)
    append!(output_dc.pdefnem_b_p, pdefnem_b_p)
    append!(output_dc.pdefnem_f_p, pdefnem_f_p)
    append!(output_dc.pdefnem_b_m, pdefnem_b_m)
    append!(output_dc.pdefnem_f_m, pdefnem_f_m)
    append!(output_dc.pdefnem_b_r, pdefnem_b_r)
    append!(output_dc.pdefnem_f_r, pdefnem_f_r)
    

    CSV.write("./data/output_ac_s1.csv", output_ac)        
    CSV.write("./data/output_dc_s1.csv", output_dc)  






    # TODO generate dataframe for NEM base and final flows 
    # Scenario 1 = current
    # Scenario 2 = peak load
    # Scenario 3 = minimum load
    # Scenario 4 = with REZs
    # Scenario 5 = REZs and HVDC connections
    # Scenario 6 = REZs and HVAC connections
