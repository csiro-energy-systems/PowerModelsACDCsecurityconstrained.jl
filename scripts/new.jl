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
#lp_solver = optimizer_with_attributes(Cbc.Optimizer)

c1_ini_file = "./data/c1/inputfiles.ini"
c1_scenarios = "scenario_01"  #, "scenario_02"]
c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
network = build_c1_pm_model(c1_cases)

network["branch_contingencies"]=Vector{Any}(undef, 1)
#network["branch_contingencies"][1]=(idx = 1, label = "LINE-1-2-BL", type = "branch")
#network["branch_contingencies"][6]=(idx = 7, label = "LINE-4-5-BL", type = "branch")
#network["branch_contingencies"][8]=(idx = 9, label = "LINE-6-12-BL", type = "branch")
#network["branch_contingencies"][9]=(idx = 10, label = "LINE-6-13-BL", type = "branch")
#network["branch_contingencies"][5]=(idx = 6, label = "LINE-3-4-BL", type = "branch")
#network["branch_contingencies"][5]=(idx = 1, label = "LINE-1-2-BL", type = "branch")
#network["branch_contingencies"][1]=(idx = 2, label = "LINE-1-5-BL", type = "branch")
network["branch_contingencies"][1]=(idx = 3, label = "LINE-2-3-BL", type = "branch")
#network["branch_contingencies"][3]=(idx = 4, label = "LINE-2-4-BL", type = "branch")
#network["branch_contingencies"][4]=(idx = 5, label = "LINE-2-5-BL", type = "branch")
#network["branch_contingencies"][7]=(idx = 8, label = "LINE-6-11-BL", type = "branch")
#network["branch_contingencies"][10]=(idx = 11, label = "LINE-7-8-BL", type = "branch")
network["gen_contingencies"]=Vector{Any}(undef, 2)
network["gen_contingencies"][1]=(idx = 3, label = "GEN-3-1", type = "gen")
network["gen_contingencies"][2]=(idx = 1, label = "GEN-1-1", type = "gen")
#network["gen_contingencies"][3]=(idx = 2, label = "GEN-2-1", type = "gen")
#network["gen_contingencies"][4]=(idx = 4, label = "GEN-2-1", type = "gen")
#network["gen_contingencies"][4]=(idx = 4, label = "GEN-6-1", type = "gen")
network["gen"]["4"]["gen_status"]=0
network["gen"]["5"]["gen_status"]=0
network["gen"]["6"]["gen_status"]=0
#network["gen"]["3"]["gen_status"]=0
#scopf_dc_cuts_soft_woc_objective = [14642.16, 26982.17]
network["branch"]["5"]["rate_c"]=network["branch"]["5"]["rate_c"]/2
network["branch"]["6"]["rate_c"]=network["branch"]["6"]["rate_c"]/2
network["branch"]["7"]["rate_c"]=network["branch"]["7"]["rate_c"]/2
network["branch"]["8"]["rate_c"]=network["branch"]["8"]["rate_c"]/2

network["branch"]["3"]["br_status"]=0

    network = deepcopy(network)

    #network["gen_flow_cuts"] = []
    #network["branch_flow_cuts"] = []

    resultdcpf = PowerModels.run_dc_pf(network, lp_solver)
    flows = PowerModels.calc_branch_flow_dc(network)

    
    result = PowerModelsSecurityConstrained.run_c1_opf_cheap(network, DCPPowerModel, lp_solver)
    PowerModelsSecurityConstrained.update_active_power_data!(network, result["solution"])
    cuts = PowerModelsSecurityConstrained.check_c1_contingencies_branch_power(network, total_cut_limit=15, gen_flow_cuts=[], branch_flow_cuts=[])
    #cuts = PowerModelsSecurityConstrained.check_c1_contingencies_branch_power(network, total_cut_limit=15, gen_flow_cuts=[], branch_flow_cuts=[])    # Filtering 
    println(length(cuts.gen_cuts) + length(cuts.branch_cuts))
    network["gen_flow_cuts"] = cuts.gen_cuts
    network["branch_flow_cuts"] = cuts.branch_cuts
    #cuts.branch_cuts[1][4]
    result1 = PowerModelsSecurityConstrained.run_c1_scopf_cuts_soft(network, DCPPowerModel, lp_solver)  #_GM




