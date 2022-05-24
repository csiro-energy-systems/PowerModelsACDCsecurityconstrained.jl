"""
transforms a contigency list into explicit multinetwork data with network 0
being the base case
"""
function build_c1_scopf_multinetwork_GM(network::Dict{String,<:Any})          #Update_GM
    if _IM.ismultinetwork(network)
        error(_LOGGER, "build scopf can only be used on single networks")
    end

    contingencies = length(network["gen_contingencies"]) + length(network["branch_contingencies"]) + length(network["branchdc_contingencies"])    #Update_GM

    info(_LOGGER, "building scopf multi-network with $(contingencies+1) networks")

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

        ###########################################################################################  #Update_GM
        for cont in base_network["branchdc_contingencies"]          #Update_GM
            cont_nw = mn_data["nw"]["$(network_id)"]
            cont_nw["name"] = cont.label
            cont_branchdc = cont_nw["branchdc"]["$(cont.idx)"]          #Update_GM
            cont_branchdc["status"] = 0                                 #Update_GM

            gen_buses = Set{Int}()
            for (i,gen) in cont_nw["gen"]
                if gen["gen_status"] != 0
                    push!(gen_buses, gen["gen_bus"])
                end
            end
            cont_nw["gen_buses"] = gen_buses

            fr_busdc = cont_nw["busdc"]["$(cont_branchdc["fbusdc"])"]          #Update_GM
            to_busdc = cont_nw["busdc"]["$(cont_branchdc["tbusdc"])"]          #Update_GM

            cont_nw["response_gens"] = Set()
            if haskey(cont_nw["area_gens"], fr_busdc["area"])                           #Update_GM
                cont_nw["response_gens"] = cont_nw["area_gens"][fr_busdc["area"]]       #Update_GM
            end
            if haskey(network["area_gens"], to_busdc["area"])                           #Update_GM
                cont_nw["response_gens"] = union(cont_nw["response_gens"], cont_nw["area_gens"][to_busdc["area"]])          #Update_GM
            end

            network_id += 1
        end
        ###########################################################################################  #Update_GM

    else
        mn_data = _PM.replicate(network, 1)
        mn_data["nw"]["0"] = mn_data["nw"]["1"]
        delete!(mn_data["nw"], "1")
    end

    return mn_data
end
