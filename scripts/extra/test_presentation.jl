# using Pkg
#Pkg.activate("./scripts")



    using Ipopt
    using Cbc
    using JuMP
    using PowerModels
    using PowerModelsACDC
    using PowerModelsSecurityConstrained
    using PowerModelsACDCsecurityconstrained
    using InfrastructureModels
    using Memento
    

    # using PowerPlots
    # using VegaLite



    nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)  
    lp_solver = optimizer_with_attributes(Cbc.Optimizer)


    const _PM = PowerModels
    const _PMSC = PowerModelsSecurityConstrained
    const _PMACDC = PowerModelsACDC
    const __PMSCACDC = PowerModelsACDCsecurityconstrained
    const _IM = InfrastructureModels
    const _LOGGER = Memento.getlogger(@__MODULE__)

    ## Include some helper functions
    include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/scripts/extra/SNEM2000.jl")
    



## 
""" Read the bus data from UNSW-NEMData """
# file = "./data/nem_2300bus_thermal_limits_gen_costs_hvdc.m"
file = "./data/nem_2300bus_thermal_limits_gen_costs_hvdc.m"
data = _PM.parse_file(file)


##
# This to empty the existing contingencies in the data

data["dcline"] = Dict{String, Any}()
# data["branchdc_contingencies"] = []
data["branchdc_contingencies"] = Vector{Any}(undef, 1)
data["branchdc_contingencies"][1] = (idx = 1, label = "line_1005_to_1508_1_dc_BASSLINK", type = "branchdc")

data["convdc_contingencies"] = []

# data["branch_contingencies"] = [(idx = branch["index"], label = branch["name"], type = "branch") for (i, branch) in data["branch"]]

# data["branch_contingencies"] = []

add_branch_contingencies!(data)


data["branch_infeasible_contingencies"] = []
data["branch_contingencies_unsolvable"] = []

# data["branch_contingencies"] = data["branch_contingencies"][1:50]


# data["gen_contingencies"] = []

add_gen_contingencies!(data)

# data["gen_contingencies"] = data["gen_contingencies"][1:50]


# data["gen_contingencies"]=Vector{Any}(undef, 1)
# data["gen_contingencies"][1]=(idx = 10, label = "gen_1019_3", type = "gen")
# data["gen_contingencies"][2]=(idx = 15, label = "gen_1034_1", type = "gen")
# data["gen_contingencies"][3]=(idx = 25, label = "gen_1058_1", type = "gen")

set1 = Set{Int64}()
set2 = Set{Int64}()
set3 = Set{Int64}()
set4 = Set{Int64}()
set5 = Set{Int64}()

for i = 1:length(data["gen"])
    gen_bus = data["gen"]["$i"]["gen_bus"]
    if data["bus"]["$gen_bus"]["area"] == 1
        push!(set1, data["gen"]["$i"]["index"])
    elseif data["bus"]["$gen_bus"]["area"] == 2
        push!(set2, data["gen"]["$i"]["index"])
    elseif data["bus"]["$gen_bus"]["area"] == 3
        push!(set3, data["gen"]["$i"]["index"])
    elseif data["bus"]["$gen_bus"]["area"] == 4
        push!(set4, data["gen"]["$i"]["index"])
    elseif data["bus"]["$gen_bus"]["area"] == 5
        push!(set5, data["gen"]["$i"]["index"])
    end
end

data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = set1
data["area_gens"][2] = set2
data["area_gens"][3] = set3
data["area_gens"][4] = set4
data["area_gens"][5] = set5

gen_total1 = sum(data["gen"]["$i"]["pmax"] for i in collect(set1))
gen_total2 = sum(data["gen"]["$i"]["pmax"] for i in collect(set2))
gen_total3 = sum(data["gen"]["$i"]["pmax"] for i in collect(set3))
gen_total4 = sum(data["gen"]["$i"]["pmax"] for i in collect(set4))
gen_total5 = sum(data["gen"]["$i"]["pmax"] for i in collect(set5))

for i in collect(set1)
    data["gen"]["$i"]["alpha"] = gen_total1/data["gen"]["$i"]["pmax"]  
end

for i in collect(set2)
    data["gen"]["$i"]["alpha"] = gen_total2/data["gen"]["$i"]["pmax"]  