#@testset "scopf cuts dc soft, infeasible" begin
#    network = deepcopy(c1_network_infeasible)
#    network["gen_flow_cuts"] = []
#    network["branch_flow_cuts"] = []

#    result = run_c1_scopf_cuts_soft(network, DCPPowerModel, lp_solver)
#    @test result["termination_status"] == INFEASIBLE || result["termination_status"] == INFEASIBLE_OR_UNBOUNDED
#end

#scopf_dc_cuts_soft_wc_objective = [14642.16, 37403.76]
#@testset "scopf cuts dc soft, with cuts - $(i)" for (i,network) in enumerate(c1_networks)
#    network = deepcopy(network)

#    result = run_c1_opf_cheap(network, DCPPowerModel, lp_solver)
#    @test isapprox(result["termination_status"], OPTIMAL)

#    update_active_power_data!(network, result["solution"])

#    cuts = check_c1_contingencies_branch_power(network, total_cut_limit=2, gen_flow_cuts=[], branch_flow_cuts=[])

    ##println(length(cuts.gen_cuts) + length(cuts.branch_cuts))
    ##cuts_found = sum(length(c.gen_cuts)+length(c.branch_cuts) for c in cuts)
#    network["gen_flow_cuts"] = cuts.gen_cuts
#    network["branch_flow_cuts"] = cuts.branch_cuts

#    result = run_c1_scopf_cuts_soft(network, DCPPowerModel, lp_solver)

#    @test isapprox(result["termination_status"], OPTIMAL)
#    @test isapprox(result["objective"], scopf_dc_cuts_soft_wc_objective[i]; atol = 1e0)
#end

#scopf_ac_cuts_soft_wc_objective = [14676.95, 37904.03]
#@testset "scopf cuts ac soft, with cuts - $(i)" for (i,network) in enumerate(c1_networks)
#    network = deepcopy(network)

#    result = run_c1_opf_cheap(network, ACPPowerModel, nlp_solver)
#    @test isapprox(result["termination_status"], LOCALLY_SOLVED)

#    update_active_power_data!(network, result["solution"])

#    cuts = check_c1_contingencies_branch_power(network, total_cut_limit=2, gen_flow_cuts=[], branch_flow_cuts=[])

    ##println(length(cuts.gen_cuts) + length(cuts.branch_cuts))
    ##cuts_found = sum(length(c.gen_cuts)+length(c.branch_cuts) for c in cuts)
#    network["gen_flow_cuts"] = cuts.gen_cuts
#    network["branch_flow_cuts"] = cuts.branch_cuts

#    result = run_c1_scopf_cuts_soft(network, ACPPowerModel, nlp_solver)

#    @test isapprox(result["termination_status"], LOCALLY_SOLVED)
#    @test isapprox(result["objective"], scopf_ac_cuts_soft_wc_objective[i]; atol = 1e0)
#end


#scopf_dc_cuts_soft_woc_objective = [14642.16, 26982.17]
#@testset "scopf cuts dc soft bpv, without cuts - $(i)" for (i,network) in enumerate(c1_networks)
#    network = deepcopy(network)
#    network["gen_flow_cuts"] = []
#    network["branch_flow_cuts"] = []

#    result = run_c1_scopf_cuts_soft_bpv(network, DCPPowerModel, lp_solver)

#    @test isapprox(result["termination_status"], OPTIMAL)
#    @test isapprox(result["objective"], scopf_dc_cuts_soft_woc_objective[i]; atol = 1e0)
#end

#@testset "scopf cuts dc soft bpv, infeasible" begin
#    network = deepcopy(c1_network_infeasible)
#    network["gen_flow_cuts"] = []
#    network["branch_flow_cuts"] = []

#    result = run_c1_scopf_cuts_soft_bpv(network, DCPPowerModel, lp_solver)
#    @test result["termination_status"] == INFEASIBLE || result["termination_status"] == INFEASIBLE_OR_UNBOUNDED
#end
