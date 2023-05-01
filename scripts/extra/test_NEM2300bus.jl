using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained



nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6)  
lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


file = "./data/nem_2300bus.m"
network = parse_file(file)

network["dcline"]=Dict{String, Any}()

# Adding monopolar VIC_to_TAS HVDC Basslink with metallic return (modelled as bipolar(network["dcpol"] = 2)) & LCC converters "islcc" => 1

network["dcpol"] = 2
Basslink_Vic_bus_number = 2113              # "name" => "bus_5001" 
Basslink_Tas_bus_number = 2271              # "name" => "bus_5171"
Basslink_Vic_gen_id = 264                   # gen_5001_1 on bus_5001 has to be removed and its type has to change from 2 to 1
Basslink_Tas_gen_id = 265                   # gen_5171_1 on bus_5171 has to be removed and its type has to change from 2 to 1

delete!(network["gen"], "$Basslink_Vic_gen_id")
delete!(network["gen"], "$Basslink_Tas_gen_id")
network["bus"]["$Basslink_Vic_bus_number"]["bus_type"]  = 1
network["bus"]["$Basslink_Tas_bus_number"]["bus_type"]  = 1

network["busdc"]=Dict{String, Any}()
network["busdc"]["1"]=Dict("basekVdc" => 400, "source_id" => Any["busdc", 1], "Vdc" => 1.02937, "busdc_i" => 1, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 1, "Pdc" => 0)
network["busdc"]["2"]=Dict("basekVdc" => 400, "source_id" => Any["busdc", 2], "Vdc" => 1, "busdc_i" => 2, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 2, "Pdc" => 0)

network["branchdc"]=Dict{String, Any}()
network["branchdc"]["1"]=Dict{String, Any}()
network["branchdc"]["1"]=Dict("c" => 0, "r" => 0.00, "status" => 1, "rateB" => 500, "fbusdc" => 1, "source_id" => Any["branchdc", 1, 2, "Basslink" ], "rateA" => 500, "l" => 0, "index" => 1, "rateC" => 500, "tbusdc" => 2)     # dynamic 630MW

