
### Script for AC-DC SCOPF implementation on SNEM2000acdc using flow cuts
using Ipopt
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained
using InfrastructureModels
using Memento
using IterativeSolvers
using Distributed

# Distributed.clear!

max_node_processes = 32

node_processes = min(Sys.CPU_THREADS - 2, max_node_processes)

if Distributed.nprocs() >= 2
    return
end
Distributed.addprocs(node_processes, topology=:master_worker)

@everywhere begin

    using Ipopt
    using JuMP
    using PowerModels
    using PowerModelsACDC
    using PowerModelsSecurityConstrained
    using PowerModelsACDCsecurityconstrained
    using InfrastructureModels
    using Memento
    using IterativeSolvers

    nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)    

    const _PM = PowerModels
    const _PMSC = PowerModelsSecurityConstrained
    const _PMACDC = PowerModelsACDC
    const _PMSCACDC = PowerModelsACDCsecurityconstrained
    const _DI = Distributed
    const _IM = InfrastructureModels
    const _LOGGER = Memento.getlogger(@__MODULE__)
    const _IS = IterativeSolvers

    ## Include some helper functions
    include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/core/ndc_filter.jl")
    include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/core/CalVio.jl")
    include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/core/conting_c.jl")
    _PMSCACDC.silence()

end



## 
# file = "./data/snem2000_acdc_mesh.m"
# file = "./data/snem2000_acdc.m"
# data = parse_file(file)
# _PMSCACDC.fix_scopf_data_issues!(data)
# modifying peak minimum load
# for (i, load) in data["load"]
#     load["pd"] = 0.85*load["pd"]
#     load["qd"] = 0.85*load["qd"]
# end
# Adding REZs
# gen_id = [gen["index"] for (i,gen) in data["gen"] if gen["pmax"] == 0]
# for i in gen_id
#     data["gen"]["$i"]["pmax"] = 0.6
# end

##
# file = "./data/case5_acdc_scopf.m"
# data = _PM.parse_file(file)
# _PMSCACDC.fix_scopf_data_case5_acdc!(data)

# data["branch"]["1"]["rate_a"] = data["branch"]["1"]["rate_b"] = data["branch"]["1"]["rate_c"] = 0.3;
# data["branch"]["2"]["rate_a"] = data["branch"]["2"]["rate_b"] = data["branch"]["2"]["rate_c"] = 0.35;
# data["branch"]["5"]["rate_a"] = data["branch"]["5"]["rate_b"] = data["branch"]["5"]["rate_c"] = 0.3;

# data["branchdc"]["1"]["rateA"] = data["branchdc"]["1"]["rateB"] = data["branchdc"]["1"]["rateC"] = 50;
# data["branchdc"]["2"]["rateA"] = data["branchdc"]["2"]["rateB"] = data["branchdc"]["2"]["rateC"] = 50;
# data["branchdc"]["3"]["rateA"] = data["branchdc"]["3"]["rateB"] = data["branchdc"]["3"]["rateC"] = 50;


##
# file = "./data/case24_3zones_acdc_sc.m"
# data = _PM.parse_file(file)
# _PMSCACDC.fix_scopf_data_case24_3zones_acdc!(data)

#
file = "./data/case67_acdc_scopf.m"
data = _PM.parse_file(file)
_PMSCACDC.fix_scopf_data_case67_acdc!(data)

##
# c1_ini_file = "./data/c1/inputfiles.ini"
# c1_scenarios = "scenario_02"
# c1_cases = parse_c1_case(c1_ini_file,scenario_id=c1_scenarios)
# data = build_c1_pm_model(c1_cases)
# _PMSCACDC.fix_scopf_data_case500_acdc!(data)

##
data["convdc_contingencies"] = []
_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

# data["branchdc"]["3"]["status"] = 1
# solution = _PMACDC.run_acdcpf(data, _PM.DCPPowerModel, nlp_solver; setting = setting)["solution"]