end

for i in collect(set3)
    data["gen"]["$i"]["alpha"] = gen_total3/data["gen"]["$i"]["pmax"]  
end

for i in collect(set4)
    data["gen"]["$i"]["alpha"] = gen_total4/data["gen"]["$i"]["pmax"]  
end

for i in collect(set5)
    data["gen"]["$i"]["alpha"] = gen_total5/data["gen"]["$i"]["pmax"]  
end

data["contingencies"] = [] 

for i=1:length(data["branch"])
    data["branch"]["$i"]["rate_a"] = 1.3 * data["branch"]["$i"]["rate_a"]
    data["branch"]["$i"]["rate_b"] = 1.3 * data["branch"]["$i"]["rate_b"]
    data["branch"]["$i"]["rate_c"] = 1.3 * data["branch"]["$i"]["rate_c"]
    if data["branch"]["$i"]["tap"] !== 1 
        data["branch"]["$i"]["tm_min"] = 0.9
        data["branch"]["$i"]["tm_max"] = 1.1
    end
    if data["branch"]["$i"]["tap"] == 1 
        data["branch"]["$i"]["tm_min"] = 1
        data["branch"]["$i"]["tm_max"] = 1
    end
    if data["branch"]["$i"]["shift"] !== 0
        data["branch"]["$i"]["ta_min"] = -15
        data["branch"]["$i"]["ta_max"] = 15
    end
    if data["branch"]["$i"]["shift"] == 0
        data["branch"]["$i"]["ta_min"] = 0
        data["branch"]["$i"]["ta_max"] = 0
    end
end

for (i, branch) in data["branch"]
    if branch["br_x"] == 0
        branch["br_x"] = 1E-3
    end
end

for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
    if data["gen"]["$i"]["ncost"] == 0
        data["gen"]["$i"]["ncost"] = 2 
        push!(data["gen"]["$i"]["cost"], 0)
        push!(data["gen"]["$i"]["cost"], 0)
        push!(data["gen"]["$i"]["cost"], 0)
        push!(data["gen"]["$i"]["cost"], 0)
    end
    if data["gen"]["$i"]["ncost"] == 2 && length(data["gen"]["$i"]["cost"]) == 2
        push!(data["gen"]["$i"]["cost"], 0)
        push!(data["gen"]["$i"]["cost"], 0)
    end
end

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end

bus_dict = Dict{Int,Int}([(parse(Int, bus_id), i) for (i, bus_id) in enumerate(keys(data["bus"]))])

Bus = Dict{String, Any}()
for (id, bus) in data["bus"]
    new_id = bus_dict[parse(Int, id)]
    Bus["$new_id"] = deepcopy(bus)
    Bus["$new_id"]["index"] = new_id
end
data["bus"] = deepcopy(Bus)

for (k, branch) in data["branch"]
    branch["f_bus"] = bus_dict[branch["f_bus"]]
    branch["t_bus"] = bus_dict[branch["t_bus"]]
end
# gen_pair = []
# for (l,gen) in data["gen"]
#     for (k,genr) in data["gen"]
#         if gen["gen_bus"] == genr["gen_bus"] && l != k
#             push!(gen_pair, (l,k))
#         end
#     end
# end
for (l, gen) in data["gen"]
    # if l ∉ gen_pair
        gen["gen_bus"] = bus_dict[gen["gen_bus"]]
    # end
end
# for (i,j) in gen_pairs
#     data["gen"]["$i"]["gen_bus"] = data["gen"]["$j"]["gen_bus"] = bus_dict[data["gen"]["$i"]["gen_bus"]]
# end

for (o,load) in data["load"]
    load["load_bus"] = bus_dict[load["load_bus"]]
end
for (n, shunt) in data["shunt"]
    shunt["shunt_bus"] = bus_dict[shunt["shunt_bus"]]
end
for (m, convdc) in data["convdc"]
    convdc["busac_i"] = bus_dict[convdc["busac_i"]]
end