network["convdc"]=Dict{String, Any}()
network["convdc"]["1"]=Dict("dVdcset" => 0, "Vtar" => 1.02937, "Pacmax" => 500, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 12.5, "status" => 1, "Pdcset" => -410, "islcc" => 1, "LossA" => 0.0, "Qacmin" => 0, "rc" => 0.01, "source_id" => Any["convdc_Basslink_VIC_to_TAS", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => Basslink_Vic_bus_number, "tm" => 1, "type_dc" => 2, "Q_g" => -233, "LossB" => 0.0, "basekVac" => 500, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -500, "Qacmax" => 250, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -410, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # VIC to TAS 478MW       type_dc = 1/2/3 -> fix/slack/droop                                              
network["convdc"]["2"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 500, "filter" => 1, "reactor" => 1, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 12.5, "status" => 1, "Pdcset" => 410, "islcc" => 1, "LossA" => 0.0, "Qacmin" => 0, "rc" => 0.01, "source_id" => Any["convdc_Basslink_TAS_to_VIC", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => Basslink_Tas_bus_number, "tm" => 1, "type_dc" => 1, "Q_g" => 233, "LossB" => 0.0, "basekVac" => 220, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -500, "Qacmax" => 250, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 410, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                      # VIC to TAS 594MW  


# Adding bipolar VIC_to_SA HVDC Murraylink & VSC converters Ref: page - 136, Chapter 7. https://doi.org/10.26190/unsworks/24018

Murraylink_Vic_bus_number = 765               # "name" => "bus_2355"(986)      # TODO bus_2355 is isolated and 165kV instead of 220kV            !Explore bus_2129 (765)
Murraylink_Sa_bus_number = 1800               # "name" => "bus_4185"
Murraylink_Vic_gen_id = 222                   # gen_2355_1 on bus_986 has to be removed and its type has to change from 2 to 1
Murraylink_Sa_xf_id = 2389                    # xf_2355_to_4185_1 has to be removed

#delete!(network["gen"], "$Murraylink_Vic_gen_id")
#delete!(network["branch"], "$Murraylink_Sa_xf_id")
#network["bus"]["$Murraylink_Vic_bus_number"]["bus_type"]  = 1

#network["busdc"]["3"]=Dict{String, Any}()
#network["busdc"]["4"]=Dict{String, Any}()

#network["busdc"]["3"]=Dict("basekVdc" => 150, "source_id" => Any["busdc", 3], "Vdc" => 1, "busdc_i" => 3, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 3, "Pdc" => 0)
#network["busdc"]["4"]=Dict("basekVdc" => 150, "source_id" => Any["busdc", 4], "Vdc" => 1, "busdc_i" => 4, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 4, "Pdc" => 0)

#network["branchdc"]["2"]=Dict{String, Any}()
#network["branchdc"]["2"]=Dict("c" => 0, "r" => 0.0052, "status" => 1, "rateB" => 220, "fbusdc" => 3, "source_id" => Any["branchdc", 3, 4, "Murraylink" ], "rateA" => 220, "l" => 0, "index" => 2, "rateC" => 220, "tbusdc" => 4)    

#network["convdc"]["3"]=Dict{String, Any}()
#network["convdc"]["4"]=Dict{String, Any}()
#network["convdc"]["3"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 220, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 10, "status" => 1, "Pdcset" => -91, "islcc" => 0, "LossA" => 0.0, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc_Murraylink_VIC_to_SA", 3], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 3, "busac_i" => Murraylink_Vic_bus_number, "tm" => 1, "type_dc" => 1, "Q_g" => 0, "LossB" => 0.0, "basekVac" => 220, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -220, "Qacmax" => 100, "index" => 3, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -91, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # VIC to SA 220MW      TODO inverter -100 +100 MVAr rectifier -75 +125                                              
#network["convdc"]["4"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 220, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 10, "status" => 1, "Pdcset" => 91, "islcc" => 0, "LossA" => 0.0, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc_Murraylink_SA_to_VIC", 4], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 4, "busac_i" => Murraylink_Sa_bus_number, "tm" => 1, "type_dc" => 1, "Q_g" => 0, "LossB" => 0.0, "basekVac" => 132, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -220, "Qacmax" => 100, "index" => 4, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 91, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # SA to VIC 200MW      TODO inverter -100 +100 MVAr rectifier -75 +125                                              

# Adding bipolar NSW_to_QL HVDC Directlink that extends 110kV(2) AC Terranora interconnector [branch 277, 278] & VSC converters

Directlink_Ql_bus_number = 211                # "name" => "bus_1218"        # Connecting to NSW through Directlink
Directlink_Nsw_bus_number = 418               # "name" => "bus_1426"        # TODO bus_1426 is nearest 132kV in NSW well connected
Directlink_Nsw_gen_id = 206                   # gen_1218_1 on bus_211 has to be removed and its type has to change from 2 to 1

#delete!(network["gen"], "$Directlink_Nsw_gen_id")
#network["bus"]["$Directlink_Ql_bus_number"]["bus_type"]  = 1

#network["busdc"]["5"]=Dict{String, Any}()
#network["busdc"]["6"]=Dict{String, Any}()

#network["busdc"]["5"]=Dict("basekVdc" => 80, "source_id" => Any["busdc", 5], "Vdc" => 1, "busdc_i" => 5, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 5, "Pdc" => 0)
#network["busdc"]["6"]=Dict("basekVdc" => 80, "source_id" => Any["busdc", 6], "Vdc" => 1, "busdc_i" => 6, "Cdc" => 0, "grid" => 1, "Vdcmax" => 1.1, "Vdcmin" => 0.9, "index" => 6, "Pdc" => 0)

#network["branchdc"]["3"]=Dict{String, Any}()
#network["branchdc"]["4"]=Dict{String, Any}()
#network["branchdc"]["5"]=Dict{String, Any}()
#network["branchdc"]["3"]=Dict("c" => 0, "r" => 0.052, "status" => 1, "rateB" => 60, "fbusdc" => 5, "source_id" => Any["branchdc", 5, 6, "Directlink" ], "rateA" => 60, "l" => 0, "index" => 3, "rateC" => 60, "tbusdc" => 6)    
#network["branchdc"]["4"]=Dict("c" => 0, "r" => 0.052, "status" => 1, "rateB" => 60, "fbusdc" => 5, "source_id" => Any["branchdc", 5, 6, "Directlink" ], "rateA" => 60, "l" => 0, "index" => 4, "rateC" => 60, "tbusdc" => 6)    
#network["branchdc"]["5"]=Dict("c" => 0, "r" => 0.052, "status" => 1, "rateB" => 60, "fbusdc" => 5, "source_id" => Any["branchdc", 5, 6, "Directlink" ], "rateA" => 60, "l" => 0, "index" => 5, "rateC" => 60, "tbusdc" => 6)    

#network["convdc"]["5"]=Dict{String, Any}()
#network["convdc"]["6"]=Dict{String, Any}()
#network["convdc"]["7"]=Dict{String, Any}()
#network["convdc"]["8"]=Dict{String, Any}()
#network["convdc"]["9"]=Dict{String, Any}()
#network["convdc"]["10"]=Dict{String, Any}()
#network["convdc"]["5"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 60, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 3.42, "status" => 1, "Pdcset" => 0.0, "islcc" => 0, "LossA" => 0.0, "Qacmin" => -30, "rc" => 0.01, "source_id" => Any["convdc_Directlink_QL_to_NSW", 5], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 5, "busac_i" => Directlink_Ql_bus_number, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.0, "basekVac" => 110, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -60, "Qacmax" => 30, "index" => 5, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -15, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # QL to NSW 210MW                                              
#network["convdc"]["6"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 60, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 3.42, "status" => 1, "Pdcset" => 0.0, "islcc" => 0, "LossA" => 0.0, "Qacmin" => -30, "rc" => 0.01, "source_id" => Any["convdc_Directlink_QL_to_NSW", 6], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 5, "busac_i" => Directlink_Ql_bus_number, "tm" => 1, "type_dc" => 1, "Q_g" => 0, "LossB" => 0.0, "basekVac" => 110, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -60, "Qacmax" => 30, "index" => 6, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -25, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # QL to NSW 210MW  
#network["convdc"]["7"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 60, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 3.42, "status" => 1, "Pdcset" => 0.0, "islcc" => 0, "LossA" => 0.0, "Qacmin" => -30, "rc" => 0.01, "source_id" => Any["convdc_Directlink_QL_to_NSW", 7], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 5, "busac_i" => Directlink_Ql_bus_number, "tm" => 1, "type_dc" => 1, "Q_g" => 0, "LossB" => 0.0, "basekVac" => 110, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -60, "Qacmax" => 30, "index" => 7, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -25, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # QL to NSW 210MW  

#network["convdc"]["8"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 60, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 3.42, "status" => 1, "Pdcset" => 0.0, "islcc" => 0, "LossA" => 0.0, "Qacmin" => -30, "rc" => 0.01, "source_id" => Any["convdc_Directlink_NSW_to_QL", 8], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 6, "busac_i" => Directlink_Nsw_bus_number, "tm" => 1, "type_dc" => 1, "Q_g" => 0, "LossB" => 0.0, "basekVac" => 132, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -60, "Qacmax" => 30, "index" => 8, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 15, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # NSW to QL 107MW 
#network["convdc"]["9"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 60, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 3.42, "status" => 1, "Pdcset" => 0.0, "islcc" => 0, "LossA" => 0.0, "Qacmin" => -30, "rc" => 0.01, "source_id" => Any["convdc_Directlink_NSW_to_QL", 9], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 6, "busac_i" => Directlink_Nsw_bus_number, "tm" => 1, "type_dc" => 1, "Q_g" => 0, "LossB" => 0.0, "basekVac" => 132, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -60, "Qacmax" => 30, "index" => 9, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 25, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # NSW to QL 107MW 
#network["convdc"]["10"]=Dict("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 60, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 3.42, "status" => 1, "Pdcset" => 0.0, "islcc" => 0, "LossA" => 0.0, "Qacmin" => -30, "rc" => 0.01, "source_id" => Any["convdc_Directlink_NSW_to_QL", 10], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 6, "busac_i" => Directlink_Nsw_bus_number, "tm" => 1, "type_dc" => 1, "Q_g" => 0, "LossB" => 0.0, "basekVac" => 132, "LossCrec" => 0.0, "droop" => 0.005, "Pacmin" => -60, "Qacmax" => 30, "index" => 10, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 25, "transformer" => 1, "bf" => 0.01, "LossCinv" => 0.0)                    # NSW to QL 107MW 

# Adding generator, branch and branchdc contingencies

network["branchdc_contingencies"]=Vector{Any}(undef, 1)
#network["branchdc_contingencies"][1]=(idx = 1, label = "LINE-1-2-R", type = "branchdc")

network["branch_contingencies"]=Vector{Any}(undef, 1)
#network["branch_contingencies"][1]=(idx = 7, label = "LINE-4-5-BL", type = "branch")

network["gen_contingencies"]=Vector{Any}(undef, 1)
#network["gen_contingencies"][1]=(idx = 3, label = "GEN-3-1", type = "gen")

 [gen["model"] = 1 for (i, gen) in network["gen"]]
 [gen["ncost"] = 2 for (i, gen) in network["gen"]]
 [gen["cost"] = [1000, 10, 1, 0] for (i, gen) in network["gen"]]
#for i in network["gen"]
    #network["gen"][i]["model"] = 1
    #network["gen"]["$i"]["pg"] = 0
    #network["gen"]["$i"]["qg"] = 0
    #network["gen"]["$i"]["pmin"] = 0
    #network["gen"]["$i"]["qmin"] = -network["gen"]["$i"]["qmax"]
    #network["gen"][i]["ncost"] = 2
    #network["gen"][i]["cost"] = [1000, 10, 1, 0]     #[0.114610934721, 148.906997825, 0.224657803731, 203.163028589, 0.33470467274, 257.869865285, 0.44475154175, 313.027507911, 0.5547984107589999, 368.635956469, 0.664845279769, 424.695210957, 0.774892148778, 481.205271377, 0.884939017788, 538.166137728, 0.9949858867970001, 595.57781001, 1.10503275581, 653.440288223]
    #network["gen"]["$i"]["alpha"] = 1
#end

network["bus"]["2136"]["bus_type"] = 2

PowerModelsACDC.process_additional_data!(network)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
resultsACDC = PowerModelsACDC.run_acdcopf(network, PowerModels.ACPPowerModel, nlp_solver; setting = setting)

#resultACDCSCOPF2=PowerModelsACDCsecurityconstrained.run_ACDC_scopf_contigency_cuts(network, PowerModels.ACPPowerModel, PowerModelsACDCsecurityconstrained.run_scopf, nlp_solver, setting)