######## trial distributed contingencies evaluation

    network = deepcopy(data) 
    
    result_base = _PMACDC.run_acdcopf(network, _PM.ACPPowerModel, nlp_solver)
    if !(result_base["termination_status"] == _PM.OPTIMAL || result_base["termination_status"] == _PM.LOCALLY_SOLVED || result_base["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        Memento.error(_LOGGER, "base-case ACDCOPF solve failed in run_c1_scopf_ptdf_cuts, status $(result_base["termination_status"])")
    end
    Memento.info(_LOGGER, "objective: $(result_base["objective"])")

    _PM.update_data!(network, result_base["solution"])
    for (i,conv) in network["convdc"]
        conv["P_g"] = -result_base["solution"]["convdc"][i]["pgrid"]
        conv["Q_g"] = -result_base["solution"]["convdc"][i]["qgrid"]
    end
    
    # for (i, branch) in network["branch"]
    #     if haskey(result["solution"]["branch"], i)
    #         branch["tap"] = result["solution"]["branch"][i]["tm"]
    #         branch["shift"] = result["solution"]["branch"][i]["ta"]
    #     end
    # end

    # add loss distribution factors and total loss
    network["ploss"] = sum(abs(branch["pf"] + branch["pt"]) for (b,branch) in network["branch"] if branch["br_status"] !=0)
    load_total = sum(load["pd"] for (i,load) in network["load"] if load["status"] != 0)
    network["ploss_df"] = Dict(bus["index"] => 0.0 for (i,bus) in network["bus"])
    for (i, load) in network["load"]
        network["ploss_df"][load["load_bus"]] = load["pd"]/load_total
    end

    ######## Contingency Evaluation ########
     
    # time_worker_start = time()
    workers = _DI.workers()
    # Memento.info(_LOGGER, "start warmup on $(length(workers)) workers")
    worker_futures = []
    for wid in workers
        future = _DI.remotecall(load_network_global_new, wid, network)
        push!(worker_futures, future)
    end
    # setup for contigency solve
    gen_cont_total = length(network["gen_contingencies"])
    branch_cont_total = length(network["branch_contingencies"])
    branchdc_cont_total = length(network["branchdc_contingencies"])
    convdc_cont_total = length(network["convdc_contingencies"])
    cont_total = gen_cont_total + branch_cont_total + branchdc_cont_total + convdc_cont_total
    cont_per_proc = cont_total/length(workers)

    cont_order = contingency_order(network)

    cont_range = []
    for p in 1:length(workers)
        cont_start = trunc(Int, ceil(1+(p-1)*cont_per_proc))
        cont_end = min(cont_total, trunc(Int,ceil(p*cont_per_proc)))
        push!(cont_range, cont_start:cont_end,)
    end

    # for (i,rng) in enumerate(cont_range)
    #     # Memento.info(_LOGGER, "task $(i): $(length(rng)) / $(rng)")
    # end
    
    # Memento.info(_LOGGER, "waiting for worker warmup to complete: $(time())")
    for future in worker_futures
        wait(future)
    end 

    # time_worker = time() - time_worker_start
    # Memento.info(_LOGGER, "total worker warmup time: $(time_worker)")
    
    # result_scopf = Dict{String,Any}()
    iteration  = 1
    # while true
    #     time_start_iteration = time()

        t_conts = @elapsed @time conts = _DI.pmap(check_contingency_violations_distributed_remote, cont_range, [iteration for p in 1:length(workers)])
        # Memento.info(_LOGGER, "total contingencies found: $(length(conts))")

        # function to merge distributed contingency evaluation results
        t_conts_org = @elapsed gen_cuts, branch_cuts, branchdc_cuts, convdc_cuts, active_conts_by_branch, active_conts_by_branchdc = _PMSCACDC.organize_distributed_conts(conts)

        # filtering dominated contingencies
        t_conts_ndc = @elapsed conts_ndc =  _PMSCACDC.filtering_dominated_contingencies(gen_cuts, branch_cuts, branchdc_cuts, convdc_cuts, active_conts_by_branch, active_conts_by_branchdc)

        # check
        # if network["gen_contingencies"] == conts_ndc.gen_contingencies && network["branch_contingencies"] == conts_ndc.branch_contingencies && network["branchdc_contingencies"] == conts_ndc.branchdc_contingencies && network["convdc_contingencies"] == conts_ndc.convdc_contingencies
        #     time_iteration = time() - time_start_iteration
        #     Memento.info(_LOGGER, "iteration time: $(time_iteration)")
        #     break
        # end

        # update the contingency sets in network data set
        network["gen_contingencies"] = conts_ndc.gen_contingencies
        network["branch_contingencies"] = conts_ndc.branch_contingencies
        network["branchdc_contingencies"] = conts_ndc.branchdc_contingencies
        network["convdc_contingencies"] = conts_ndc.convdc_contingencies
        network["branchdc_contingencies"] = data["branchdc_contingencies"]
        network["gen_contingencies"] = []
        network["branch_contingencies"] = []

        # Solving ac-dc scopf heuristic with ptdf and dcdf cuts
        t_scopf = @elapsed @time result_scopf = _PMSCACDC.run_acdc_scopf_ptdf_dcdf_cuts_iterative(network, _PM.ACPPowerModel, _PMSCACDC.run_acdc_scopf_cuts_soft, nlp_solver)
        # using ProfileSVG # ProfileSVG.@profile # ProfileSVG.save(joinpath("plots", "prof.svg"))

       
        t_scopf = @elapsed @time result_scopf = _PMSCACDC.run_ACDC_scopf_contigency_cuts(network, _PM.ACPPowerModel, _PMSCACDC.run_scopf_soft, _PMSCACDC.check_contingency_violations_SI, nlp_solver, setting) 


        # Save the results
        using HDF5, JLD
        case = Dict{String, Any}()
        case["rbase"] = result_base
        case["t_conts"] = t_conts
        case["ndc_mem"] = (5.782, "MiB")
        case["g_conts"] = network["gen_contingencies"]
        case["b_conts"] = network["branch_contingencies"]
        case["bdc_conts"] = network["branchdc_contingencies"]
        case["c_conts"] = network["convdc_contingencies"]
        case["rfinal"] = result_scopf
        case["t_scopf"] = t_scopf
        case["scopf_mem"] = (289.745, "MiB")

        save("./results/case500_ptdf_wf.jld", "data", case)

        # load("./results/case5_ptdf.jld")["data"]

        # if result_scopf["final"]["iterations"] < 2
        #     time_iteration = time() - time_start_iteration
        #     Memento.info(_LOGGER, "iteration time: $(time_iteration)")
        #     break
        # end
        
        # update results
        # _PM.update_data!(network, result_scopf["final"]["solution"])
        # for (i,conv) in network["convdc"]
        #     conv["P_g"] = -result_scopf["final"]["solution"]["convdc"][i]["pgrid"]
        #     conv["Q_g"] = -result_scopf["final"]["solution"]["convdc"][i]["qgrid"]
        # end

        # iteration += 1
    # end





# @time conts = __PMSCACDC.check_contingencies_distributed(data)

filter_ndc_time=@elapsed ndc_contingencies= _PMSCACDC.filter_dominated_contingencies(data, _PM.ACPPowerModel, nlp_solver, setting)

# data["branch"]["10"]["br_status"] = 1
# resultopf = __PMACDC.run_acdcopf(data, _PM.ACPPowerModel, nlp_solver, setting = setting) 

# data["branchdc"]["1"]["status"] = 1

# data["convdc"]["1"]["P_g"] = -resultopf["solution"]["convdc"]["1"]["pgrid"]
# data["convdc"]["1"]["Q_g"] = resultopf["solution"]["convdc"]["1"]["qgrid"]
# data["convdc"]["2"]["P_g"] = -resultopf["solution"]["convdc"]["2"]["pgrid"]
# data["convdc"]["2"]["Q_g"] = resultopf["solution"]["convdc"]["2"]["qgrid"]

# data["convdc"]["1"]["status"] = 0
# data["convdc"]["2"]["status"] = 0
# data["branchdc"]["1"]["status"] = 0


# update_data!(data, resultopf["solution"])
# resultpf = __PMACDC.run_acdcpf(data, _PM.ACPPowerModel, nlp_solver, setting = setting) 
# result = __PMSCACDC.run_ACDC_scopf_contigency_cuts(data, _PM.ACPPowerModel, __PMSCACDC.run_scopf_soft, __PMSCACDC.check_contingency_violations_SI, nlp_solver, setting)

scopf_solve_time=@elapsed results = __PMSCACDC.run_acdc_scopf_ptdf_dcdf_cuts(data, _PM.ACPPowerModel, __PMSCACDC.run_acdc_scopf_cuts, nlp_solver)

##
plotdata = deepcopy(data)
_PM.update_data!(plotdata, results["final"]["solution"])
plotdata["dcline"] = Dict{String, Any}()
plotdata["dcline"] = plotdata["branchdc"]

plotdata["dcline"]["1"]["f_bus"] = 1005  
plotdata["dcline"]["1"]["t_bus"] = 1508

plotdata["dcline"]["2"]["f_bus"] = 877  
plotdata["dcline"]["2"]["t_bus"] = 182

plotdata["dcline"]["3"]["f_bus"] = 877  
plotdata["dcline"]["3"]["t_bus"] = 182

plotdata["dcline"]["4"]["f_bus"] = 877  
plotdata["dcline"]["4"]["t_bus"] = 182

plotdata["dcline"]["5"]["f_bus"] = 1920  
plotdata["dcline"]["5"]["t_bus"] = 316


plot_nem = powerplot(plotdata; gen_color = "red", bus_color="black", branch_color="blue", dcline_color = "green", bus_size=10, gen_size=50, branch_size=1, load_size = 0, dcline_size = 3, show_flow=false, connector_size=1, width=2000, height=2000)
PowerPlots.Experimental.add_zoom!(plot_nem)
save("plot_nem2.html", plot_nem)

a = [br["pf"]/data["branch"][i]["rate_a"] for (i, br) in results["final"]["solution"]["branch"] if abs(br["pf"]/data["branch"][i]["rate_a"]) > 1 ]
a = [br["pf"]/data["branch"][i]["rate_a"] for (i, br) in results["final"]["solution"]["branch"] ]

using Plots
plot(a)


# Checking the feasible contingencies
function calc_feasible_contingencies(data, nlp_solver, setting)
    feasible_contingencies = []
    infeasible_contingencies = []
    for i = 1:length(data["branch"])
        if  data["branch"]["$i"]["br_status"] != 0 && i != 140 && i!= 712 && i!= 1313 && i!= 2687
            data["branch"]["$i"]["br_status"] = 0
            result_acdcpf = __PMACDC.run_acdcpf(data, _PM.ACPPowerModel, nlp_solver, setting = setting)

            if (result_acdcpf["termination_status"] == _PM.OPTIMAL || result_acdcpf["termination_status"] == _PM.LOCALLY_SOLVED || result_acdcpf["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
                push!(feasible_contingencies, data["branch"]["$i"]["index"])
            else    
                push!(infeasible_contingencies, data["branch"]["$i"]["index"])
            end
            data["branch"]["$i"]["br_status"] = 1
            result_acdcpf = nothing
            if i == 500
                printstyled("Note that ................ i == ........##......... 500\n"; color = :red)
            elseif i == 1000
                printstyled("Note that ................ i == ........##......... 1000\n"; color = :red)
            elseif i == 1500
                printstyled("Note that ................ i == ........##......... 1500\n"; color = :red)
            elseif i == 2000
                printstyled("Note that ................ i == ........##......... 2000\n"; color = :red)
            elseif i == 2500
                printstyled("Note that ................ i == ........##......... 2500\n"; color = :red)
            elseif i == 3000
                printstyled("Note that ................ i == ........##......... 3000\n"; color = :red)
            end
        end
    end
    return feasible_contingencies, infeasible_contingencies
end


    feasible_contingencies, infeasible_contingencies = calc_feasible_contingencies(data, nlp_solver, setting)


#change to contingencies
contingencies = [] 
for (i, branch) in data["branch"]
    if branch["index"] in feasible_contingencies
        push!(contingencies, (idx = branch["index"], label = branch["name"], type = "branch"))
    end
end
for i=1:1000
    println("data[\"branch_contingencies\"][$i] = $(contingencies[i])")
end

### checkscopf
i = 1644
        # if data["branch"]["$i"]["br_status"] != 0
            data["branch"]["2687"]["br_status"] = 0
            data["branch"]["1645"]["br_status"] = 1
            result_acdcpf = __PMACDC.run_acdcpf(data, _PM.ACPPowerModel, nlp_solver, setting = setting)
        # end

        for (i, branch) in data["branch"]
            if branch["f_bus"] == 367 && branch["t_bus"] == 508
                println("$(branch["index"])")
            end
        end
        
### check parallel branch
parallel_branch = []
for (idx, label, type) in data["branch_contingencies"]
    for (i, branch) in data["branch"]
        if branch["f_bus"] == data["branch"]["$idx"]["f_bus"] && branch["t_bus"] == data["branch"]["$idx"]["t_bus"] && "$idx" != i
            println("Parallel branch .............................. $idx and $i")
            push!(parallel_branch, parse(Int64, i))
        end
    end
end

#  generating a new set avoiding parallel lines
contingencies_new = []
for (idx, label, type) in data["branch_contingencies"]
    if idx ∉ parallel_branch && idx ∉ rm_branch_conts
        push!(contingencies_new, (idx = idx, label = "$label", type = "$type"))
    end
end
for i=1001:1295
    println("data[\"branch_contingencies\"][$i] = $(contingencies_new[i])")
end
i=1
for (idx, label, type) in data["branch_contingencies"]
    println("data[\"branch_contingencies\"][$i] = (idx = $idx, label = \"$label\", type = \"$type\")")
    i+=1
end

# setting up generator contingencies
i = 1
for (j, gen) in data["gen"]
    if gen["fuel"] != "CapBank/SVC/StatCom/SynCon" && gen["pmax"] < 5.0 && gen["index"] <= 265
        println("data[\"gen_contingencies\"][$i] = (idx = $(gen["index"]), label = \"$(gen["name"])__$(gen["pmax"])MW\", type = \"gen\")")
        i +=1
    end
end

parallel_gen = []
for (idx, label, type) in data["gen_contingencies"]
    for (i, bus) in data["bus"]
        if bus["index"] == data["gen"]["$idx"]["index"] && "$idx" != i
            push!(parallel_gen, parse(Int64, i))
        end
    end
end

gen_power = 0.0
j = 1
for (i,gen) in results["final"]["solution"]["gen"]
    if gen["pg"] != 0
        gen_power += gen["pg"]
        println("gen index = $i, $(data["gen"]["$i"]["fuel"]), $(data["gen"]["$i"]["pmax"]) ................ pg = $(gen["pg"])")
        j +=1
    else
        println("gen index = $i, ................ pg = $(gen["pg"])")
    end
end

load_total = 0.0
for (i, load) in data["load"]
    load_total += load["pd"]
end

for (i,gen) in data["gen"]
   if gen["fuel"] == "Coal" && gen["pmax"] > 5
        println("gen $i ................................ $(gen["pmax"])")
   end
end

for (i, gen) in data["gen"]
    if gen["fuel"] == "CapBank/SVC/StatCom/SynCon"
       println("$i ........... $(gen["fuel"])")
    end 
end
   
for (i, gen) in data["gen"]
    println("$(gen["gen_bus"])")
end

for (i, branch) in data["branch"]
    fbus = branch["f_bus"]
    tbus = branch["t_bus"]
    if data["bus"]["$fbus"]["base_kv"] < 66 && data["bus"]["$tbus"]["base_kv"] < 66
        println("branch $i ............. $fbus ... ($(data["bus"]["$fbus"]["base_kv"])) ............ $tbus ... ($(data["bus"]["$tbus"]["base_kv"]))")
    end
end

####
branch_cont_idx = []
for (idx, label, type) in data["branch_contingencies"]
    push!(branch_cont_idx, idx)
end
gen_bus = []
for (i, gen) in data["gen"]
    push!(gen_bus, gen["gen_bus"])
end
gen_cont_idx = []
for (idx, label, type) in data["gen_contingencies"]
    push!(gen_cont_idx, idx)
end
gen_cont_buses = []
for (i, gen) in data["gen"]
    if gen["index"] in gen_cont_idx
        push!(gen_cont_buses, gen["gen_bus"])
    end
end
branch_bus = []
for (i, branch) in data["branch"]
    push!(branch_bus, branch["f_bus"])
    push!(branch_bus, branch["t_bus"])
end
rm_branch_conts = [] 
for (i, branch) in data["branch"]
    if branch["index"] in branch_cont_idx
        if branch["f_bus"] in gen_bus 
            if branch["f_bus"] in gen_cont_buses 
                if count(==(branch["f_bus"]), branch_bus) == 1
                    push!(rm_branch_conts, branch["index"])
                end
            end
        end
        if branch["t_bus"] in gen_bus
            if branch["t_bus"] in gen_cont_buses
                if count(==(branch["t_bus"]), branch_bus) == 1
                    push!(rm_branch_conts, branch["index"])
                end
            end
        end
    end
end





function calc_feasible_contingencies(data, nlp_solver, setting)
    network = deepcopy(data)
    feasible_contingencies = []
    infeasible_contingencies = []
    for (idx, label, type) in network["branch_contingencies"]
            if  network["branch"]["$idx"]["br_status"] != 0 
                network["branch"]["$idx"]["br_status"] = 0
                println("contingency ...... $idx ...... embedded")
                # result_acdcpf = _SACDCPF.compute_sacdc_pf(network)
                try
                    result_acdcpf = _PMACDC.run_acdcpf(network, _PM.DCPPowerModel, nlp_solver, setting=setting)
                    if (result_acdcpf["termination_status"] == _PM.OPTIMAL || result_acdcpf["termination_status"] == _PM.LOCALLY_SOLVED || result_acdcpf["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
                        push!(feasible_contingencies1, (idx, label, type))
                    else
                        push!(infeasible_contingencies, (idx, label, type))
                    end
                catch exception
                    continue
                    push!(infeasible_contingencies, (idx, label, type)) 
                end
                network["branch"]["$idx"]["br_status"] = 1
                result_acdcpf = nothing
            end
    end
    return feasible_contingencies, infeasible_contingencies
end

feasible_contingencies_dc, infeasible_contingencies_dc = calc_feasible_contingencies(data, nlp_solver, setting)

for i=1001:1295
    println("data[\"branch_contingencies\"][$i] = $(contingencies_new[i])")
end
i=1
for (idx, label, type) in data["branch_contingencies"]
    if idx != 1091 && idx != 3081
        println("data[\"branch_contingencies\"][$i] = (idx = $idx, label = \"$label\", type = \"$type\")")
        i+=1
        # if i == 1000
        #     break
        # end
    end
end





function calc_feasible_contingencies(data)
    network = deepcopy(data)
    feasible_contingencies = []
    infeasible_contingencies = []
    for (i, branch) in network["branch"]
        if  branch["br_status"] != 0
            branch["br_status"] = 0
            try
                result_acdcpf = _SACDCPF.compute_sacdc_pf(network)
                push!(feasible_contingencies, (idx = branch["index"], label = branch["name"], type = "branch"))
                catch exception
                    # _PMSCACDC.warn(_LOGGER, "SACDCPF solve failed on branch $(branch["index"]) contingency")
                    push!(infeasible_contingencies, (idx = branch["index"], label = branch["name"], type = "branch"))
                continue
            end
        end
        branch["br_status"] = 1
    end
    return feasible_contingencies, infeasible_contingencies
end

feasible_contingencies, infeasible_contingencies = calc_feasible_contingencies(data)
#change to contingencies
contingencies = [] 
for (i, branch) in data["branch"]
    if branch["index"] in feasible_contingencies
        push!(contingencies, (idx = branch["index"], label = branch["name"], type = "branch"))
    end
end
for i=1:1000
    println("data[\"branch_contingencies\"][$i] = $(contingencies[i])")
end