# for (i, bus) in data["bus"]
#     if bus["name"] == "bus_2202"
#         println("bus 838 ........ $(bus["index"])")
#     elseif bus["name"] == "bus_5150"
#         println("bus 2250 ........ $(bus["index"])")
#     elseif bus["name"] == "bus_1218"
#         println("bus 211 ........ $(bus["index"])")
#     elseif bus["name"] == "bus_1651"
#         println("bus 636 ........ $(bus["index"])")
#     elseif bus["name"] == "bus_2355"
#         println("bus 986 ........ $(bus["index"])")
#     elseif bus["name"] == "bus_4185"
#         println("bus 1800 ........ $(bus["index"])")
#     end
# end
# for (i, bus) in data["bus"]
#     if bus["name"] == "bus_1002"
#         println("bus 3 ........ $(bus["index"])")
#     elseif bus["name"] == "bus_5033"
#         println("bus 2136 ........ $(bus["index"])")
#     end
# end

data["convdc"]["1"]["busac_i"] = 1005
data["convdc"]["2"]["busac_i"] = 1508
data["convdc"]["3"]["busac_i"] = 877
data["convdc"]["4"]["busac_i"] = 182
data["convdc"]["5"]["busac_i"] = 1920
data["convdc"]["6"]["busac_i"] = 316

##
# result = _PMSC.run_c1_scopf_contigency_cuts(data, DCPPowerModel, lp_solver)
# result = _PMSC.run_c1_scopf_contigency_cuts(data, ACPPowerModel, opadtimizer)


split_large_coal_powerplants_to_units!(data)

for (i, gen) in data["gen"]
    if gen["fuel"] == "CapBank/SVC/StatCom/SynCon"
        gen["pmax"] = 0
    end
end
 

_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)


filter_ndc_time=@elapsed ndc_contingencies = __PMSCACDC.filter_dominated_contingencies(data, _PM.ACPPowerModel, nlp_solver, setting)

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

data["gen_contingencies"] = ndc_contingencies.gen_contingencies
data["branch_contingencies"] = ndc_contingencies.branch_contingencies


scopf_solve_time=@elapsed results = __PMSCACDC.run_acdc_scopf_ptdf_dcdf_cuts(data, _PM.ACPPowerModel, __PMSCACDC.run_acdc_scopf_cuts, nlp_solver)

##
using PowerPlots
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


plot_nem = powerplot(plotdata; gen_color = "red", bus_color="black", branch_color="blue", dcline_color = "green", bus_size=10, gen_size=50, branch_size=1, load_size = 0, dcline_size = 3, show_flow=true, connector_size=1, width=2000, height=2000)
PowerPlots.Experimental.add_zoom!(plot_nem)
save("plot_nem2.html", plot_nem)

plotdata_area1 = Dict{String, Any}()
plotdata_area1["bus"] = Dict{String, Any}()
plotdata_area1["branch"] = Dict{String, Any}()
plotdata_area1["gen"] = Dict{String, Any}()
plotdata_area1["load"] = Dict{String, Any}()
plotdata_area1["dcline"] = Dict{String, Any}()

for (i, bus) in plotdata["bus"]
    if bus["area"] == 1
        plotdata_area1["bus"][i] = plotdata["bus"][i]
    end
end
for (i, branch) in plotdata["branch"]
    if plotdata["bus"]["$(branch["f_bus"])"]["area"] == 1 || plotdata["bus"]["$(branch["t_bus"])"]["area"]  == 1 
        plotdata_area1["branch"][i] = plotdata["branch"][i]
    end
end
for (i, gen) in plotdata["gen"]
    if plotdata["bus"]["$(gen["gen_bus"])"]["area"]  == 1 || plotdata["bus"]["$(gen["gen_bus"])"]["area"]  == 1 
        plotdata_area1["gen"][i] = plotdata["gen"][i]
    end
end
for (i,load) in plotdata["load"]
    if plotdata["bus"]["$(load["load_bus"])"]["area"] == 1
        plotdata_area1["load"][i] = plotdata["load"][i]
    end
end
plotdata_area1["dcline"] = plotdata["dcline"]

plot_nem = powerplot(plotdata_area1; gen_color = "red", bus_color="black", branch_color="blue", dcline_color = "green", bus_size=10, gen_size=50, branch_size=1, load_size = 0, dcline_size = 3, show_flow=true, connector_size=1, width=2000, height=2000)

for (i,bus) in data["bus"]
    if bus["area"] == 1
    println("$(bus["index"])")
    end
end


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



