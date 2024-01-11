"""
This function transforms a contigency list into explicit multinetwork data including
HVAC and HVDC grid with network 0 being the base case

"""

function build_scopf_acdc_multinetwork(network::Dict{String,<:Any})         
    if _IM.ismultinetwork(network)
        error(_LOGGER, "build_scopf_acdc_multinetwork can only be used on single networks")
    end

    contingencies = length(network["gen_contingencies"]) + length(network["branch_contingencies"]) + length(network["branchdc_contingencies"]) + length(network["convdc_contingencies"])   

    _PMSC.info(_LOGGER, "building scopf multi-network with $(contingencies+1) networks")

    if contingencies > 0
        mn_data = _PM.replicate(network, contingencies)
        base_network = mn_data["nw"]["0"] = deepcopy(mn_data["nw"]["1"])

        for (n, network) in mn_data["nw"]
            if n == "0"
                continue
            end

            for (i,bus) in network["bus"]
                if haskey(bus, "evhi")
                    bus["vmax"] = bus["evhi"]
                end
                if haskey(bus, "evlo")
                    bus["vmin"] = bus["evlo"]
                end
            end

            for (i,branch) in network["branch"]
                if haskey(branch, "rate_c")
                    branch["rate_a"] = branch["rate_c"]
                end
            end
        end

        network_id = 1
        for cont in base_network["gen_contingencies"]
            cont_nw = mn_data["nw"]["$(network_id)"]
            cont_nw["name"] = cont.label
            cont_gen = cont_nw["gen"]["$(cont.idx)"]
            cont_gen["gen_status"] = 0

            gen_buses = Set{Int}()
            for (i,gen) in cont_nw["gen"]
                if gen["gen_status"] != 0
                    push!(gen_buses, gen["gen_bus"])
                end
            end
            cont_nw["gen_buses"] = gen_buses

            network["response_gens"] = Set()
            gen_bus = cont_nw["bus"]["$(cont_gen["gen_bus"])"]
            cont_nw["response_gens"] = cont_nw["area_gens"][gen_bus["area"]]

            network_id += 1
        end
        
        for cont in base_network["branch_contingencies"]
            cont_nw = mn_data["nw"]["$(network_id)"]
            cont_nw["name"] = cont.label
            cont_branch = cont_nw["branch"]["$(cont.idx)"]
            cont_branch["br_status"] = 0

            gen_buses = Set{Int}()
            for (i,gen) in cont_nw["gen"]
                if gen["gen_status"] != 0
                    push!(gen_buses, gen["gen_bus"])
                end
            end
            cont_nw["gen_buses"] = gen_buses

            fr_bus = cont_nw["bus"]["$(cont_branch["f_bus"])"]
            to_bus = cont_nw["bus"]["$(cont_branch["t_bus"])"]

            cont_nw["response_gens"] = Set()
            if haskey(cont_nw["area_gens"], fr_bus["area"])
                cont_nw["response_gens"] = cont_nw["area_gens"][fr_bus["area"]]
            end
            if haskey(network["area_gens"], to_bus["area"])
                cont_nw["response_gens"] = union(cont_nw["response_gens"], cont_nw["area_gens"][to_bus["area"]])
            end

            network_id += 1
        end

        for cont in base_network["branchdc_contingencies"]         
            cont_nw = mn_data["nw"]["$(network_id)"]
            cont_nw["name"] = cont.label
            cont_branchdc = cont_nw["branchdc"]["$(cont.idx)"]        
            cont_branchdc["status"] = 0                                 

            gen_buses = Set{Int}()
            for (i,gen) in cont_nw["gen"]
                if gen["gen_status"] != 0
                    push!(gen_buses, gen["gen_bus"])
                end
            end
            cont_nw["gen_buses"] = gen_buses

            fr_busdc = cont_nw["busdc"]["$(cont_branchdc["fbusdc"])"]          
            to_busdc = cont_nw["busdc"]["$(cont_branchdc["tbusdc"])"]          

            cont_nw["response_gens"] = Set()
            if haskey(cont_nw["area_gens"], fr_busdc["area"])                          
                cont_nw["response_gens"] = cont_nw["area_gens"][fr_busdc["area"]]       
            end
            if haskey(network["area_gens"], to_busdc["area"])                           
                cont_nw["response_gens"] = union(cont_nw["response_gens"], cont_nw["area_gens"][to_busdc["area"]])         
            end

            network_id += 1
        end

        for cont in base_network["convdc_contingencies"]         
            cont_nw = mn_data["nw"]["$(network_id)"]
            cont_nw["name"] = cont.label
            cont_convdc = cont_nw["convdc"]["$(cont.idx)"]        
            cont_convdc["status"] = 0                                 

            gen_buses = Set{Int}()
            for (i,gen) in cont_nw["gen"]
                if gen["gen_status"] != 0
                    push!(gen_buses, gen["gen_bus"])
                end
            end
            cont_nw["gen_buses"] = gen_buses

            busac = cont_nw["bus"]["$(cont_convdc["busac_i"])"]          
            busdc = cont_nw["busdc"]["$(cont_convdc["busdc_i"])"]          

            cont_nw["response_gens"] = Set()
            if haskey(cont_nw["area_gens"], busac["area"])                          
                cont_nw["response_gens"] = cont_nw["area_gens"][busac["area"]]       
            end
            if haskey(network["area_gens"], busdc["area"])                           
                cont_nw["response_gens"] = union(cont_nw["response_gens"], cont_nw["area_gens"][busdc["area"]])         
            end

            network_id += 1
        end

    else
        mn_data = _PM.replicate(network, 1)
        mn_data["nw"]["0"] = mn_data["nw"]["1"]
        delete!(mn_data["nw"], "1")
    end

    return mn_data
end


function update_data_converter_setpoints!(data, solution)
    for (i,conv) in data["convdc"]
        conv["P_g"] = -solution["convdc"][i]["pgrid"]
        conv["Q_g"] = -solution["convdc"][i]["qgrid"]
    end
    return data
end

function update_data_branch_tap_shift!(data, solution)
    for (i, branch) in data["branch"]
        if haskey(solution["branch"], i)
            branch["tap"] = solution["branch"][i]["tm"]
            branch["shift"] = solution["branch"][i]["ta"]
        end
    end
    return data
end

function add_losses_and_loss_distribution_factors!(data)   
    data["ploss"] = sum(abs(branch["pf"] + branch["pt"]) for (b,branch) in data["branch"] if branch["br_status"] !=0)
    load_total = sum(load["pd"] for (i,load) in data["load"] if load["status"] != 0)
    data["ploss_df"] = Dict(bus["index"] => 0.0 for (i,bus) in data["bus"])
    for (i, load) in data["load"]
        data["ploss_df"][load["load_bus"]] = load["pd"]/load_total
    end
    return data
end