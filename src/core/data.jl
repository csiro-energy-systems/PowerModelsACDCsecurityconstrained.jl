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





function fix_scopf_data_issues!(data)

    # Defining generator areas sets: data["area_gens"]

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

    # Defining generator participation factors: gen["alpha"]

    gen_total1 = sum(data["gen"]["$i"]["pmax"] for i in collect(set1))
    gen_total2 = sum(data["gen"]["$i"]["pmax"] for i in collect(set2))
    gen_total3 = sum(data["gen"]["$i"]["pmax"] for i in collect(set3))
    gen_total4 = sum(data["gen"]["$i"]["pmax"] for i in collect(set4))
    gen_total5 = sum(data["gen"]["$i"]["pmax"] for i in collect(set5))

    for i in collect(set1)
        if data["gen"]["$i"]["type"] != "VAr support"
            data["gen"]["$i"]["alpha"] = gen_total1/data["gen"]["$i"]["pmax"]
        else
            data["gen"]["$i"]["alpha"] = 0.0
        end 
    end

    for i in collect(set2)
        if data["gen"]["$i"]["type"] != "VAr support"
            data["gen"]["$i"]["alpha"] = gen_total2/data["gen"]["$i"]["pmax"] 
        else
            data["gen"]["$i"]["alpha"] = 0.0
        end  
    end

    for i in collect(set3)
        if data["gen"]["$i"]["type"] != "VAr support"
            data["gen"]["$i"]["alpha"] = gen_total3/data["gen"]["$i"]["pmax"]
        else
            data["gen"]["$i"]["alpha"] = 0.0
        end   
    end

    for i in collect(set4)
        if data["gen"]["$i"]["type"] != "VAr support"
            data["gen"]["$i"]["alpha"] = gen_total4/data["gen"]["$i"]["pmax"]
        else
            data["gen"]["$i"]["alpha"] = 0.0
        end  
    end

    for i in collect(set5)
        if data["gen"]["$i"]["type"] != "VAr support"
            data["gen"]["$i"]["alpha"] = gen_total5/data["gen"]["$i"]["pmax"]
        else
            data["gen"]["$i"]["alpha"] = 0.0
        end   
    end

    # Adding emergency ac branch ratings and transformer tap and shift bounds 

    for i=1:length(data["branch"])
        data["branch"]["$i"]["rate_c"] = 1.3 * data["branch"]["$i"]["rate_c"]
        data["branch"]["$i"]["rate_a"] = data["branch"]["$i"]["rate_c"]
        data["branch"]["$i"]["rate_b"] = data["branch"]["$i"]["rate_c"]
        data["branch"]["$i"]["tm_min"] = 0.9
        data["branch"]["$i"]["tm_max"] = 1.1
        data["branch"]["$i"]["ta_min"] = -15
        data["branch"]["$i"]["ta_max"] = 15  
    end
    
    # Defining the smoothing coefficient for generator response constraint

    for i=1:length(data["gen"])
        data["gen"]["$i"]["ep"] = 1e-1
    end

    # Ading converter dead band voltage bounds and smoothing coefficient for droop constraints

    for i=1:length(data["convdc"])
        data["convdc"]["$i"]["ep"] = 1e-1
        data["convdc"]["$i"]["Vdclow"] = 0.98
        data["convdc"]["$i"]["Vdchigh"] = 1.02
    end

    # Empting the data["contingencies"] Dict to save memory  

    data["contingencies"] = []

    # Splitting large coal plant modeled as single generator into units

    split_large_coal_powerplants_to_units!(data)

    # Adding converter convdc["busac_i"])"]["area"]

    for (i,conv) in data["convdc"]
        data["busdc"]["$(conv["busdc_i"])"]["area"] = data["bus"]["$(conv["busac_i"])"]["area"]
    end

    # Setting upper and lower bound of voltage the same for all buses 

    for (i,bus) in data["bus"]
        bus["vmax"] = 1.1
        bus["vmin"] = 0.9
    end

    # Add generator contingencies
    data["gen_contingencies"] = Vector{Any}(undef, 221)
    data["gen_contingencies"][1] = (idx = 1, label = "gen_1002_1__4.25MW", type = "gen")
    data["gen_contingencies"][2] = (idx = 54, label = "gen_2030_8__1.1MW", type = "gen")
    data["gen_contingencies"][3] = (idx = 101, label = "gen_3425_3__4.2MW", type = "gen")
    data["gen_contingencies"][4] = (idx = 41, label = "gen_1084_1__0.6MW", type = "gen")
    data["gen_contingencies"][5] = (idx = 65, label = "gen_2054_1__1.2MW", type = "gen")
    data["gen_contingencies"][6] = (idx = 168, label = "gen_5012_1__0.4MW", type = "gen")
    data["gen_contingencies"][7] = (idx = 159, label = "gen_4079_12__1.1MW", type = "gen")
    data["gen_contingencies"][8] = (idx = 190, label = "gen_5229_1__0.7MW", type = "gen")
    data["gen_contingencies"][9] = (idx = 88, label = "gen_3155_1__0.8MW", type = "gen")
    data["gen_contingencies"][10] = (idx = 26, label = "gen_1059_1__0.5MW", type = "gen")
    data["gen_contingencies"][11] = (idx = 24, label = "gen_1044_1__4.2MW", type = "gen")
    data["gen_contingencies"][12] = (idx = 23, label = "gen_1043_6__3.5MW", type = "gen")
    data["gen_contingencies"][13] = (idx = 160, label = "gen_4081_2__0.8MW", type = "gen")
    data["gen_contingencies"][14] = (idx = 149, label = "gen_4058_1__1.7MW", type = "gen")
    data["gen_contingencies"][15] = (idx = 59, label = "gen_2041_2__2.1MW", type = "gen")
    data["gen_contingencies"][16] = (idx = 184, label = "gen_5036_2__0.4MW", type = "gen")
    data["gen_contingencies"][17] = (idx = 43, label = "gen_2003_7__0.9MW", type = "gen")
    data["gen_contingencies"][18] = (idx = 122, label = "gen_3463_1__1.1MW", type = "gen")
    data["gen_contingencies"][19] = (idx = 253, label = "gen_4084_1__0.8MW", type = "gen")
    data["gen_contingencies"][20] = (idx = 175, label = "gen_5022_1__0.4MW", type = "gen")
    data["gen_contingencies"][21] = (idx = 39, label = "gen_1081_5__4.2MW", type = "gen")
    data["gen_contingencies"][22] = (idx = 143, label = "gen_4035_1__0.4MW", type = "gen")
    data["gen_contingencies"][23] = (idx = 112, label = "gen_3443_2__3.2MW", type = "gen")
    data["gen_contingencies"][24] = (idx = 34, label = "gen_1074_2__1.1MW", type = "gen")
    data["gen_contingencies"][25] = (idx = 137, label = "gen_4027_1__0.4MW", type = "gen")
    data["gen_contingencies"][26] = (idx = 55, label = "gen_2036_1__1.1MW", type = "gen")
    data["gen_contingencies"][27] = (idx = 243, label = "gen_4022_1__1.2MW", type = "gen")
    data["gen_contingencies"][28] = (idx = 9, label = "gen_1018_2__4.15MW", type = "gen")
    data["gen_contingencies"][29] = (idx = 172, label = "gen_5019_1__0.2MW", type = "gen")
    data["gen_contingencies"][30] = (idx = 12, label = "gen_1022_1__1.1MW", type = "gen")
    data["gen_contingencies"][31] = (idx = 192, label = "gen_5231_1__0.4MW", type = "gen")
    data["gen_contingencies"][32] = (idx = 20, label = "gen_1040_3__3.5MW", type = "gen")
    data["gen_contingencies"][33] = (idx = 252, label = "gen_4050_1__1.1MW", type = "gen")
    data["gen_contingencies"][34] = (idx = 14, label = "gen_1031_1__1.0MW", type = "gen")
    data["gen_contingencies"][35] = (idx = 167, label = "gen_5010_1__1.3MW", type = "gen")
    data["gen_contingencies"][36] = (idx = 127, label = "gen_3527_1__2.3MW", type = "gen")
    data["gen_contingencies"][37] = (idx = 96, label = "gen_3420_4__3.4MW", type = "gen")
    data["gen_contingencies"][38] = (idx = 123, label = "gen_3464_1__1.9MW", type = "gen")
    data["gen_contingencies"][39] = (idx = 177, label = "gen_5026_5__0.4MW", type = "gen")
    data["gen_contingencies"][40] = (idx = 19, label = "gen_1039_2__3.4MW", type = "gen")
    data["gen_contingencies"][41] = (idx = 179, label = "gen_5030_1__0.6MW", type = "gen")
    data["gen_contingencies"][42] = (idx = 242, label = "gen_4020_2__1.4MW", type = "gen")
    data["gen_contingencies"][43] = (idx = 239, label = "gen_4013_22__0.3MW", type = "gen")
    data["gen_contingencies"][44] = (idx = 35, label = "gen_1075_3__1.2MW", type = "gen")
    data["gen_contingencies"][45] = (idx = 131, label = "gen_3588_4__2.6MW", type = "gen")
    data["gen_contingencies"][46] = (idx = 21, label = "gen_1041_4__3.4MW", type = "gen")
    data["gen_contingencies"][47] = (idx = 83, label = "gen_2322_3__0.5MW", type = "gen")
    data["gen_contingencies"][48] = (idx = 244, label = "gen_4023_1__1.1MW", type = "gen")
    data["gen_contingencies"][49] = (idx = 45, label = "gen_2010_1__1.0MW", type = "gen")
    data["gen_contingencies"][50] = (idx = 139, label = "gen_4029_1__0.4MW", type = "gen")
    data["gen_contingencies"][51] = (idx = 181, label = "gen_5032_2__1.8MW", type = "gen")
    data["gen_contingencies"][52] = (idx = 85, label = "gen_2324_1__0.6MW", type = "gen")
    data["gen_contingencies"][53] = (idx = 105, label = "gen_3434_1__1.6MW", type = "gen")
    data["gen_contingencies"][54] = (idx = 30, label = "gen_1069_1__2.2MW", type = "gen")
    data["gen_contingencies"][55] = (idx = 3, label = "gen_1004_3__4.6MW", type = "gen")
    data["gen_contingencies"][56] = (idx = 81, label = "gen_2094_3__4.9MW", type = "gen")
    data["gen_contingencies"][57] = (idx = 27, label = "gen_1060_2__0.5MW", type = "gen")
    data["gen_contingencies"][58] = (idx = 75, label = "gen_2064_12__3.6MW", type = "gen")
    data["gen_contingencies"][59] = (idx = 50, label = "gen_2016_2__0.8MW", type = "gen")
    data["gen_contingencies"][60] = (idx = 162, label = "gen_4083_4__0.6MW", type = "gen")
    data["gen_contingencies"][61] = (idx = 63, label = "gen_2046_1__3.3MW", type = "gen")
    data["gen_contingencies"][62] = (idx = 92, label = "gen_3301_1__0.5MW", type = "gen")
    data["gen_contingencies"][63] = (idx = 208, label = "gen_2007_1__0.7MW", type = "gen")
    data["gen_contingencies"][64] = (idx = 214, label = "gen_2076_1__0.8MW", type = "gen")
    data["gen_contingencies"][65] = (idx = 120, label = "gen_3457_5__0.1MW", type = "gen")
    data["gen_contingencies"][66] = (idx = 87, label = "gen_3154_3__0.6MW", type = "gen")
    data["gen_contingencies"][67] = (idx = 117, label = "gen_3454_2__0.3MW", type = "gen")
    data["gen_contingencies"][68] = (idx = 178, label = "gen_5028_1__0.4MW", type = "gen")
    data["gen_contingencies"][69] = (idx = 89, label = "gen_3156_2__0.6MW", type = "gen")
    data["gen_contingencies"][70] = (idx = 176, label = "gen_5023_2__0.4MW", type = "gen")
    data["gen_contingencies"][71] = (idx = 182, label = "gen_5033_3__1.7MW", type = "gen")
    data["gen_contingencies"][72] = (idx = 195, label = "gen_5235_1__0.4MW", type = "gen")
    data["gen_contingencies"][73] = (idx = 249, label = "gen_4047_1__1.0MW", type = "gen")
    data["gen_contingencies"][74] = (idx = 161, label = "gen_4082_3__1.1MW", type = "gen")
    data["gen_contingencies"][75] = (idx = 146, label = "gen_4052_11__2.0MW", type = "gen")
    data["gen_contingencies"][76] = (idx = 142, label = "gen_4034_1__0.4MW", type = "gen")
    data["gen_contingencies"][77] = (idx = 219, label = "gen_2246_1__0.7MW", type = "gen")
    data["gen_contingencies"][78] = (idx = 80, label = "gen_2093_2__4.2MW", type = "gen")
    data["gen_contingencies"][79] = (idx = 113, label = "gen_3444_1__3.4MW", type = "gen")
    data["gen_contingencies"][80] = (idx = 110, label = "gen_3439_2__2.1MW", type = "gen")
    data["gen_contingencies"][81] = (idx = 157, label = "gen_4072_1__0.6MW", type = "gen")
    data["gen_contingencies"][82] = (idx = 57, label = "gen_2038_3__1.1MW", type = "gen")
    data["gen_contingencies"][83] = (idx = 165, label = "gen_5006_1__1.0MW", type = "gen")
    data["gen_contingencies"][84] = (idx = 173, label = "gen_5020_1__0.5MW", type = "gen")
    data["gen_contingencies"][85] = (idx = 200, label = "gen_1025_1__0.6MW", type = "gen")
    data["gen_contingencies"][86] = (idx = 171, label = "gen_5018_2__1.0MW", type = "gen")
    data["gen_contingencies"][87] = (idx = 130, label = "gen_3587_3__4.3MW", type = "gen")
    data["gen_contingencies"][88] = (idx = 15, label = "gen_1034_1__3.25MW", type = "gen")
    data["gen_contingencies"][89] = (idx = 61, label = "gen_2044_3__3.5MW", type = "gen")
    data["gen_contingencies"][90] = (idx = 67, label = "gen_2056_3__0.5MW", type = "gen")
    data["gen_contingencies"][91] = (idx = 108, label = "gen_3437_4__3.8MW", type = "gen")
    data["gen_contingencies"][92] = (idx = 100, label = "gen_3424_2__4.3MW", type = "gen")
    data["gen_contingencies"][93] = (idx = 46, label = "gen_2011_2__1.8MW", type = "gen")
    data["gen_contingencies"][94] = (idx = 251, label = "gen_4049_1__0.6MW", type = "gen")
    data["gen_contingencies"][95] = (idx = 170, label = "gen_5017_1__2.0MW", type = "gen")
    data["gen_contingencies"][96] = (idx = 151, label = "gen_4061_4__1.6MW", type = "gen")
    data["gen_contingencies"][97] = (idx = 68, label = "gen_2057_4__1.2MW", type = "gen")
    data["gen_contingencies"][98] = (idx = 56, label = "gen_2037_2__1.1MW", type = "gen")
    data["gen_contingencies"][99] = (idx = 147, label = "gen_4053_12__2.0MW", type = "gen")
    data["gen_contingencies"][100] = (idx = 76, label = "gen_2069_1__0.6MW", type = "gen")
    data["gen_contingencies"][101] = (idx = 186, label = "gen_5039_3__0.7MW", type = "gen")
    data["gen_contingencies"][102] = (idx = 180, label = "gen_5031_1__1.7MW", type = "gen")
    data["gen_contingencies"][103] = (idx = 135, label = "gen_4007_1__1.3MW", type = "gen")
    data["gen_contingencies"][104] = (idx = 48, label = "gen_2014_1__1.9MW", type = "gen")
    data["gen_contingencies"][105] = (idx = 103, label = "gen_3430_1__4.3MW", type = "gen")
    data["gen_contingencies"][106] = (idx = 32, label = "gen_1071_1__2.1MW", type = "gen")
    data["gen_contingencies"][107] = (idx = 109, label = "gen_3438_1__2.1MW", type = "gen")
    data["gen_contingencies"][108] = (idx = 2, label = "gen_1003_2__4.6MW", type = "gen")
    data["gen_contingencies"][109] = (idx = 183, label = "gen_5035_3__0.4MW", type = "gen")
    data["gen_contingencies"][110] = (idx = 155, label = "gen_4066_1__1.8MW", type = "gen")
    data["gen_contingencies"][111] = (idx = 51, label = "gen_2021_14__1.6MW", type = "gen")
    data["gen_contingencies"][112] = (idx = 53, label = "gen_2028_6__1.2MW", type = "gen")
    data["gen_contingencies"][113] = (idx = 106, label = "gen_3435_2__1.6MW", type = "gen")
    data["gen_contingencies"][114] = (idx = 141, label = "gen_4033_1__0.4MW", type = "gen")
    data["gen_contingencies"][115] = (idx = 93, label = "gen_3417_1__3.3MW", type = "gen")
    data["gen_contingencies"][116] = (idx = 10, label = "gen_1019_3__4.15MW", type = "gen")
    data["gen_contingencies"][117] = (idx = 215, label = "gen_2082_1__2.9MW", type = "gen")
    data["gen_contingencies"][118] = (idx = 154, label = "gen_4065_4__2.7MW", type = "gen")
    data["gen_contingencies"][119] = (idx = 49, label = "gen_2015_1__0.8MW", type = "gen")
    data["gen_contingencies"][120] = (idx = 218, label = "gen_2090_1__2.0MW", type = "gen")
    data["gen_contingencies"][121] = (idx = 5, label = "gen_1012_1__0.5MW", type = "gen")
    data["gen_contingencies"][122] = (idx = 62, label = "gen_2045_4__3.75MW", type = "gen")
    data["gen_contingencies"][123] = (idx = 196, label = "gen_5236_2__0.4MW", type = "gen")
    data["gen_contingencies"][124] = (idx = 90, label = "gen_3264_1__2.5MW", type = "gen")
    data["gen_contingencies"][125] = (idx = 205, label = "gen_1181_1__1.0MW", type = "gen")
    data["gen_contingencies"][126] = (idx = 201, label = "gen_1027_1__1.1MW", type = "gen")
    data["gen_contingencies"][127] = (idx = 164, label = "gen_5005_2__1.5MW", type = "gen")
    data["gen_contingencies"][128] = (idx = 86, label = "gen_2325_2__0.7MW", type = "gen")
    data["gen_contingencies"][129] = (idx = 126, label = "gen_3526_3__2.4MW", type = "gen")
    data["gen_contingencies"][130] = (idx = 152, label = "gen_4062_1__2.7MW", type = "gen")
    data["gen_contingencies"][131] = (idx = 71, label = "gen_2060_1__1.1MW", type = "gen")
    data["gen_contingencies"][132] = (idx = 37, label = "gen_1079_7__1.0MW", type = "gen")
    data["gen_contingencies"][133] = (idx = 245, label = "gen_4024_1__1.2MW", type = "gen")
    data["gen_contingencies"][134] = (idx = 6, label = "gen_1013_1__0.5MW", type = "gen")
    data["gen_contingencies"][135] = (idx = 125, label = "gen_3525_2__2.3MW", type = "gen")
    data["gen_contingencies"][136] = (idx = 98, label = "gen_3422_6__3.3MW", type = "gen")
    data["gen_contingencies"][137] = (idx = 174, label = "gen_5021_4__0.5MW", type = "gen")
    data["gen_contingencies"][138] = (idx = 187, label = "gen_5040_4__0.7MW", type = "gen")
    data["gen_contingencies"][139] = (idx = 7, label = "gen_1014_1__0.3MW", type = "gen")
    data["gen_contingencies"][140] = (idx = 194, label = "gen_5234_1__0.2MW", type = "gen")
    data["gen_contingencies"][141] = (idx = 140, label = "gen_4030_1__0.4MW", type = "gen")
    data["gen_contingencies"][142] = (idx = 107, label = "gen_3436_3__1.6MW", type = "gen")
    data["gen_contingencies"][143] = (idx = 102, label = "gen_3426_4__4.2MW", type = "gen")
    data["gen_contingencies"][144] = (idx = 69, label = "gen_2058_5__0.8MW", type = "gen")
    data["gen_contingencies"][145] = (idx = 97, label = "gen_3421_5__3.3MW", type = "gen")
    data["gen_contingencies"][146] = (idx = 4, label = "gen_1005_4__4.6MW", type = "gen")
    data["gen_contingencies"][147] = (idx = 13, label = "gen_1030_4__1.0MW", type = "gen")
    data["gen_contingencies"][148] = (idx = 136, label = "gen_4008_1__0.3MW", type = "gen")
    data["gen_contingencies"][149] = (idx = 211, label = "gen_2033_2__0.9MW", type = "gen")
    data["gen_contingencies"][150] = (idx = 134, label = "gen_4003_1__0.4MW", type = "gen")
    data["gen_contingencies"][151] = (idx = 133, label = "gen_3656_2__2.85MW", type = "gen")
    data["gen_contingencies"][152] = (idx = 148, label = "gen_4054_18__2.1MW", type = "gen")
    data["gen_contingencies"][153] = (idx = 240, label = "gen_4018_1__0.6MW", type = "gen")
    data["gen_contingencies"][154] = (idx = 193, label = "gen_5233_3__0.4MW", type = "gen")
    data["gen_contingencies"][155] = (idx = 118, label = "gen_3455_3__0.3MW", type = "gen")
    data["gen_contingencies"][156] = (idx = 246, label = "gen_4026_1__0.7MW", type = "gen")
    data["gen_contingencies"][157] = (idx = 38, label = "gen_1080_8__1.0MW", type = "gen")
    data["gen_contingencies"][158] = (idx = 188, label = "gen_5041_5__0.7MW", type = "gen")
    data["gen_contingencies"][159] = (idx = 199, label = "gen_1024_2__0.8MW", type = "gen")
    data["gen_contingencies"][160] = (idx = 116, label = "gen_3453_1__0.3MW", type = "gen")
    data["gen_contingencies"][161] = (idx = 66, label = "gen_2055_2__0.7MW", type = "gen")
    data["gen_contingencies"][162] = (idx = 241, label = "gen_4019_1__1.0MW", type = "gen")
    data["gen_contingencies"][163] = (idx = 18, label = "gen_1038_1__3.5MW", type = "gen")
    data["gen_contingencies"][164] = (idx = 132, label = "gen_3655_1__2.9MW", type = "gen")
    data["gen_contingencies"][165] = (idx = 29, label = "gen_1068_2__0.3MW", type = "gen")
    data["gen_contingencies"][166] = (idx = 78, label = "gen_2091_1__1.1MW", type = "gen")
    data["gen_contingencies"][167] = (idx = 74, label = "gen_2063_11__3.6MW", type = "gen")
    data["gen_contingencies"][168] = (idx = 119, label = "gen_3456_4__0.3MW", type = "gen")
    data["gen_contingencies"][169] = (idx = 42, label = "gen_1085_2__0.6MW", type = "gen")
    data["gen_contingencies"][170] = (idx = 33, label = "gen_1072_1__2.2MW", type = "gen")
    data["gen_contingencies"][171] = (idx = 28, label = "gen_1067_1__0.4MW", type = "gen")
    data["gen_contingencies"][172] = (idx = 52, label = "gen_2024_2__1.1MW", type = "gen")
    data["gen_contingencies"][173] = (idx = 121, label = "gen_3462_1__2.0MW", type = "gen")
    data["gen_contingencies"][174] = (idx = 115, label = "gen_3449_2__0.4MW", type = "gen")
    data["gen_contingencies"][175] = (idx = 163, label = "gen_5004_1__1.5MW", type = "gen")
    data["gen_contingencies"][176] = (idx = 58, label = "gen_2040_1__2.1MW", type = "gen")
    data["gen_contingencies"][177] = (idx = 25, label = "gen_1058_1__2.75MW", type = "gen")
    data["gen_contingencies"][178] = (idx = 114, label = "gen_3448_1__0.4MW", type = "gen")
    data["gen_contingencies"][179] = (idx = 166, label = "gen_5008_1__0.6MW", type = "gen")
    data["gen_contingencies"][180] = (idx = 31, label = "gen_1070_1__2.1MW", type = "gen")
    data["gen_contingencies"][181] = (idx = 206, label = "gen_1218_1__1.1MW", type = "gen")
    data["gen_contingencies"][182] = (idx = 44, label = "gen_2004_8__1.0MW", type = "gen")
    data["gen_contingencies"][183] = (idx = 169, label = "gen_5016_6__0.8MW", type = "gen")
    data["gen_contingencies"][184] = (idx = 129, label = "gen_3586_2__4.3MW", type = "gen")
    data["gen_contingencies"][185] = (idx = 189, label = "gen_5045_1__0.9MW", type = "gen")
    data["gen_contingencies"][186] = (idx = 150, label = "gen_4059_2__1.6MW", type = "gen")
    data["gen_contingencies"][187] = (idx = 94, label = "gen_3418_2__3.3MW", type = "gen")
    data["gen_contingencies"][188] = (idx = 99, label = "gen_3423_1__4.3MW", type = "gen")
    data["gen_contingencies"][189] = (idx = 207, label = "gen_1582_1__0.7MW", type = "gen")
    data["gen_contingencies"][190] = (idx = 47, label = "gen_2012_1__0.3MW", type = "gen")
    data["gen_contingencies"][191] = (idx = 73, label = "gen_2062_2__1.1MW", type = "gen")
    data["gen_contingencies"][192] = (idx = 82, label = "gen_2095_4__4.8MW", type = "gen")
    data["gen_contingencies"][193] = (idx = 79, label = "gen_2092_1__4.8MW", type = "gen")
    data["gen_contingencies"][194] = (idx = 84, label = "gen_2323_4__0.5MW", type = "gen")
    data["gen_contingencies"][195] = (idx = 104, label = "gen_3431_2__4.2MW", type = "gen")
    data["gen_contingencies"][196] = (idx = 124, label = "gen_3466_1__0.4MW", type = "gen")
    data["gen_contingencies"][197] = (idx = 238, label = "gen_4010_21__0.3MW", type = "gen")
    data["gen_contingencies"][198] = (idx = 209, label = "gen_2008_2__0.8MW", type = "gen")
    data["gen_contingencies"][199] = (idx = 185, label = "gen_5037_1__0.7MW", type = "gen")
    data["gen_contingencies"][200] = (idx = 70, label = "gen_2059_6__1.2MW", type = "gen")
    data["gen_contingencies"][201] = (idx = 191, label = "gen_5230_2__0.4MW", type = "gen")
    data["gen_contingencies"][202] = (idx = 8, label = "gen_1017_1__4.3MW", type = "gen")
    data["gen_contingencies"][203] = (idx = 198, label = "gen_1023_1__0.8MW", type = "gen")
    data["gen_contingencies"][204] = (idx = 64, label = "gen_2047_2__3.25MW", type = "gen")
    data["gen_contingencies"][205] = (idx = 222, label = "gen_2355_1__2.8MW", type = "gen")
    data["gen_contingencies"][206] = (idx = 91, label = "gen_3295_1__4.95MW", type = "gen")
    data["gen_contingencies"][207] = (idx = 158, label = "gen_4078_11__0.4MW", type = "gen")
    data["gen_contingencies"][208] = (idx = 156, label = "gen_4067_2__0.9MW", type = "gen")
    data["gen_contingencies"][209] = (idx = 144, label = "gen_4036_1__0.4MW", type = "gen")
    data["gen_contingencies"][210] = (idx = 220, label = "gen_2247_2__0.6MW", type = "gen")
    data["gen_contingencies"][211] = (idx = 22, label = "gen_1042_5__3.4MW", type = "gen")
    data["gen_contingencies"][212] = (idx = 11, label = "gen_1020_4__4.1MW", type = "gen")
    data["gen_contingencies"][213] = (idx = 16, label = "gen_1036_3__3.25MW", type = "gen")
    data["gen_contingencies"][214] = (idx = 40, label = "gen_1082_6__4.15MW", type = "gen")
    data["gen_contingencies"][215] = (idx = 72, label = "gen_2061_5__1.1MW", type = "gen")
    data["gen_contingencies"][216] = (idx = 128, label = "gen_3585_1__4.2MW", type = "gen")
    data["gen_contingencies"][217] = (idx = 145, label = "gen_4051_1__0.9MW", type = "gen")
    data["gen_contingencies"][218] = (idx = 36, label = "gen_1078_6__1.0MW", type = "gen")
    data["gen_contingencies"][219] = (idx = 95, label = "gen_3419_3__3.4MW", type = "gen")
    data["gen_contingencies"][220] = (idx = 138, label = "gen_4028_1__0.4MW", type = "gen")
    data["gen_contingencies"][221] = (idx = 153, label = "gen_4064_3__2.8MW", type = "gen")


    # Add branch contingencies
    data["branch_contingencies"] = Vector{Any}(undef, 1293)
    data["branch_contingencies"][1] = (idx = 1881, label = "xf_2194_to_2170_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][2] = (idx = 2923, label = "xf_3302_3304_3303_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][3] = (idx = 599, label = "line_3009_to_3116_1_cp", type = "branch")
    data["branch_contingencies"][4] = (idx = 228, label = "line_1206_to_1646_1_cp_merged_with_line_1365_to_1646_1_pi", type = "branch")
    data["branch_contingencies"][5] = (idx = 2590, label = "xf_4358_to_4017_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][6] = (idx = 2562, label = "xf_4328_to_4057_3_2winding_transformer_merged_with_line_4226_to_4328_1_cp", type = "branch")
    data["branch_contingencies"][7] = (idx = 1106, label = "line_4206_to_4207_1_cp", type = "branch")
    data["branch_contingencies"][8] = (idx = 928, label = "line_3545_to_3572_3_cp", type = "branch")
    data["branch_contingencies"][9] = (idx = 1863, label = "xf_2182_to_2289_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][10] = (idx = 561, label = "line_2216_to_2240_1_cp", type = "branch")
    data["branch_contingencies"][11] = (idx = 39, label = "line_1102_to_1114_1_cp", type = "branch")
    data["branch_contingencies"][12] = (idx = 2713, label = "xf_5152_to_5015_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][13] = (idx = 112, label = "line_1159_to_1637_1_cp", type = "branch")
    data["branch_contingencies"][14] = (idx = 17, label = "line_1095_to_1104_1_cp", type = "branch")
    data["branch_contingencies"][15] = (idx = 333, label = "line_1315_to_1324_1_cp", type = "branch")
    data["branch_contingencies"][16] = (idx = 341, label = "line_1331_to_1385_1_cp", type = "branch")
    data["branch_contingencies"][17] = (idx = 598, label = "line_3005_to_3006_1_cp", type = "branch")
    data["branch_contingencies"][18] = (idx = 14, label = "line_1093_to_1120_1_cp", type = "branch")
    data["branch_contingencies"][19] = (idx = 613, label = "line_3021_to_3634_1_cp", type = "branch")
    data["branch_contingencies"][20] = (idx = 1052, label = "line_4131_to_4145_1_cp", type = "branch")
    data["branch_contingencies"][21] = (idx = 2334, label = "xf_4143_to_4382_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][22] = (idx = 2585, label = "xf_4357_to_4014_6_2winding_transformer", type = "branch")
    data["branch_contingencies"][23] = (idx = 2127, label = "xf_3369_to_3370_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][24] = (idx = 401, label = "line_1404_to_1443_2_cp", type = "branch")
    data["branch_contingencies"][25] = (idx = 1973, label = "xf_3039_to_3042_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][26] = (idx = 83, label = "line_1126_to_1145_1_cp", type = "branch")
    data["branch_contingencies"][27] = (idx = 751, label = "line_3163_to_3471_1_cp", type = "branch")
    data["branch_contingencies"][28] = (idx = 3037, label = "xf_4186_4230_4494_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][29] = (idx = 1070, label = "line_4163_to_4203_1_cp", type = "branch")
    data["branch_contingencies"][30] = (idx = 3046, label = "xf_4220_4074_4498_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][31] = (idx = 2001, label = "xf_3077_to_3642_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][32] = (idx = 2752, label = "xf_1092_1093_1525_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][33] = (idx = 1882, label = "xf_2194_to_2171_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][34] = (idx = 117, label = "line_1164_to_1637_1_cp", type = "branch")
    data["branch_contingencies"][35] = (idx = 1166, label = "line_4267_to_4268_1_cp", type = "branch")
    data["branch_contingencies"][36] = (idx = 852, label = "line_3312_to_3480_1_cp_merged_with_xf_3480_to_3479_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][37] = (idx = 1675, label = "xf_1447_to_1632_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][38] = (idx = 249, label = "line_1221_to_1373_2_cp", type = "branch")
    data["branch_contingencies"][39] = (idx = 1290, label = "line_5112_to_5223_1_cp", type = "branch")
    data["branch_contingencies"][40] = (idx = 1132, label = "line_4239_to_4240_1_cp", type = "branch")
    data["branch_contingencies"][41] = (idx = 3027, label = "xf_4160_4097_4401_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][42] = (idx = 1110, label = "line_4210_to_4213_1_cp", type = "branch")
    data["branch_contingencies"][43] = (idx = 1085, label = "line_4177_to_4178_1_cp", type = "branch")
    data["branch_contingencies"][44] = (idx = 3044, label = "xf_4220_4074_4498_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][45] = (idx = 717, label = "line_3129_to_3342_1_cp", type = "branch")
    data["branch_contingencies"][46] = (idx = 3047, label = "xf_4220_4074_4499_5_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][47] = (idx = 61, label = "line_1113_to_1151_1_cp", type = "branch")
    data["branch_contingencies"][48] = (idx = 247, label = "line_1221_to_1316_1_cp", type = "branch")
    data["branch_contingencies"][49] = (idx = 2126, label = "xf_3368_to_3370_2_2winding_transformer_merged_with_line_3368_to_3382_2_cp", type = "branch")
    data["branch_contingencies"][50] = (idx = 2220, label = "xf_3582_to_3633_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][51] = (idx = 1285, label = "line_5102_to_5106_1_cp", type = "branch")
    data["branch_contingencies"][52] = (idx = 435, label = "line_1594_to_1595_1_cp", type = "branch")
    data["branch_contingencies"][53] = (idx = 1023, label = "line_4002_to_4154_1_cp", type = "branch")
    data["branch_contingencies"][54] = (idx = 2772, label = "xf_1106_1167_1537_4_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][55] = (idx = 994, label = "line_3584_to_3597_2_cp", type = "branch")
    data["branch_contingencies"][56] = (idx = 742, label = "line_3158_to_3612_1_cp", type = "branch")
    data["branch_contingencies"][57] = (idx = 315, label = "line_1292_to_1297_1_cp", type = "branch")
    data["branch_contingencies"][58] = (idx = 841, label = "line_3299_to_3633_1_cp", type = "branch")
    data["branch_contingencies"][59] = (idx = 984, label = "line_3572_to_3589_1_cp", type = "branch")
    data["branch_contingencies"][60] = (idx = 731, label = "line_3142_to_3283_1_cp", type = "branch")
    data["branch_contingencies"][61] = (idx = 1176, label = "line_4279_to_4288_1_cp", type = "branch")
    data["branch_contingencies"][62] = (idx = 97, label = "line_1138_to_1144_1_cp", type = "branch")
    data["branch_contingencies"][63] = (idx = 2733, label = "xf_5169_to_5118_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][64] = (idx = 2918, label = "xf_3302_3304_3303_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][65] = (idx = 193, label = "line_1195_to_1430_1_cp", type = "branch")
    data["branch_contingencies"][66] = (idx = 2886, label = "xf_2200_2196_2304_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][67] = (idx = 2917, label = "xf_3302_3304_3303_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][68] = (idx = 116, label = "line_1164_to_1447_1_cp", type = "branch")
    data["branch_contingencies"][69] = (idx = 1906, label = "xf_2226_to_2302_1_2winding_transformer_merged_with_line_2009_to_2302_1_cp", type = "branch")
    data["branch_contingencies"][70] = (idx = 29, label = "line_1098_to_1125_1_cp", type = "branch")
    data["branch_contingencies"][71] = (idx = 1713, label = "xf_1530_to_1610_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][72] = (idx = 367, label = "line_1354_to_1627_1_cp", type = "branch")
    data["branch_contingencies"][73] = (idx = 948, label = "line_3557_to_3608_1_cp", type = "branch")
    data["branch_contingencies"][74] = (idx = 3031, label = "xf_4166_4356_4491_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][75] = (idx = 706, label = "line_3108_to_3483_1_cp", type = "branch")
    data["branch_contingencies"][76] = (idx = 1729, label = "xf_2068_to_2070_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][77] = (idx = 1189, label = "line_4302_to_4303_1_cp", type = "branch")
    data["branch_contingencies"][78] = (idx = 2175, label = "xf_3483_to_3558_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][79] = (idx = 886, label = "line_3408_to_3496_1_cp", type = "branch")
    data["branch_contingencies"][80] = (idx = 3026, label = "xf_4160_4097_4400_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][81] = (idx = 2770, label = "xf_1106_1167_1536_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][82] = (idx = 189, label = "line_1193_to_1464_1_cp", type = "branch")
    data["branch_contingencies"][83] = (idx = 2070, label = "xf_3192_to_3605_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][84] = (idx = 1594, label = "xf_1304_to_1581_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][85] = (idx = 79, label = "line_1124_to_1144_1_cp", type = "branch")
    data["branch_contingencies"][86] = (idx = 1321, label = "line_5155_to_5162_1_cp", type = "branch")
    data["branch_contingencies"][87] = (idx = 2601, label = "xf_5048_to_5047_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][88] = (idx = 1389, label = "Dec20_line_4233_to_4234_1_dec", type = "branch")
    data["branch_contingencies"][89] = (idx = 2858, label = "xf_2191_2018_2019_6_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][90] = (idx = 922, label = "line_3543_to_3560_1_cp", type = "branch")
    data["branch_contingencies"][91] = (idx = 2337, label = "xf_4147_to_4334_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][92] = (idx = 1952, label = "xf_3010_to_3011_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][93] = (idx = 324, label = "line_1305_to_1338_1_cp", type = "branch")
    data["branch_contingencies"][94] = (idx = 2921, label = "xf_3302_3304_3303_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][95] = (idx = 667, label = "line_3072_to_3479_1_cp", type = "branch")
    data["branch_contingencies"][96] = (idx = 145, label = "line_1182_to_1456_1_cp", type = "branch")
    data["branch_contingencies"][97] = (idx = 1543, label = "xf_1156_to_1157_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][98] = (idx = 630, label = "line_3039_to_3218_1_cp", type = "branch")
    data["branch_contingencies"][99] = (idx = 2932, label = "xf_3333_3336_3335_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][100] = (idx = 1273, label = "line_5091_to_5112_1_cp", type = "branch")
    data["branch_contingencies"][101] = (idx = 972, label = "line_3566_to_3593_1_cp_merged_with_xf_3496_to_3566_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][102] = (idx = 620, label = "line_3024_to_3497_1_cp", type = "branch")
    data["branch_contingencies"][103] = (idx = 586, label = "line_2255_to_2262_2_cp", type = "branch")
    data["branch_contingencies"][104] = (idx = 43, label = "line_1103_to_1158_1_cp", type = "branch")
    data["branch_contingencies"][105] = (idx = 2926, label = "xf_3333_3335_3336_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][106] = (idx = 1717, label = "xf_1602_to_1088_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][107] = (idx = 530, label = "line_2198_to_2206_1_cp", type = "branch")
    data["branch_contingencies"][108] = (idx = 3080, label = "xf_5094_5202_5203_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][109] = (idx = 962, label = "line_3560_to_3605_1_cp", type = "branch")
    data["branch_contingencies"][110] = (idx = 1382, label = "Dec14_line_4123_to_4292_1_dec", type = "branch")
    data["branch_contingencies"][111] = (idx = 2373, label = "xf_4185_to_4229_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][112] = (idx = 1014, label = "line_3615_to_3616_1_cp", type = "branch")
    data["branch_contingencies"][113] = (idx = 2807, label = "xf_1296_1504_1505_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][114] = (idx = 889, label = "line_3411_to_3503_1_cp", type = "branch")
    data["branch_contingencies"][115] = (idx = 1817, label = "xf_2156_to_2262_2_2winding_transformer_merged_with_line_2144_to_2156_2_cp", type = "branch")
    data["branch_contingencies"][116] = (idx = 2107, label = "xf_3322_to_3323_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][117] = (idx = 458, label = "line_2105_to_2176_1_cp", type = "branch")
    data["branch_contingencies"][118] = (idx = 2716, label = "xf_5153_to_5071_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][119] = (idx = 668, label = "line_3073_to_3116_2_cp", type = "branch")
    data["branch_contingencies"][120] = (idx = 2851, label = "xf_2145_2243_2306_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][121] = (idx = 2944, label = "xf_3362_3364_3363_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][122] = (idx = 526, label = "line_2190_to_2195_1_cp", type = "branch")
    data["branch_contingencies"][123] = (idx = 2848, label = "xf_2145_2243_2306_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][124] = (idx = 92, label = "line_1133_to_1144_1_cp", type = "branch")
    data["branch_contingencies"][125] = (idx = 1262, label = "line_5089_to_5095_1_cp", type = "branch")
    data["branch_contingencies"][126] = (idx = 826, label = "line_3276_to_3642_1_cp", type = "branch")
    data["branch_contingencies"][127] = (idx = 3062, label = "xf_4257_4379_4434_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][128] = (idx = 516, label = "line_2164_to_2178_1_cp", type = "branch")
    data["branch_contingencies"][129] = (idx = 2080, label = "xf_3212_to_3465_2_2winding_transformer_merged_with_line_3212_to_3255_1_cp", type = "branch")
    data["branch_contingencies"][130] = (idx = 3024, label = "xf_4160_4097_4400_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][131] = (idx = 1146, label = "line_4251_to_4254_1_cp", type = "branch")
    data["branch_contingencies"][132] = (idx = 2985, label = "xf_3492_3565_3495_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][133] = (idx = 2906, label = "xf_3226_3227_3228_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][134] = (idx = 1034, label = "line_4106_to_4107_1_cp", type = "branch")
    data["branch_contingencies"][135] = (idx = 2908, label = "xf_3231_3644_3645_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][136] = (idx = 2221, label = "xf_3583_to_3633_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][137] = (idx = 2811, label = "xf_1296_1504_1506_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][138] = (idx = 2952, label = "xf_3371_3372_3373_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][139] = (idx = 1233, label = "line_5061_to_5062_1_cp", type = "branch")
    data["branch_contingencies"][140] = (idx = 32, label = "line_1099_to_1156_1_cp", type = "branch")
    data["branch_contingencies"][141] = (idx = 1181, label = "line_4294_to_4295_1_cp", type = "branch")
    data["branch_contingencies"][142] = (idx = 1399, label = "Dec4_line_4112_to_4135_1_dec", type = "branch")
    data["branch_contingencies"][143] = (idx = 340, label = "line_1330_to_1541_1_cp", type = "branch")
    data["branch_contingencies"][144] = (idx = 2581, label = "xf_4350_to_4009_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][145] = (idx = 1346, label = "line_1416_to_1417_1_pi_merged_with_line_1182_to_1417_1_cp", type = "branch")
    data["branch_contingencies"][146] = (idx = 2335, label = "xf_4144_to_4384_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][147] = (idx = 237, label = "line_1214_to_1605_1_cp", type = "branch")
    data["branch_contingencies"][148] = (idx = 1965, label = "xf_3028_to_3029_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][149] = (idx = 787, label = "line_3211_to_3529_1_cp", type = "branch")
    data["branch_contingencies"][150] = (idx = 272, label = "line_1240_to_1258_1_cp", type = "branch")
    data["branch_contingencies"][151] = (idx = 3038, label = "xf_4186_4230_4494_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][152] = (idx = 854, label = "line_3322_to_3504_1_cp", type = "branch")
    data["branch_contingencies"][153] = (idx = 908, label = "line_3490_to_3568_1_cp", type = "branch")
    data["branch_contingencies"][154] = (idx = 1950, label = "xf_3009_to_3011_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][155] = (idx = 283, label = "line_1256_to_1423_1_cp", type = "branch")
    data["branch_contingencies"][156] = (idx = 513, label = "line_2163_to_2186_1_cp", type = "branch")
    data["branch_contingencies"][157] = (idx = 2818, label = "xf_1428_1501_1540_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][158] = (idx = 3079, label = "xf_5094_5202_5203_2_3winding_transformer_br1_merged_with_line_5091_to_5094_2_cp", type = "branch")
    data["branch_contingencies"][159] = (idx = 2785, label = "xf_1121_1123_1634_6_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][160] = (idx = 796, label = "line_3222_to_3226_1_cp", type = "branch")
    data["branch_contingencies"][161] = (idx = 2977, label = "xf_3486_3561_3489_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][162] = (idx = 1861, label = "xf_2180_to_2290_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][163] = (idx = 382, label = "line_1375_to_1400_1_cp", type = "branch")
    data["branch_contingencies"][164] = (idx = 2902, label = "xf_3226_3227_3228_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][165] = (idx = 3029, label = "xf_4160_4097_4401_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][166] = (idx = 1031, label = "line_4103_to_4153_2_cp", type = "branch")
    data["branch_contingencies"][167] = (idx = 395, label = "line_1397_to_1621_1_cp", type = "branch")
    data["branch_contingencies"][168] = (idx = 1155, label = "line_4260_to_4341_1_cp", type = "branch")
    data["branch_contingencies"][169] = (idx = 2955, label = "xf_3371_3372_3373_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][170] = (idx = 759, label = "line_3172_to_3246_1_cp", type = "branch")
    data["branch_contingencies"][171] = (idx = 99, label = "line_1138_to_1149_1_cp", type = "branch")
    data["branch_contingencies"][172] = (idx = 647, label = "line_3061_to_3274_1_cp", type = "branch")
    data["branch_contingencies"][173] = (idx = 921, label = "line_3543_to_3556_1_cp", type = "branch")
    data["branch_contingencies"][174] = (idx = 325, label = "line_1306_to_1475_1_cp", type = "branch")
    data["branch_contingencies"][175] = (idx = 1104, label = "line_4202_to_4212_1_cp", type = "branch")
    data["branch_contingencies"][176] = (idx = 304, label = "line_1282_to_1470_1_cp", type = "branch")
    data["branch_contingencies"][177] = (idx = 2975, label = "xf_3486_3561_3488_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][178] = (idx = 1798, label = "xf_2142_to_2032_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][179] = (idx = 40, label = "line_1103_to_1118_1_cp", type = "branch")
    data["branch_contingencies"][180] = (idx = 1125, label = "line_4234_to_4235_1_cp", type = "branch")
    data["branch_contingencies"][181] = (idx = 2965, label = "xf_3483_3558_3484_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][182] = (idx = 3065, label = "xf_5087_5175_5176_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][183] = (idx = 2803, label = "xf_1273_1572_1573_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][184] = (idx = 1284, label = "line_5101_to_5103_1_cp", type = "branch")
    data["branch_contingencies"][185] = (idx = 2092, label = "xf_3243_to_3659_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][186] = (idx = 2750, label = "xf_1092_1093_1525_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][187] = (idx = 2805, label = "xf_1273_1572_1573_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][188] = (idx = 184, label = "line_1193_to_1207_1_cp", type = "branch")
    data["branch_contingencies"][189] = (idx = 1394, label = "Dec25_line_4277_to_4285_1_dec", type = "branch")
    data["branch_contingencies"][190] = (idx = 421, label = "line_1479_to_1481_1_cp", type = "branch")
    data["branch_contingencies"][191] = (idx = 1243, label = "line_5069_to_5126_1_cp", type = "branch")
    data["branch_contingencies"][192] = (idx = 2328, label = "xf_4136_to_4294_6_2winding_transformer", type = "branch")
    data["branch_contingencies"][193] = (idx = 2740, label = "xf_5227_to_5008_2_2winding_transformer_merged_with_line_5227_to_5228_1_cp", type = "branch")
    data["branch_contingencies"][194] = (idx = 1303, label = "line_5122_to_5124_1_cp", type = "branch")
    data["branch_contingencies"][195] = (idx = 127, label = "line_1167_to_1211_1_cp", type = "branch")
    data["branch_contingencies"][196] = (idx = 944, label = "line_3554_to_3598_2_cp", type = "branch")
    data["branch_contingencies"][197] = (idx = 823, label = "line_3270_to_3305_1_cp", type = "branch")
    data["branch_contingencies"][198] = (idx = 254, label = "line_1223_to_1381_1_cp", type = "branch")
    data["branch_contingencies"][199] = (idx = 242, label = "line_1219_to_1389_1_cp_merged_with_line_1389_to_1541_3_cp", type = "branch")
    data["branch_contingencies"][200] = (idx = 680, label = "line_3083_to_3240_1_cp", type = "branch")
    data["branch_contingencies"][201] = (idx = 2754, label = "xf_1092_1093_1526_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][202] = (idx = 503, label = "line_2149_to_2150_1_cp_merged_with_xf_2202_to_2149_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][203] = (idx = 2876, label = "xf_2191_2031_2022_5_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][204] = (idx = 2870, label = "xf_2191_2027_2028_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][205] = (idx = 709, label = "line_3114_to_3172_1_cp", type = "branch")
    data["branch_contingencies"][206] = (idx = 2802, label = "xf_1273_1572_1573_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][207] = (idx = 1715, label = "xf_1569_to_1221_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][208] = (idx = 496, label = "line_2138_to_2186_1_cp", type = "branch")
    data["branch_contingencies"][209] = (idx = 1933, label = "xf_2306_to_2339_6_2winding_transformer", type = "branch")
    data["branch_contingencies"][210] = (idx = 256, label = "line_1224_to_1467_1_cp", type = "branch")
    data["branch_contingencies"][211] = (idx = 3059, label = "xf_4257_4379_4434_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][212] = (idx = 80, label = "line_1124_to_1147_1_cp", type = "branch")
    data["branch_contingencies"][213] = (idx = 2905, label = "xf_3226_3227_3228_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][214] = (idx = 1940, label = "xf_2315_to_2350_6_2winding_transformer", type = "branch")
    data["branch_contingencies"][215] = (idx = 1263, label = "line_5089_to_5116_1_cp", type = "branch")
    data["branch_contingencies"][216] = (idx = 2963, label = "xf_3413_3415_3414_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][217] = (idx = 1314, label = "line_5148_to_5149_1_cp_merged_with_xf_5148_to_5061_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][218] = (idx = 1232, label = "line_5060_to_5061_1_cp", type = "branch")
    data["branch_contingencies"][219] = (idx = 675, label = "line_3080_to_3189_1_cp", type = "branch")
    data["branch_contingencies"][220] = (idx = 2043, label = "xf_3144_to_3145_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][221] = (idx = 500, label = "line_2147_to_2181_2_cp", type = "branch")
    data["branch_contingencies"][222] = (idx = 251, label = "line_1221_to_1460_2_cp", type = "branch")
    data["branch_contingencies"][223] = (idx = 2066, label = "xf_3190_to_3461_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][224] = (idx = 529, label = "line_2198_to_2199_1_cp", type = "branch")
    data["branch_contingencies"][225] = (idx = 111, label = "line_1159_to_1335_1_cp", type = "branch")
    data["branch_contingencies"][226] = (idx = 321, label = "line_1299_to_1347_1_cp", type = "branch")
    data["branch_contingencies"][227] = (idx = 2413, label = "xf_4220_to_4077_9_2winding_transformer", type = "branch")
    data["branch_contingencies"][228] = (idx = 1241, label = "line_5065_to_5066_1_cp", type = "branch")
    data["branch_contingencies"][229] = (idx = 2856, label = "xf_2162_2271_2315_5_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][230] = (idx = 1347, label = "line_1498_to_1599_1_pi", type = "branch")
    data["branch_contingencies"][231] = (idx = 2787, label = "xf_1121_1123_1635_7_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][232] = (idx = 521, label = "line_2178_to_2182_1_cp", type = "branch")
    data["branch_contingencies"][233] = (idx = 2760, label = "xf_1097_1098_1162_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][234] = (idx = 938, label = "line_3549_to_3598_1_cp", type = "branch")
    data["branch_contingencies"][235] = (idx = 107, label = "line_1148_to_2191_1_cp", type = "branch")
    data["branch_contingencies"][236] = (idx = 69, label = "line_1118_to_1148_1_cp", type = "branch")
    data["branch_contingencies"][237] = (idx = 1156, label = "line_4262_to_4326_2_cp", type = "branch")
    data["branch_contingencies"][238] = (idx = 199, label = "line_1199_to_1311_1_cp", type = "branch")
    data["branch_contingencies"][239] = (idx = 66, label = "line_1115_to_1146_1_cp", type = "branch")
    data["branch_contingencies"][240] = (idx = 468, label = "line_2117_to_2167_1_cp", type = "branch")
    data["branch_contingencies"][241] = (idx = 2838, label = "xf_2077_2205_2346_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][242] = (idx = 548, label = "line_2206_to_2207_1_cp", type = "branch")
    data["branch_contingencies"][243] = (idx = 2880, label = "xf_2195_2293_2332_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][244] = (idx = 3039, label = "xf_4187_4230_4495_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][245] = (idx = 2859, label = "xf_2191_2018_2019_6_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][246] = (idx = 236, label = "line_1214_to_1223_1_cp", type = "branch")
    data["branch_contingencies"][247] = (idx = 564, label = "line_2219_to_2282_1_cp", type = "branch")
    data["branch_contingencies"][248] = (idx = 1647, label = "xf_1392_to_1612_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][249] = (idx = 960, label = "line_3560_to_3578_2_cp_merged_with_xf_3578_to_3429_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][250] = (idx = 674, label = "line_3078_to_3643_2_cp", type = "branch")
    data["branch_contingencies"][251] = (idx = 129, label = "line_1168_to_1317_1_cp", type = "branch")
    data["branch_contingencies"][252] = (idx = 2895, label = "xf_3134_3135_3136_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][253] = (idx = 2193, label = "xf_3516_to_3584_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][254] = (idx = 1883, label = "xf_2198_to_2118_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][255] = (idx = 3073, label = "xf_5090_5200_5201_5_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][256] = (idx = 1441, label = "xf_1104_to_1164_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][257] = (idx = 60, label = "line_1112_to_1152_1_cp", type = "branch")
    data["branch_contingencies"][258] = (idx = 766, label = "line_3177_to_3473_1_cp", type = "branch")
    data["branch_contingencies"][259] = (idx = 2855, label = "xf_2162_2271_2315_5_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][260] = (idx = 2794, label = "xf_1148_1075_1076_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][261] = (idx = 587, label = "line_2256_to_2257_1_cp", type = "branch")
    data["branch_contingencies"][262] = (idx = 3003, label = "xf_4038_4034_4033_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][263] = (idx = 851, label = "line_3312_to_3313_1_cp_merged_with_xf_3313_to_3316_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][264] = (idx = 153, label = "line_1183_to_1380_1_cp", type = "branch")
    data["branch_contingencies"][265] = (idx = 464, label = "line_2109_to_2154_1_cp", type = "branch")
    data["branch_contingencies"][266] = (idx = 159, label = "line_1186_to_1231_1_cp_merged_with_line_1231_to_1391_1_cp", type = "branch")
    data["branch_contingencies"][267] = (idx = 394, label = "line_1396_to_1456_1_cp", type = "branch")
    data["branch_contingencies"][268] = (idx = 773, label = "line_3190_to_3209_1_cp", type = "branch")
    data["branch_contingencies"][269] = (idx = 3075, label = "xf_5090_5200_5201_6_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][270] = (idx = 749, label = "line_3161_to_3483_1_cp", type = "branch")
    data["branch_contingencies"][271] = (idx = 300, label = "line_1275_to_1604_1_cp", type = "branch")
    data["branch_contingencies"][272] = (idx = 1216, label = "line_4344_to_4382_1_cp", type = "branch")
    data["branch_contingencies"][273] = (idx = 2997, label = "xf_4031_4028_4027_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][274] = (idx = 2002, label = "xf_3078_to_3642_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][275] = (idx = 1270, label = "line_5090_to_5112_1_cp", type = "branch")
    data["branch_contingencies"][276] = (idx = 460, label = "line_2106_to_2129_1_cp", type = "branch")
    data["branch_contingencies"][277] = (idx = 2635, label = "xf_5075_to_5194_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][278] = (idx = 2768, label = "xf_1106_1167_1536_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][279] = (idx = 2850, label = "xf_2145_2243_2306_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][280] = (idx = 692, label = "line_3096_to_3209_3_cp", type = "branch")
    data["branch_contingencies"][281] = (idx = 2978, label = "xf_3486_3561_3489_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][282] = (idx = 1972, label = "xf_3039_to_3041_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][283] = (idx = 1380, label = "Dec12_line_4135_to_4136_1_dec", type = "branch")
    data["branch_contingencies"][284] = (idx = 892, label = "line_3412_to_3503_2_cp", type = "branch")
    data["branch_contingencies"][285] = (idx = 628, label = "line_3039_to_3060_1_cp", type = "branch")
    data["branch_contingencies"][286] = (idx = 748, label = "line_3161_to_3285_1_cp", type = "branch")
    data["branch_contingencies"][287] = (idx = 344, label = "line_1333_to_1483_1_cp", type = "branch")
    data["branch_contingencies"][288] = (idx = 2835, label = "xf_1617_1027_1619_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][289] = (idx = 639, label = "line_3058_to_3371_1_cp", type = "branch")
    data["branch_contingencies"][290] = (idx = 320, label = "line_1298_to_1347_2_cp_merged_with_line_1027_to_1298_2_cp", type = "branch")
    data["branch_contingencies"][291] = (idx = 1187, label = "line_4301_to_4302_1_cp", type = "branch")
    data["branch_contingencies"][292] = (idx = 1341, label = "line_1287_to_1496_1_pi", type = "branch")
    data["branch_contingencies"][293] = (idx = 765, label = "line_3174_to_3542_1_cp", type = "branch")
    data["branch_contingencies"][294] = (idx = 662, label = "line_3068_to_3096_1_cp", type = "branch")
    data["branch_contingencies"][295] = (idx = 659, label = "line_3065_to_3167_1_cp", type = "branch")
    data["branch_contingencies"][296] = (idx = 2061, label = "xf_3185_to_3186_2_2winding_transformer_merged_with_line_3185_to_3263_2_cp", type = "branch")
    data["branch_contingencies"][297] = (idx = 783, label = "line_3203_to_3496_3_cp", type = "branch")
    data["branch_contingencies"][298] = (idx = 1365, label = "line_3119_to_3120_1_pi_merged_with_xf_3119_to_3447_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][299] = (idx = 164, label = "line_1189_to_1215_1_cp", type = "branch")
    data["branch_contingencies"][300] = (idx = 1378, label = "Dec10_line_4129_to_4147_1_dec", type = "branch")
    data["branch_contingencies"][301] = (idx = 1230, label = "line_5059_to_5061_1_cp", type = "branch")
    data["branch_contingencies"][302] = (idx = 1161, label = "line_4266_to_4272_1_cp", type = "branch")
    data["branch_contingencies"][303] = (idx = 1096, label = "line_4190_to_4196_1_cp", type = "branch")
    data["branch_contingencies"][304] = (idx = 1182, label = "line_4298_to_4315_1_cp", type = "branch")
    data["branch_contingencies"][305] = (idx = 808, label = "line_3231_to_3534_1_cp", type = "branch")
    data["branch_contingencies"][306] = (idx = 373, label = "line_1361_to_1450_1_cp", type = "branch")
    data["branch_contingencies"][307] = (idx = 466, label = "line_2113_to_2181_2_cp", type = "branch")
    data["branch_contingencies"][308] = (idx = 2844, label = "xf_2077_2205_2349_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][309] = (idx = 375, label = "line_1363_to_1473_1_cp", type = "branch")
    data["branch_contingencies"][310] = (idx = 2982, label = "xf_3492_3565_3494_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][311] = (idx = 1040, label = "line_4107_to_4116_1_cp", type = "branch")
    data["branch_contingencies"][312] = (idx = 42, label = "line_1103_to_1154_1_cp", type = "branch")
    data["branch_contingencies"][313] = (idx = 3000, label = "xf_4031_4030_4029_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][314] = (idx = 2935, label = "xf_3358_3360_3361_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][315] = (idx = 314, label = "line_1289_to_1461_1_cp", type = "branch")
    data["branch_contingencies"][316] = (idx = 1338, label = "line_1194_to_1496_1_pi_merged_with_line_1194_to_1195_1_pi", type = "branch")
    data["branch_contingencies"][317] = (idx = 756, label = "line_3167_to_3492_1_cp", type = "branch")
    data["branch_contingencies"][318] = (idx = 330, label = "line_1312_to_1385_1_cp", type = "branch")
    data["branch_contingencies"][319] = (idx = 1352, label = "line_1599_to_1651_1_pi", type = "branch")
    data["branch_contingencies"][320] = (idx = 2801, label = "xf_1273_1572_1573_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][321] = (idx = 1116, label = "line_4216_to_4224_1_cp", type = "branch")
    data["branch_contingencies"][322] = (idx = 1215, label = "line_4343_to_4344_1_cp", type = "branch")
    data["branch_contingencies"][323] = (idx = 144, label = "line_1182_to_1396_1_cp", type = "branch")
    data["branch_contingencies"][324] = (idx = 3032, label = "xf_4166_4356_4491_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][325] = (idx = 1107, label = "line_4208_to_4209_1_cp", type = "branch")
    data["branch_contingencies"][326] = (idx = 603, label = "line_3014_to_3491_1_cp", type = "branch")
    data["branch_contingencies"][327] = (idx = 710, label = "line_3116_to_3542_1_cp", type = "branch")
    data["branch_contingencies"][328] = (idx = 1, label = "line_1027_to_1299_1_cp", type = "branch")
    data["branch_contingencies"][329] = (idx = 788, label = "line_3211_to_3643_1_cp", type = "branch")
    data["branch_contingencies"][330] = (idx = 774, label = "line_3192_to_3231_1_cp", type = "branch")
    data["branch_contingencies"][331] = (idx = 491, label = "line_2129_to_2162_1_cp", type = "branch")
    data["branch_contingencies"][332] = (idx = 1377, label = "line_4364_to_4365_1_pi", type = "branch")
    data["branch_contingencies"][333] = (idx = 227, label = "line_1206_to_1481_1_cp", type = "branch")
    data["branch_contingencies"][334] = (idx = 1935, label = "xf_2306_to_2341_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][335] = (idx = 297, label = "line_1273_to_1419_1_cp", type = "branch")
    data["branch_contingencies"][336] = (idx = 1282, label = "line_5100_to_5110_1_cp_merged_with_xf_5110_to_5213_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][337] = (idx = 372, label = "line_1360_to_1593_1_cp", type = "branch")
    data["branch_contingencies"][338] = (idx = 19, label = "line_1095_to_1143_1_cp", type = "branch")
    data["branch_contingencies"][339] = (idx = 582, label = "line_2251_to_2256_1_cp", type = "branch")
    data["branch_contingencies"][340] = (idx = 868, label = "line_3369_to_3382_1_cp", type = "branch")
    data["branch_contingencies"][341] = (idx = 81, label = "line_1124_to_1149_1_cp", type = "branch")
    data["branch_contingencies"][342] = (idx = 2988, label = "xf_3516_3584_3517_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][343] = (idx = 1210, label = "line_4319_to_4324_1_cp", type = "branch")
    data["branch_contingencies"][344] = (idx = 2186, label = "xf_3503_to_3570_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][345] = (idx = 2967, label = "xf_3483_3558_3484_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][346] = (idx = 499, label = "line_2147_to_2180_1_cp", type = "branch")
    data["branch_contingencies"][347] = (idx = 182, label = "line_1192_to_1322_1_cp", type = "branch")
    data["branch_contingencies"][348] = (idx = 1199, label = "line_4311_to_4318_1_cp", type = "branch")
    data["branch_contingencies"][349] = (idx = 1083, label = "line_4176_to_4184_1_cp", type = "branch")
    data["branch_contingencies"][350] = (idx = 636, label = "line_3056_to_3342_1_cp", type = "branch")
    data["branch_contingencies"][351] = (idx = 3035, label = "xf_4166_4356_4492_4_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][352] = (idx = 1149, label = "line_4255_to_4292_1_cp", type = "branch")
    data["branch_contingencies"][353] = (idx = 157, label = "line_1185_to_1188_3_cp", type = "branch")
    data["branch_contingencies"][354] = (idx = 1271, label = "line_5091_to_5092_1_cp", type = "branch")
    data["branch_contingencies"][355] = (idx = 1158, label = "line_4264_to_4268_1_cp", type = "branch")
    data["branch_contingencies"][356] = (idx = 3014, label = "xf_4104_4041_4042_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][357] = (idx = 2900, label = "xf_3177_3179_3178_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][358] = (idx = 2836, label = "xf_2077_2205_2346_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][359] = (idx = 2899, label = "xf_3177_3179_3178_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][360] = (idx = 1178, label = "line_4281_to_4297_1_cp", type = "branch")
    data["branch_contingencies"][361] = (idx = 106, label = "line_1148_to_1158_1_cp", type = "branch")
    data["branch_contingencies"][362] = (idx = 3034, label = "xf_4166_4356_4492_4_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][363] = (idx = 2582, label = "xf_4356_to_4006_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][364] = (idx = 2755, label = "xf_1092_1093_1526_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][365] = (idx = 443, label = "line_1598_to_1601_1_cp", type = "branch")
    data["branch_contingencies"][366] = (idx = 1151, label = "line_4257_to_4258_1_cp", type = "branch")
    data["branch_contingencies"][367] = (idx = 2113, label = "xf_3337_to_3339_1_2winding_transformer_merged_with_line_3337_to_3471_1_cp", type = "branch")
    data["branch_contingencies"][368] = (idx = 3020, label = "xf_4104_4045_4046_4_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][369] = (idx = 3069, label = "xf_5088_5175_5241_4_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][370] = (idx = 311, label = "line_1289_to_1387_2_cp", type = "branch")
    data["branch_contingencies"][371] = (idx = 1350, label = "line_1597_to_1600_1_pi", type = "branch")
    data["branch_contingencies"][372] = (idx = 461, label = "line_2106_to_2177_1_cp", type = "branch")
    data["branch_contingencies"][373] = (idx = 1800, label = "xf_2142_to_2034_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][374] = (idx = 71, label = "line_1118_to_1158_1_cp", type = "branch")
    data["branch_contingencies"][375] = (idx = 1339, label = "line_1234_to_1493_1_pi_merged_with_xf_1493_to_1647_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][376] = (idx = 266, label = "line_1236_to_1491_1_cp", type = "branch")
    data["branch_contingencies"][377] = (idx = 6, label = "line_1061_to_1274_1_cp", type = "branch")
    data["branch_contingencies"][378] = (idx = 2104, label = "xf_3315_to_3316_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][379] = (idx = 920, label = "line_3543_to_3547_1_cp", type = "branch")
    data["branch_contingencies"][380] = (idx = 473, label = "line_2118_to_2185_1_cp_merged_with_line_2173_to_2185_1_cp_merged_with_line_2173_to_2188_1_cp", type = "branch")
    data["branch_contingencies"][381] = (idx = 2391, label = "xf_4201_to_4146_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][382] = (idx = 607, label = "line_3017_to_3636_2_cp", type = "branch")
    data["branch_contingencies"][383] = (idx = 337, label = "line_1321_to_1627_1_cp", type = "branch")
    data["branch_contingencies"][384] = (idx = 2652, label = "xf_5092_to_5225_2A_2winding_transformer", type = "branch")
    data["branch_contingencies"][385] = (idx = 1028, label = "line_4091_to_4307_1_cp", type = "branch")
    data["branch_contingencies"][386] = (idx = 455, label = "line_2105_to_2109_1_cp", type = "branch")
    data["branch_contingencies"][387] = (idx = 1118, label = "line_4218_to_4219_1_cp", type = "branch")
    data["branch_contingencies"][388] = (idx = 947, label = "line_3557_to_3569_1_cp", type = "branch")
    data["branch_contingencies"][389] = (idx = 515, label = "line_2164_to_2168_1_cp", type = "branch")
    data["branch_contingencies"][390] = (idx = 1477, label = "xf_1124_to_1047_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][391] = (idx = 914, label = "line_3519_to_3534_1_cp", type = "branch")
    data["branch_contingencies"][392] = (idx = 1126, label = "line_4235_to_4337_1_cp", type = "branch")
    data["branch_contingencies"][393] = (idx = 1255, label = "line_5081_to_5116_1_cp", type = "branch")
    data["branch_contingencies"][394] = (idx = 44, label = "line_1104_to_1116_1_cp", type = "branch")
    data["branch_contingencies"][395] = (idx = 1793, label = "xf_2139_to_2088_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][396] = (idx = 3040, label = "xf_4187_4230_4495_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][397] = (idx = 534, label = "line_2199_to_2206_1_cp", type = "branch")
    data["branch_contingencies"][398] = (idx = 1702, label = "xf_1494_to_1647_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][399] = (idx = 2398, label = "xf_4213_to_4149_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][400] = (idx = 220, label = "line_1205_to_1485_1_cp_merged_with_line_1400_to_1485_1_cp", type = "branch")
    data["branch_contingencies"][401] = (idx = 2169, label = "xf_3477_to_3554_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][402] = (idx = 506, label = "line_2154_to_2176_1_cp", type = "branch")
    data["branch_contingencies"][403] = (idx = 72, label = "line_1118_to_2191_1_cp", type = "branch")
    data["branch_contingencies"][404] = (idx = 407, label = "line_1434_to_1626_1_cp", type = "branch")
    data["branch_contingencies"][405] = (idx = 2810, label = "xf_1296_1504_1506_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][406] = (idx = 945, label = "line_3555_to_3598_1_cp_merged_with_xf_3477_to_3555_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][407] = (idx = 2198, label = "xf_3523_to_3596_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][408] = (idx = 2922, label = "xf_3302_3304_3303_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][409] = (idx = 596, label = "line_3004_to_3005_1_cp", type = "branch")
    data["branch_contingencies"][410] = (idx = 1084, label = "line_4176_to_4191_1_cp", type = "branch")
    data["branch_contingencies"][411] = (idx = 2904, label = "xf_3226_3227_3228_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][412] = (idx = 635, label = "line_3054_to_3060_1_cp", type = "branch")
    data["branch_contingencies"][413] = (idx = 703, label = "line_3108_to_3243_2_cp", type = "branch")
    data["branch_contingencies"][414] = (idx = 1976, label = "xf_3045_to_3046_2_2winding_transformer_merged_with_line_3045_to_3482_1_cp", type = "branch")
    data["branch_contingencies"][415] = (idx = 1272, label = "line_5091_to_5093_1_cp_merged_with_xf_5093_5202_5203_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][416] = (idx = 12, label = "line_1091_to_1149_1_cp", type = "branch")
    data["branch_contingencies"][417] = (idx = 357, label = "line_1346_to_1443_1_cp", type = "branch")
    data["branch_contingencies"][418] = (idx = 2056, label = "xf_3172_to_3657_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][419] = (idx = 1157, label = "line_4264_to_4265_1_cp", type = "branch")
    data["branch_contingencies"][420] = (idx = 2038, label = "xf_3137_to_3138_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][421] = (idx = 610, label = "line_3018_to_3636_1_cp", type = "branch")
    data["branch_contingencies"][422] = (idx = 1317, label = "line_5149_to_5169_1_cp", type = "branch")
    data["branch_contingencies"][423] = (idx = 993, label = "line_3584_to_3596_1_cp", type = "branch")
    data["branch_contingencies"][424] = (idx = 2210, label = "xf_3536_to_3127_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][425] = (idx = 911, label = "line_3496_to_3623_1_cp", type = "branch")
    data["branch_contingencies"][426] = (idx = 2933, label = "xf_3333_3336_3335_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][427] = (idx = 436, label = "line_1594_to_1601_1_cp", type = "branch")
    data["branch_contingencies"][428] = (idx = 573, label = "line_2235_to_2257_1_cp", type = "branch")
    data["branch_contingencies"][429] = (idx = 1387, label = "Dec19_line_4226_to_4327_1_dec", type = "branch")
    data["branch_contingencies"][430] = (idx = 999, label = "line_3593_to_3610_1_cp", type = "branch")
    data["branch_contingencies"][431] = (idx = 719, label = "line_3131_to_3519_1_cp", type = "branch")
    data["branch_contingencies"][432] = (idx = 544, label = "line_2203_to_2204_1_cp", type = "branch")
    data["branch_contingencies"][433] = (idx = 652, label = "line_3063_to_3165_1_cp", type = "branch")
    data["branch_contingencies"][434] = (idx = 231, label = "line_1208_to_1293_1_cp", type = "branch")
    data["branch_contingencies"][435] = (idx = 1839, label = "xf_2168_to_2321_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][436] = (idx = 1374, label = "line_4123_to_4239_1_pi", type = "branch")
    data["branch_contingencies"][437] = (idx = 3061, label = "xf_4257_4379_4434_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][438] = (idx = 720, label = "line_3131_to_3534_1_cp", type = "branch")
    data["branch_contingencies"][439] = (idx = 108, label = "line_1155_to_1157_1_cp", type = "branch")
    data["branch_contingencies"][440] = (idx = 46, label = "line_1105_to_1119_1_cp", type = "branch")
    data["branch_contingencies"][441] = (idx = 2834, label = "xf_1617_1027_1619_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][442] = (idx = 454, label = "line_2105_to_2108_1_cp", type = "branch")
    data["branch_contingencies"][443] = (idx = 342, label = "line_1331_to_1402_1_cp", type = "branch")
    data["branch_contingencies"][444] = (idx = 1331, label = "line_5167_to_5169_1_cp_merged_with_xf_5167_to_5042_6_2winding_transformer", type = "branch")
    data["branch_contingencies"][445] = (idx = 334, label = "line_1317_to_1497_1_cp", type = "branch")
    data["branch_contingencies"][446] = (idx = 849, label = "line_3310_to_3642_1_cp", type = "branch")
    data["branch_contingencies"][447] = (idx = 2861, label = "xf_2191_2020_2021_7_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][448] = (idx = 2919, label = "xf_3302_3304_3303_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][449] = (idx = 2762, label = "xf_1099_1100_1532_10_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][450] = (idx = 2970, label = "xf_3483_3558_3485_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][451] = (idx = 1348, label = "line_1498_to_1651_1_pi", type = "branch")
    data["branch_contingencies"][452] = (idx = 718, label = "line_3129_to_3467_1_cp", type = "branch")
    data["branch_contingencies"][453] = (idx = 1937, label = "xf_2308_to_2066_5_2winding_transformer_merged_with_line_2308_to_2311_6_cp", type = "branch")
    data["branch_contingencies"][454] = (idx = 1712, label = "xf_1529_to_1610_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][455] = (idx = 2893, label = "xf_3134_3135_3136_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][456] = (idx = 1080, label = "line_4174_to_4183_1_cp", type = "branch")
    data["branch_contingencies"][457] = (idx = 1256, label = "line_5081_to_5223_1_cp", type = "branch")
    data["branch_contingencies"][458] = (idx = 678, label = "line_3080_to_3529_1_cp", type = "branch")
    data["branch_contingencies"][459] = (idx = 1022, label = "line_4002_to_4144_1_cp", type = "branch")
    data["branch_contingencies"][460] = (idx = 2076, label = "xf_3203_to_3206_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][461] = (idx = 2833, label = "xf_1617_1027_1619_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][462] = (idx = 425, label = "line_1519_to_1521_2_cp", type = "branch")
    data["branch_contingencies"][463] = (idx = 78, label = "line_1123_to_1155_1_cp", type = "branch")
    data["branch_contingencies"][464] = (idx = 1177, label = "line_4279_to_4294_1_cp", type = "branch")
    data["branch_contingencies"][465] = (idx = 2822, label = "xf_1430_1502_1543_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][466] = (idx = 52, label = "line_1108_to_1293_1_cp", type = "branch")
    data["branch_contingencies"][467] = (idx = 1059, label = "line_4141_to_4149_1_cp", type = "branch")
    data["branch_contingencies"][468] = (idx = 2106, label = "xf_3321_to_3323_2_2winding_transformer_merged_with_line_3321_to_3504_2_cp", type = "branch")
    data["branch_contingencies"][469] = (idx = 937, label = "line_3547_to_3606_1_cp", type = "branch")
    data["branch_contingencies"][470] = (idx = 2971, label = "xf_3486_3561_3487_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][471] = (idx = 1100, label = "line_4195_to_4196_1_cp", type = "branch")
    data["branch_contingencies"][472] = (idx = 104, label = "line_1144_to_1150_1_cp", type = "branch")
    data["branch_contingencies"][473] = (idx = 1136, label = "line_4243_to_4331_1_cp", type = "branch")
    data["branch_contingencies"][474] = (idx = 2969, label = "xf_3483_3558_3485_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][475] = (idx = 1095, label = "line_4190_to_4193_1_cp", type = "branch")
    data["branch_contingencies"][476] = (idx = 16, label = "line_1093_to_1140_1_cp", type = "branch")
    data["branch_contingencies"][477] = (idx = 1094, label = "line_4189_to_4193_1_cp", type = "branch")
    data["branch_contingencies"][478] = (idx = 1557, label = "xf_1200_to_1516_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][479] = (idx = 128, label = "line_1168_to_1292_1_cp", type = "branch")
    data["branch_contingencies"][480] = (idx = 1194, label = "line_4307_to_4339_1_cp", type = "branch")
    data["branch_contingencies"][481] = (idx = 915, label = "line_3529_to_3643_1_cp", type = "branch")
    data["branch_contingencies"][482] = (idx = 371, label = "line_1360_to_1362_1_cp_merged_with_xf_1362_to_1596_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][483] = (idx = 1236, label = "line_5062_to_5064_1_cp", type = "branch")
    data["branch_contingencies"][484] = (idx = 362, label = "line_1352_to_1486_1_cp", type = "branch")
    data["branch_contingencies"][485] = (idx = 1062, label = "line_4146_to_4149_1_cp", type = "branch")
    data["branch_contingencies"][486] = (idx = 2816, label = "xf_1428_1501_1540_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][487] = (idx = 2966, label = "xf_3483_3558_3484_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][488] = (idx = 2864, label = "xf_2191_2023_2024_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][489] = (idx = 1244, label = "line_5070_to_5072_2_cp", type = "branch")
    data["branch_contingencies"][490] = (idx = 289, label = "line_1261_to_1341_1_cp", type = "branch")
    data["branch_contingencies"][491] = (idx = 2185, label = "xf_3498_to_3568_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][492] = (idx = 926, label = "line_3545_to_3570_2_cp", type = "branch")
    data["branch_contingencies"][493] = (idx = 293, label = "line_1271_to_1440_1_cp", type = "branch")
    data["branch_contingencies"][494] = (idx = 462, label = "line_2108_to_2125_1_cp", type = "branch")
    data["branch_contingencies"][495] = (idx = 1295, label = "line_5116_to_5118_3_cp", type = "branch")
    data["branch_contingencies"][496] = (idx = 3006, label = "xf_4038_4035_4036_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][497] = (idx = 884, label = "line_3401_to_3642_1_cp", type = "branch")
    data["branch_contingencies"][498] = (idx = 2197, label = "xf_3519_to_3595_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][499] = (idx = 693, label = "line_3096_to_3259_1_cp", type = "branch")
    data["branch_contingencies"][500] = (idx = 35, label = "line_1100_to_1133_1_cp", type = "branch")
    data["branch_contingencies"][501] = (idx = 131, label = "line_1169_to_1221_1_cp", type = "branch")
    data["branch_contingencies"][502] = (idx = 691, label = "line_3096_to_3208_1_cp_merged_with_xf_3208_to_3460_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][503] = (idx = 768, label = "line_3182_to_3523_1_cp", type = "branch")
    data["branch_contingencies"][504] = (idx = 1148, label = "line_4254_to_4256_1_cp", type = "branch")
    data["branch_contingencies"][505] = (idx = 1724, label = "xf_1656_to_1087_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][506] = (idx = 1362, label = "line_2303_to_2304_2_pi", type = "branch")
    data["branch_contingencies"][507] = (idx = 482, label = "line_2122_to_2181_1_cp", type = "branch")
    data["branch_contingencies"][508] = (idx = 2986, label = "xf_3516_3584_3517_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][509] = (idx = 422, label = "line_1480_to_1497_1_cp", type = "branch")
    data["branch_contingencies"][510] = (idx = 3045, label = "xf_4220_4074_4498_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][511] = (idx = 255, label = "line_1224_to_1236_1_cp", type = "branch")
    data["branch_contingencies"][512] = (idx = 178, label = "line_1191_to_1253_1_cp", type = "branch")
    data["branch_contingencies"][513] = (idx = 3042, label = "xf_4218_4392_4496_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][514] = (idx = 442, label = "line_1595_to_1598_1_cp", type = "branch")
    data["branch_contingencies"][515] = (idx = 562, label = "line_2218_to_2221_1_cp", type = "branch")
    data["branch_contingencies"][516] = (idx = 654, label = "line_3063_to_3196_1_cp", type = "branch")
    data["branch_contingencies"][517] = (idx = 291, label = "line_1262_to_1336_1_cp", type = "branch")
    data["branch_contingencies"][518] = (idx = 1180, label = "line_4286_to_4311_1_cp", type = "branch")
    data["branch_contingencies"][519] = (idx = 969, label = "line_3564_to_3652_1_cp_merged_with_xf_3490_to_3564_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][520] = (idx = 327, label = "line_1308_to_1480_1_cp", type = "branch")
    data["branch_contingencies"][521] = (idx = 284, label = "line_1258_to_1422_1_cp", type = "branch")
    data["branch_contingencies"][522] = (idx = 3015, label = "xf_4104_4043_4044_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][523] = (idx = 1386, label = "Dec18_line_4226_to_4326_2_dec", type = "branch")
    data["branch_contingencies"][524] = (idx = 15, label = "line_1093_to_1138_1_cp", type = "branch")
    data["branch_contingencies"][525] = (idx = 2879, label = "xf_2195_2293_2332_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][526] = (idx = 566, label = "line_2221_to_2252_1_cp", type = "branch")
    data["branch_contingencies"][527] = (idx = 721, label = "line_3134_to_3340_1_cp", type = "branch")
    data["branch_contingencies"][528] = (idx = 2252, label = "xf_3633_to_3515_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][529] = (idx = 399, label = "line_1402_to_1423_1_cp", type = "branch")
    data["branch_contingencies"][530] = (idx = 245, label = "line_1220_to_1471_1_cp_merged_with_line_1279_to_1282_2_pi_merged_with_line_1279_to_1471_1_cp", type = "branch")
    data["branch_contingencies"][531] = (idx = 268, label = "line_1237_to_1288_1_cp", type = "branch")
    data["branch_contingencies"][532] = (idx = 658, label = "line_3065_to_3165_1_cp", type = "branch")
    data["branch_contingencies"][533] = (idx = 2984, label = "xf_3492_3565_3495_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][534] = (idx = 261, label = "line_1229_to_1249_1_cp", type = "branch")
    data["branch_contingencies"][535] = (idx = 102, label = "line_1140_to_1152_1_cp", type = "branch")
    data["branch_contingencies"][536] = (idx = 2217, label = "xf_3579_to_3428_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][537] = (idx = 282, label = "line_1254_to_1457_1_cp", type = "branch")
    data["branch_contingencies"][538] = (idx = 38, label = "line_1102_to_1103_1_cp", type = "branch")
    data["branch_contingencies"][539] = (idx = 845, label = "line_3306_to_3397_1_cp", type = "branch")
    data["branch_contingencies"][540] = (idx = 1165, label = "line_4266_to_4292_2_cp", type = "branch")
    data["branch_contingencies"][541] = (idx = 2885, label = "xf_2200_2196_2304_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][542] = (idx = 1408, label = "xf_1009_to_1606_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][543] = (idx = 115, label = "line_1164_to_1335_1_cp", type = "branch")
    data["branch_contingencies"][544] = (idx = 351, label = "line_1340_to_1393_1_cp", type = "branch")
    data["branch_contingencies"][545] = (idx = 370, label = "line_1358_to_1593_1_cp", type = "branch")
    data["branch_contingencies"][546] = (idx = 279, label = "line_1247_to_1249_1_cp", type = "branch")
    data["branch_contingencies"][547] = (idx = 801, label = "line_3223_to_3529_1_cp", type = "branch")
    data["branch_contingencies"][548] = (idx = 1133, label = "line_4241_to_4248_1_cp", type = "branch")
    data["branch_contingencies"][549] = (idx = 853, label = "line_3314_to_3315_2_cp", type = "branch")
    data["branch_contingencies"][550] = (idx = 2360, label = "xf_4174_to_4116_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][551] = (idx = 1129, label = "line_4236_to_4337_1_cp", type = "branch")
    data["branch_contingencies"][552] = (idx = 608, label = "line_3018_to_3019_1_cp", type = "branch")
    data["branch_contingencies"][553] = (idx = 1472, label = "xf_1120_to_1178_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][554] = (idx = 2804, label = "xf_1273_1572_1573_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][555] = (idx = 1623, label = "xf_1333_to_1513_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][556] = (idx = 1716, label = "xf_1569_to_1541_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][557] = (idx = 1152, label = "line_4257_to_4259_1_cp", type = "branch")
    data["branch_contingencies"][558] = (idx = 1213, label = "line_4321_to_4338_1_cp", type = "branch")
    data["branch_contingencies"][559] = (idx = 2890, label = "xf_3134_3135_3136_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][560] = (idx = 2052, label = "xf_3158_to_3648_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][561] = (idx = 1150, label = "line_4256_to_4264_1_cp", type = "branch")
    data["branch_contingencies"][562] = (idx = 817, label = "line_3259_to_3518_1_cp", type = "branch")
    data["branch_contingencies"][563] = (idx = 1087, label = "line_4178_to_4179_1_cp", type = "branch")
    data["branch_contingencies"][564] = (idx = 258, label = "line_1226_to_1256_1_cp", type = "branch")
    data["branch_contingencies"][565] = (idx = 2951, label = "xf_3371_3372_3373_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][566] = (idx = 666, label = "line_3072_to_3116_1_cp", type = "branch")
    data["branch_contingencies"][567] = (idx = 2279, label = "xf_4038_to_4037_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][568] = (idx = 143, label = "line_1179_to_1429_1_cp", type = "branch")
    data["branch_contingencies"][569] = (idx = 1086, label = "line_4177_to_4184_1_cp", type = "branch")
    data["branch_contingencies"][570] = (idx = 1740, label = "xf_2084_to_2085_2_2winding_transformer_merged_with_line_2084_to_2164_2_pi", type = "branch")
    data["branch_contingencies"][571] = (idx = 318, label = "line_1296_to_1310_1_cp", type = "branch")
    data["branch_contingencies"][572] = (idx = 2600, label = "xf_5048_to_5046_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][573] = (idx = 2853, label = "xf_2145_2243_2306_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][574] = (idx = 3063, label = "xf_4257_4379_4434_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][575] = (idx = 1217, label = "line_4364_to_4366_2_cp", type = "branch")
    data["branch_contingencies"][576] = (idx = 423, label = "line_1486_to_1604_1_cp", type = "branch")
    data["branch_contingencies"][577] = (idx = 863, label = "line_3350_to_3354_1_cp_merged_with_xf_3350_to_3351_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][578] = (idx = 2796, label = "xf_1148_1077_1078_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][579] = (idx = 2980, label = "xf_3492_3565_3494_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][580] = (idx = 617, label = "line_3023_to_3195_1_cp", type = "branch")
    data["branch_contingencies"][581] = (idx = 1294, label = "line_5115_to_5118_5_cp_merged_with_xf_5038_to_5115_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][582] = (idx = 263, label = "line_1230_to_1403_1_cp", type = "branch")
    data["branch_contingencies"][583] = (idx = 181, label = "line_1191_to_1401_1_cp", type = "branch")
    data["branch_contingencies"][584] = (idx = 2830, label = "xf_1616_1027_1618_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][585] = (idx = 2419, label = "xf_4224_to_4073_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][586] = (idx = 1391, label = "Dec22_line_4275_to_4289_1_dec", type = "branch")
    data["branch_contingencies"][587] = (idx = 642, label = "line_3060_to_3151_1_cp", type = "branch")
    data["branch_contingencies"][588] = (idx = 589, label = "line_2259_to_2262_3_cp_merged_with_xf_2259_to_2066_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][589] = (idx = 75, label = "line_1121_to_1156_1_cp", type = "branch")
    data["branch_contingencies"][590] = (idx = 1936, label = "xf_2307_to_2065_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][591] = (idx = 669, label = "line_3073_to_3479_2_cp", type = "branch")
    data["branch_contingencies"][592] = (idx = 537, label = "line_2200_to_2204_1_cp", type = "branch")
    data["branch_contingencies"][593] = (idx = 2595, label = "xf_4399_to_4344_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][594] = (idx = 208, label = "line_1200_to_1429_1_cp", type = "branch")
    data["branch_contingencies"][595] = (idx = 855, label = "line_3324_to_3473_2_cp", type = "branch")
    data["branch_contingencies"][596] = (idx = 2937, label = "xf_3358_3360_3361_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][597] = (idx = 1257, label = "line_5082_to_5116_2_cp_merged_with_line_5082_to_5223_2_cp", type = "branch")
    data["branch_contingencies"][598] = (idx = 3048, label = "xf_4220_4074_4499_5_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][599] = (idx = 113, label = "line_1160_to_1334_1_cp_merged_with_xf_1159_to_1160_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][600] = (idx = 555, label = "line_2211_to_2221_1_cp", type = "branch")
    data["branch_contingencies"][601] = (idx = 2842, label = "xf_2077_2205_2349_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][602] = (idx = 345, label = "line_1334_to_1392_1_cp", type = "branch")
    data["branch_contingencies"][603] = (idx = 312, label = "line_1289_to_1388_1_cp", type = "branch")
    data["branch_contingencies"][604] = (idx = 567, label = "line_2221_to_2294_1_cp", type = "branch")
    data["branch_contingencies"][605] = (idx = 621, label = "line_3024_to_3498_2_cp", type = "branch")
    data["branch_contingencies"][606] = (idx = 1739, label = "xf_2083_to_2086_1_2winding_transformer_merged_with_line_2083_to_2163_1_pi", type = "branch")
    data["branch_contingencies"][607] = (idx = 109, label = "line_1159_to_1312_1_cp", type = "branch")
    data["branch_contingencies"][608] = (idx = 1119, label = "line_4219_to_4220_1_cp", type = "branch")
    data["branch_contingencies"][609] = (idx = 217, label = "line_1205_to_1263_1_cp", type = "branch")
    data["branch_contingencies"][610] = (idx = 2962, label = "xf_3413_3415_3414_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][611] = (idx = 2040, label = "xf_3140_to_3142_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][612] = (idx = 760, label = "line_3172_to_3247_1_cp", type = "branch")
    data["branch_contingencies"][613] = (idx = 2940, label = "xf_3359_3360_3361_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][614] = (idx = 1385, label = "Dec17_line_4226_to_4292_2_dec", type = "branch")
    data["branch_contingencies"][615] = (idx = 1061, label = "line_4145_to_4146_1_cp", type = "branch")
    data["branch_contingencies"][616] = (idx = 2898, label = "xf_3177_3179_3178_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][617] = (idx = 205, label = "line_1199_to_1497_1_cp", type = "branch")
    data["branch_contingencies"][618] = (idx = 2894, label = "xf_3134_3135_3136_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][619] = (idx = 1030, label = "line_4102_to_4152_1_cp", type = "branch")
    data["branch_contingencies"][620] = (idx = 1173, label = "line_4278_to_4295_1_cp", type = "branch")
    data["branch_contingencies"][621] = (idx = 2930, label = "xf_3333_3336_3335_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][622] = (idx = 2410, label = "xf_4220_to_4074_6_2winding_transformer", type = "branch")
    data["branch_contingencies"][623] = (idx = 397, label = "line_1400_to_1429_1_cp", type = "branch")
    data["branch_contingencies"][624] = (idx = 329, label = "line_1310_to_1433_1_cp", type = "branch")
    data["branch_contingencies"][625] = (idx = 246, label = "line_1221_to_1272_1_cp", type = "branch")
    data["branch_contingencies"][626] = (idx = 880, label = "line_3391_to_3534_1_cp_merged_with_xf_3391_to_3392_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][627] = (idx = 565, label = "line_2221_to_2225_1_cp", type = "branch")
    data["branch_contingencies"][628] = (idx = 1392, label = "Dec23_line_4276_to_4279_1_dec", type = "branch")
    data["branch_contingencies"][629] = (idx = 3064, label = "xf_4257_4379_4434_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][630] = (idx = 800, label = "line_3222_to_3623_1_cp", type = "branch")
    data["branch_contingencies"][631] = (idx = 733, label = "line_3143_to_3523_2_cp", type = "branch")
    data["branch_contingencies"][632] = (idx = 2670, label = "xf_5111_to_5213_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][633] = (idx = 1622, label = "xf_1332_to_1513_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][634] = (idx = 163, label = "line_1187_to_1468_1_cp", type = "branch")
    data["branch_contingencies"][635] = (idx = 281, label = "line_1254_to_1371_1_cp", type = "branch")
    data["branch_contingencies"][636] = (idx = 847, label = "line_3307_to_3397_2_cp", type = "branch")
    data["branch_contingencies"][637] = (idx = 730, label = "line_3142_to_3270_1_cp", type = "branch")
    data["branch_contingencies"][638] = (idx = 2920, label = "xf_3302_3304_3303_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][639] = (idx = 888, label = "line_3411_to_3471_1_cp", type = "branch")
    data["branch_contingencies"][640] = (idx = 412, label = "line_1438_to_1488_1_cp", type = "branch")
    data["branch_contingencies"][641] = (idx = 479, label = "line_2120_to_2169_1_cp", type = "branch")
    data["branch_contingencies"][642] = (idx = 352, label = "line_1340_to_1478_1_cp", type = "branch")
    data["branch_contingencies"][643] = (idx = 1287, label = "line_5104_to_5106_1_cp", type = "branch")
    data["branch_contingencies"][644] = (idx = 2183, label = "xf_3496_to_3567_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][645] = (idx = 2968, label = "xf_3483_3558_3485_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][646] = (idx = 1123, label = "line_4231_to_4275_1_cp", type = "branch")
    data["branch_contingencies"][647] = (idx = 3019, label = "xf_4104_4045_4046_4_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][648] = (idx = 271, label = "line_1239_to_1424_1_cp", type = "branch")
    data["branch_contingencies"][649] = (idx = 604, label = "line_3015_to_3491_2_cp_merged_with_xf_3015_to_3016_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][650] = (idx = 3041, label = "xf_4218_4392_4496_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][651] = (idx = 336, label = "line_1321_to_1370_1_cp", type = "branch")
    data["branch_contingencies"][652] = (idx = 1164, label = "line_4266_to_4275_1_cp", type = "branch")
    data["branch_contingencies"][653] = (idx = 1195, label = "line_4308_to_4319_1_cp", type = "branch")
    data["branch_contingencies"][654] = (idx = 2753, label = "xf_1092_1093_1526_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][655] = (idx = 332, label = "line_1313_to_1458_1_cp", type = "branch")
    data["branch_contingencies"][656] = (idx = 2078, label = "xf_3205_to_3206_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][657] = (idx = 24, label = "line_1096_to_1120_1_cp", type = "branch")
    data["branch_contingencies"][658] = (idx = 160, label = "line_1186_to_1233_2_cp_merged_with_line_1233_to_1326_1_cp", type = "branch")
    data["branch_contingencies"][659] = (idx = 891, label = "line_3412_to_3471_2_cp", type = "branch")
    data["branch_contingencies"][660] = (idx = 253, label = "line_1222_to_2162_1_cp", type = "branch")
    data["branch_contingencies"][661] = (idx = 3056, label = "xf_4257_4379_4434_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][662] = (idx = 137, label = "line_1172_to_1249_1_cp", type = "branch")
    data["branch_contingencies"][663] = (idx = 2128, label = "xf_3378_to_3380_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][664] = (idx = 2929, label = "xf_3333_3336_3335_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][665] = (idx = 2321, label = "xf_4133_to_4292_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][666] = (idx = 1121, label = "line_4229_to_4230_3_cp", type = "branch")
    data["branch_contingencies"][667] = (idx = 96, label = "line_1136_to_2139_1_cp", type = "branch")
    data["branch_contingencies"][668] = (idx = 673, label = "line_3077_to_3643_1_cp", type = "branch")
    data["branch_contingencies"][669] = (idx = 925, label = "line_3543_to_3593_1_cp", type = "branch")
    data["branch_contingencies"][670] = (idx = 2824, label = "xf_1430_1502_1543_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][671] = (idx = 2987, label = "xf_3516_3584_3517_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][672] = (idx = 1974, label = "xf_3039_to_3043_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][673] = (idx = 2868, label = "xf_2191_2025_2026_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][674] = (idx = 2407, label = "xf_4218_to_4392_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][675] = (idx = 2847, label = "xf_2145_2243_2306_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][676] = (idx = 1169, label = "line_4272_to_4275_1_cp", type = "branch")
    data["branch_contingencies"][677] = (idx = 303, label = "line_1281_to_1469_2_cp", type = "branch")
    data["branch_contingencies"][678] = (idx = 3058, label = "xf_4257_4379_4434_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][679] = (idx = 2896, label = "xf_3177_3179_3178_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][680] = (idx = 2812, label = "xf_1296_1504_1506_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][681] = (idx = 1864, label = "xf_2182_to_2290_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][682] = (idx = 2958, label = "xf_3379_3380_3381_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][683] = (idx = 2845, label = "xf_2145_2243_2306_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][684] = (idx = 1613, label = "xf_1318_to_1057_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][685] = (idx = 3077, label = "xf_5093_5202_5203_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][686] = (idx = 219, label = "line_1205_to_1433_1_cp", type = "branch")
    data["branch_contingencies"][687] = (idx = 1212, label = "line_4321_to_4323_1_cp", type = "branch")
    data["branch_contingencies"][688] = (idx = 1049, label = "line_4124_to_4135_1_cp", type = "branch")
    data["branch_contingencies"][689] = (idx = 1267, label = "line_5090_to_5092_1_cp", type = "branch")
    data["branch_contingencies"][690] = (idx = 200, label = "line_1199_to_1479_1_cp", type = "branch")
    data["branch_contingencies"][691] = (idx = 273, label = "line_1240_to_1413_1_cp", type = "branch")
    data["branch_contingencies"][692] = (idx = 2938, label = "xf_3359_3360_3361_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][693] = (idx = 1135, label = "line_4243_to_4249_1_cp", type = "branch")
    data["branch_contingencies"][694] = (idx = 846, label = "line_3306_to_3441_1_cp", type = "branch")
    data["branch_contingencies"][695] = (idx = 356, label = "line_1344_to_1373_2_cp", type = "branch")
    data["branch_contingencies"][696] = (idx = 215, label = "line_1204_to_1475_1_cp", type = "branch")
    data["branch_contingencies"][697] = (idx = 424, label = "line_1519_to_1520_1_cp_merged_with_xf_1520_to_1001_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][698] = (idx = 90, label = "line_1132_to_1149_1_cp", type = "branch")
    data["branch_contingencies"][699] = (idx = 707, label = "line_3111_to_3196_1_cp", type = "branch")
    data["branch_contingencies"][700] = (idx = 2184, label = "xf_3497_to_3568_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][701] = (idx = 1089, label = "line_4180_to_4184_1_cp", type = "branch")
    data["branch_contingencies"][702] = (idx = 657, label = "line_3063_to_3285_1_cp", type = "branch")
    data["branch_contingencies"][703] = (idx = 1227, label = "line_5058_to_5063_1_cp", type = "branch")
    data["branch_contingencies"][704] = (idx = 98, label = "line_1138_to_1147_1_cp", type = "branch")
    data["branch_contingencies"][705] = (idx = 2911, label = "xf_3231_3644_3645_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][706] = (idx = 136, label = "line_1172_to_1247_1_cp", type = "branch")
    data["branch_contingencies"][707] = (idx = 848, label = "line_3307_to_3441_2_cp", type = "branch")
    data["branch_contingencies"][708] = (idx = 148, label = "line_1183_to_1262_1_cp", type = "branch")
    data["branch_contingencies"][709] = (idx = 1108, label = "line_4209_to_4210_1_cp", type = "branch")
    data["branch_contingencies"][710] = (idx = 929, label = "line_3545_to_3589_1_cp", type = "branch")
    data["branch_contingencies"][711] = (idx = 551, label = "line_2210_to_2217_1_cp", type = "branch")
    data["branch_contingencies"][712] = (idx = 1229, label = "line_5059_to_5060_1_cp", type = "branch")
    data["branch_contingencies"][713] = (idx = 1811, label = "xf_2150_to_2048_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][714] = (idx = 2199, label = "xf_3523_to_3597_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][715] = (idx = 374, label = "line_1363_to_1444_1_cp", type = "branch")
    data["branch_contingencies"][716] = (idx = 2336, label = "xf_4145_to_4329_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][717] = (idx = 2840, label = "xf_2077_2205_2347_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][718] = (idx = 82, label = "line_1125_to_1158_1_cp", type = "branch")
    data["branch_contingencies"][719] = (idx = 2129, label = "xf_3378_to_3381_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][720] = (idx = 726, label = "line_3140_to_3486_2_cp", type = "branch")
    data["branch_contingencies"][721] = (idx = 2814, label = "xf_1428_1501_1539_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][722] = (idx = 22, label = "line_1096_to_1105_1_cp", type = "branch")
    data["branch_contingencies"][723] = (idx = 383, label = "line_1375_to_1433_1_cp", type = "branch")
    data["branch_contingencies"][724] = (idx = 861, label = "line_3340_to_3635_1_cp", type = "branch")
    data["branch_contingencies"][725] = (idx = 875, label = "line_3378_to_3504_2_cp", type = "branch")
    data["branch_contingencies"][726] = (idx = 860, label = "line_3338_to_3471_2_cp", type = "branch")
    data["branch_contingencies"][727] = (idx = 1088, label = "line_4179_to_4180_1_cp", type = "branch")
    data["branch_contingencies"][728] = (idx = 2813, label = "xf_1428_1501_1539_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][729] = (idx = 767, label = "line_3177_to_3633_1_cp", type = "branch")
    data["branch_contingencies"][730] = (idx = 36, label = "line_1100_to_1144_1_cp", type = "branch")
    data["branch_contingencies"][731] = (idx = 403, label = "line_1414_to_1479_1_cp", type = "branch")
    data["branch_contingencies"][732] = (idx = 270, label = "line_1239_to_1394_1_cp", type = "branch")
    data["branch_contingencies"][733] = (idx = 2783, label = "xf_1121_1123_1634_6_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][734] = (idx = 743, label = "line_3158_to_3613_2_cp", type = "branch")
    data["branch_contingencies"][735] = (idx = 387, label = "line_1387_to_1541_4_cp", type = "branch")
    data["branch_contingencies"][736] = (idx = 2887, label = "xf_2200_2196_2305_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][737] = (idx = 602, label = "line_3010_to_3475_1_cp", type = "branch")
    data["branch_contingencies"][738] = (idx = 594, label = "line_2307_to_2311_5_cp", type = "branch")
    data["branch_contingencies"][739] = (idx = 651, label = "line_3063_to_3164_1_cp", type = "branch")
    data["branch_contingencies"][740] = (idx = 1046, label = "line_4117_to_4131_1_cp", type = "branch")
    data["branch_contingencies"][741] = (idx = 1117, label = "line_4217_to_4224_1_cp", type = "branch")
    data["branch_contingencies"][742] = (idx = 192, label = "line_1195_to_1313_1_cp", type = "branch")
    data["branch_contingencies"][743] = (idx = 552, label = "line_2210_to_2218_1_cp", type = "branch")
    data["branch_contingencies"][744] = (idx = 417, label = "line_1458_to_1468_1_cp", type = "branch")
    data["branch_contingencies"][745] = (idx = 991, label = "line_3582_to_3589_1_cp", type = "branch")
    data["branch_contingencies"][746] = (idx = 2756, label = "xf_1097_1098_1161_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][747] = (idx = 1406, label = "xf_1002_to_1006_10_2winding_transformer", type = "branch")
    data["branch_contingencies"][748] = (idx = 1320, label = "line_5155_to_5160_1_cp", type = "branch")
    data["branch_contingencies"][749] = (idx = 2959, label = "xf_3413_3415_3414_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][750] = (idx = 1032, label = "line_4104_to_4106_1_cp", type = "branch")
    data["branch_contingencies"][751] = (idx = 1403, label = "Dec8_line_4128_to_4148_1_dec", type = "branch")
    data["branch_contingencies"][752] = (idx = 2849, label = "xf_2145_2243_2306_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][753] = (idx = 1910, label = "xf_2229_to_2013_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][754] = (idx = 45, label = "line_1105_to_1114_1_cp", type = "branch")
    data["branch_contingencies"][755] = (idx = 3018, label = "xf_4104_4045_4046_4_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][756] = (idx = 1002, label = "line_3604_to_3611_1_cp", type = "branch")
    data["branch_contingencies"][757] = (idx = 400, label = "line_1403_to_1425_1_cp", type = "branch")
    data["branch_contingencies"][758] = (idx = 728, label = "line_3141_to_3486_1_cp", type = "branch")
    data["branch_contingencies"][759] = (idx = 392, label = "line_1392_to_1419_1_cp", type = "branch")
    data["branch_contingencies"][760] = (idx = 1103, label = "line_4201_to_4202_2_cp", type = "branch")
    data["branch_contingencies"][761] = (idx = 949, label = "line_3557_to_3611_1_cp", type = "branch")
    data["branch_contingencies"][762] = (idx = 671, label = "line_3076_to_3283_1_cp", type = "branch")
    data["branch_contingencies"][763] = (idx = 275, label = "line_1242_to_1364_1_cp", type = "branch")
    data["branch_contingencies"][764] = (idx = 2820, label = "xf_1430_1502_1542_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][765] = (idx = 459, label = "line_2105_to_2177_1_cp", type = "branch")
    data["branch_contingencies"][766] = (idx = 308, label = "line_1287_to_1463_1_cp", type = "branch")
    data["branch_contingencies"][767] = (idx = 606, label = "line_3017_to_3314_2_cp", type = "branch")
    data["branch_contingencies"][768] = (idx = 233, label = "line_1212_to_1309_1_cp", type = "branch")
    data["branch_contingencies"][769] = (idx = 130, label = "line_1168_to_1497_1_cp", type = "branch")
    data["branch_contingencies"][770] = (idx = 2947, label = "xf_3362_3364_3363_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][771] = (idx = 2964, label = "xf_3413_3415_3414_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][772] = (idx = 3074, label = "xf_5090_5200_5201_6_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][773] = (idx = 100, label = "line_1139_to_1247_1_cp", type = "branch")
    data["branch_contingencies"][774] = (idx = 444, label = "line_1601_to_1658_1_cp", type = "branch")
    data["branch_contingencies"][775] = (idx = 735, label = "line_3146_to_3209_1_cp_merged_with_xf_3146_to_3147_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][776] = (idx = 262, label = "line_1230_to_1401_1_cp", type = "branch")
    data["branch_contingencies"][777] = (idx = 48, label = "line_1106_to_1151_1_cp", type = "branch")
    data["branch_contingencies"][778] = (idx = 592, label = "line_2280_to_2283_1_cp", type = "branch")
    data["branch_contingencies"][779] = (idx = 1661, label = "xf_1428_to_1501_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][780] = (idx = 405, label = "line_1429_to_1432_1_cp", type = "branch")
    data["branch_contingencies"][781] = (idx = 1035, label = "line_4107_to_4109_1_cp", type = "branch")
    data["branch_contingencies"][782] = (idx = 2473, label = "xf_4263_to_4056_2_2winding_transformer_merged_with_line_4263_to_4326_1_cp", type = "branch")
    data["branch_contingencies"][783] = (idx = 2, label = "line_1027_to_1358_1_cp", type = "branch")
    data["branch_contingencies"][784] = (idx = 1122, label = "line_4231_to_4232_1_cp", type = "branch")
    data["branch_contingencies"][785] = (idx = 51, label = "line_1108_to_1208_1_cp", type = "branch")
    data["branch_contingencies"][786] = (idx = 2972, label = "xf_3486_3561_3487_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][787] = (idx = 141, label = "line_1179_to_1200_3_cp", type = "branch")
    data["branch_contingencies"][788] = (idx = 2941, label = "xf_3359_3360_3361_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][789] = (idx = 713, label = "line_3123_to_3473_1_cp", type = "branch")
    data["branch_contingencies"][790] = (idx = 600, label = "line_3009_to_3475_2_cp", type = "branch")
    data["branch_contingencies"][791] = (idx = 1127, label = "line_4235_to_4382_1_cp", type = "branch")
    data["branch_contingencies"][792] = (idx = 194, label = "line_1196_to_1241_1_cp", type = "branch")
    data["branch_contingencies"][793] = (idx = 936, label = "line_3547_to_3556_1_cp", type = "branch")
    data["branch_contingencies"][794] = (idx = 369, label = "line_1356_to_1464_1_cp", type = "branch")
    data["branch_contingencies"][795] = (idx = 1153, label = "line_4257_to_4332_1_cp", type = "branch")
    data["branch_contingencies"][796] = (idx = 784, label = "line_3204_to_3496_2_cp", type = "branch")
    data["branch_contingencies"][797] = (idx = 18, label = "line_1095_to_1109_1_cp", type = "branch")
    data["branch_contingencies"][798] = (idx = 2412, label = "xf_4220_to_4076_8_2winding_transformer", type = "branch")
    data["branch_contingencies"][799] = (idx = 2357, label = "xf_4171_to_4115_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][800] = (idx = 961, label = "line_3560_to_3593_1_cp", type = "branch")
    data["branch_contingencies"][801] = (idx = 1105, label = "line_4204_to_4206_1_cp", type = "branch")
    data["branch_contingencies"][802] = (idx = 2596, label = "xf_4462_to_4461_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][803] = (idx = 313, label = "line_1289_to_1460_2_cp", type = "branch")
    data["branch_contingencies"][804] = (idx = 1404, label = "Dec9_line_4129_to_4146_1_dec", type = "branch")
    data["branch_contingencies"][805] = (idx = 1204, label = "line_4316_to_4333_1_cp_merged_with_xf_4147_to_4333_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][806] = (idx = 1964, label = "xf_3027_to_3029_2_2winding_transformer_merged_with_line_3027_to_3072_1_cp", type = "branch")
    data["branch_contingencies"][807] = (idx = 2931, label = "xf_3333_3336_3335_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][808] = (idx = 267, label = "line_1237_to_1278_1_cp", type = "branch")
    data["branch_contingencies"][809] = (idx = 2976, label = "xf_3486_3561_3488_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][810] = (idx = 1276, label = "line_5095_to_5111_1_cp", type = "branch")
    data["branch_contingencies"][811] = (idx = 420, label = "line_1464_to_1473_1_cp", type = "branch")
    data["branch_contingencies"][812] = (idx = 3025, label = "xf_4160_4097_4400_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][813] = (idx = 727, label = "line_3140_to_3643_2_cp", type = "branch")
    data["branch_contingencies"][814] = (idx = 1954, label = "xf_3014_to_3016_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][815] = (idx = 810, label = "line_3237_to_3382_2_cp", type = "branch")
    data["branch_contingencies"][816] = (idx = 670, label = "line_3076_to_3276_1_cp", type = "branch")
    data["branch_contingencies"][817] = (idx = 1475, label = "xf_1123_to_1045_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][818] = (idx = 3010, label = "xf_4104_4039_4040_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][819] = (idx = 326, label = "line_1308_to_1395_1_cp", type = "branch")
    data["branch_contingencies"][820] = (idx = 467, label = "line_2114_to_2182_1_cp", type = "branch")
    data["branch_contingencies"][821] = (idx = 714, label = "line_3123_to_3633_1_cp", type = "branch")
    data["branch_contingencies"][822] = (idx = 1308, label = "line_5142_to_5143_1_cp", type = "branch")
    data["branch_contingencies"][823] = (idx = 250, label = "line_1221_to_1441_1_cp", type = "branch")
    data["branch_contingencies"][824] = (idx = 2910, label = "xf_3231_3644_3645_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][825] = (idx = 59, label = "line_1112_to_1140_1_cp", type = "branch")
    data["branch_contingencies"][826] = (idx = 1048, label = "line_4124_to_4131_1_cp", type = "branch")
    data["branch_contingencies"][827] = (idx = 415, label = "line_1443_to_1483_1_cp", type = "branch")
    data["branch_contingencies"][828] = (idx = 1134, label = "line_4243_to_4246_1_cp", type = "branch")
    data["branch_contingencies"][829] = (idx = 1077, label = "line_4171_to_4173_1_cp_merged_with_xf_4173_to_4366_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][830] = (idx = 676, label = "line_3080_to_3240_1_cp", type = "branch")
    data["branch_contingencies"][831] = (idx = 777, label = "line_3192_to_3534_1_cp", type = "branch")
    data["branch_contingencies"][832] = (idx = 177, label = "line_1191_to_1234_1_cp", type = "branch")
    data["branch_contingencies"][833] = (idx = 396, label = "line_1397_to_1630_1_cp", type = "branch")
    data["branch_contingencies"][834] = (idx = 260, label = "line_1228_to_1381_1_cp", type = "branch")
    data["branch_contingencies"][835] = (idx = 740, label = "line_3153_to_3482_1_cp", type = "branch")
    data["branch_contingencies"][836] = (idx = 556, label = "line_2213_to_2215_1_cp", type = "branch")
    data["branch_contingencies"][837] = (idx = 2340, label = "xf_4150_to_4214_1_2winding_transformer_merged_with_line_4189_to_4214_1_cp", type = "branch")
    data["branch_contingencies"][838] = (idx = 413, label = "line_1439_to_1446_1_cp", type = "branch")
    data["branch_contingencies"][839] = (idx = 805, label = "line_3229_to_3471_1_cp", type = "branch")
    data["branch_contingencies"][840] = (idx = 1887, label = "xf_2200_to_2196_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][841] = (idx = 2808, label = "xf_1296_1504_1505_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][842] = (idx = 2110, label = "xf_3326_to_3324_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][843] = (idx = 2934, label = "xf_3333_3336_3335_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][844] = (idx = 2843, label = "xf_2077_2205_2349_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][845] = (idx = 1112, label = "line_4213_to_4215_2_cp", type = "branch")
    data["branch_contingencies"][846] = (idx = 924, label = "line_3543_to_3568_1_cp", type = "branch")
    data["branch_contingencies"][847] = (idx = 1044, label = "line_4116_to_4150_1_cp", type = "branch")
    data["branch_contingencies"][848] = (idx = 1396, label = "Dec27_line_4297_to_4334_1_dec", type = "branch")
    data["branch_contingencies"][849] = (idx = 2351, label = "xf_4166_to_4005_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][850] = (idx = 431, label = "line_1579_to_1648_1_cp", type = "branch")
    data["branch_contingencies"][851] = (idx = 1666, label = "xf_1434_to_1571_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][852] = (idx = 2589, label = "xf_4358_to_4016_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][853] = (idx = 785, label = "line_3205_to_3496_1_cp", type = "branch")
    data["branch_contingencies"][854] = (idx = 1001, label = "line_3604_to_3608_1_cp", type = "branch")
    data["branch_contingencies"][855] = (idx = 68, label = "line_1117_to_1144_1_cp", type = "branch")
    data["branch_contingencies"][856] = (idx = 393, label = "line_1396_to_1416_1_cp", type = "branch")
    data["branch_contingencies"][857] = (idx = 355, label = "line_1344_to_1349_1_cp", type = "branch")
    data["branch_contingencies"][858] = (idx = 1529, label = "xf_1149_to_1196_6_2winding_transformer", type = "branch")
    data["branch_contingencies"][859] = (idx = 305, label = "line_1283_to_1336_1_cp", type = "branch")
    data["branch_contingencies"][860] = (idx = 1353, label = "line_1600_to_1651_1_pi", type = "branch")
    data["branch_contingencies"][861] = (idx = 62, label = "line_1113_to_2195_1_cp", type = "branch")
    data["branch_contingencies"][862] = (idx = 2819, label = "xf_1430_1502_1542_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][863] = (idx = 2757, label = "xf_1097_1098_1161_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][864] = (idx = 3036, label = "xf_4186_4230_4494_1_3winding_transformer_br1_merged_with_line_4185_to_4186_1_cp", type = "branch")
    data["branch_contingencies"][865] = (idx = 390, label = "line_1391_to_1393_1_cp", type = "branch")
    data["branch_contingencies"][866] = (idx = 1144, label = "line_4248_to_4337_1_cp", type = "branch")
    data["branch_contingencies"][867] = (idx = 702, label = "line_3108_to_3201_1_cp", type = "branch")
    data["branch_contingencies"][868] = (idx = 1047, label = "line_4117_to_4154_1_cp", type = "branch")
    data["branch_contingencies"][869] = (idx = 379, label = "line_1369_to_1656_4_cp", type = "branch")
    data["branch_contingencies"][870] = (idx = 2751, label = "xf_1092_1093_1525_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][871] = (idx = 13, label = "line_1091_to_1150_1_cp", type = "branch")
    data["branch_contingencies"][872] = (idx = 3078, label = "xf_5093_5202_5203_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][873] = (idx = 1053, label = "line_4131_to_4149_1_cp", type = "branch")
    data["branch_contingencies"][874] = (idx = 1045, label = "line_4117_to_4124_1_cp", type = "branch")
    data["branch_contingencies"][875] = (idx = 1250, label = "line_5074_to_5123_1_cp", type = "branch")
    data["branch_contingencies"][876] = (idx = 2996, label = "xf_3633_3514_3513_4_3winding_transformer_br2_merged_with_line_3367_to_3514_1_pi", type = "branch")
    data["branch_contingencies"][877] = (idx = 402, label = "line_1405_to_1443_1_cp", type = "branch")
    data["branch_contingencies"][878] = (idx = 2897, label = "xf_3177_3179_3178_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][879] = (idx = 814, label = "line_3246_to_3259_1_cp", type = "branch")
    data["branch_contingencies"][880] = (idx = 1483, label = "xf_1124_to_1551_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][881] = (idx = 339, label = "line_1330_to_1382_1_cp", type = "branch")
    data["branch_contingencies"][882] = (idx = 1072, label = "line_4165_to_4223_2_cp", type = "branch")
    data["branch_contingencies"][883] = (idx = 206, label = "line_1200_to_1332_2_cp", type = "branch")
    data["branch_contingencies"][884] = (idx = 595, label = "line_2309_to_2311_7_cp", type = "branch")
    data["branch_contingencies"][885] = (idx = 430, label = "line_1570_to_1571_1_cp", type = "branch")
    data["branch_contingencies"][886] = (idx = 1131, label = "line_4238_to_4241_1_cp", type = "branch")
    data["branch_contingencies"][887] = (idx = 2875, label = "xf_2191_2031_2022_5_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][888] = (idx = 1058, label = "line_4139_to_4151_2_cp", type = "branch")
    data["branch_contingencies"][889] = (idx = 209, label = "line_1200_to_1432_1_cp", type = "branch")
    data["branch_contingencies"][890] = (idx = 1482, label = "xf_1124_to_1180_3_2winding_transformer_merged_with_line_1180_to_1463_1_pi", type = "branch")
    data["branch_contingencies"][891] = (idx = 2852, label = "xf_2145_2243_2306_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][892] = (idx = 222, label = "line_1206_to_1274_1_cp", type = "branch")
    data["branch_contingencies"][893] = (idx = 2231, label = "xf_3609_to_3648_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][894] = (idx = 3011, label = "xf_4104_4039_4040_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][895] = (idx = 540, label = "line_2200_to_2209_1_cp", type = "branch")
    data["branch_contingencies"][896] = (idx = 483, label = "line_2125_to_2169_1_cp", type = "branch")
    data["branch_contingencies"][897] = (idx = 2888, label = "xf_2200_2196_2305_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][898] = (idx = 2823, label = "xf_1430_1502_1543_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][899] = (idx = 331, label = "line_1312_to_1474_1_cp", type = "branch")
    data["branch_contingencies"][900] = (idx = 1003, label = "line_3605_to_3610_2_cp", type = "branch")
    data["branch_contingencies"][901] = (idx = 1971, label = "xf_3039_to_3040_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][902] = (idx = 2949, label = "xf_3362_3364_3363_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][903] = (idx = 844, label = "line_3305_to_3642_1_cp", type = "branch")
    data["branch_contingencies"][904] = (idx = 931, label = "line_3545_to_3595_1_cp", type = "branch")
    data["branch_contingencies"][905] = (idx = 1191, label = "line_4303_to_4304_1_cp", type = "branch")
    data["branch_contingencies"][906] = (idx = 1725, label = "xf_1657_to_1086_3_2winding_transformer_merged_with_line_1369_to_1657_3_cp", type = "branch")
    data["branch_contingencies"][907] = (idx = 328, label = "line_1309_to_1530_1_cp", type = "branch")
    data["branch_contingencies"][908] = (idx = 2747, label = "xf_1090_1091_1523_9_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][909] = (idx = 1190, label = "line_4302_to_4342_1_cp", type = "branch")
    data["branch_contingencies"][910] = (idx = 1193, label = "line_4303_to_4306_2_cp", type = "branch")
    data["branch_contingencies"][911] = (idx = 708, label = "line_3111_to_3483_1_cp", type = "branch")
    data["branch_contingencies"][912] = (idx = 2821, label = "xf_1430_1502_1542_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][913] = (idx = 1711, label = "xf_1528_to_1610_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][914] = (idx = 1170, label = "line_4273_to_4274_1_cp", type = "branch")
    data["branch_contingencies"][915] = (idx = 463, label = "line_2108_to_2145_1_cp", type = "branch")
    data["branch_contingencies"][916] = (idx = 2953, label = "xf_3371_3372_3373_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][917] = (idx = 386, label = "line_1381_to_1435_1_cp", type = "branch")
    data["branch_contingencies"][918] = (idx = 30, label = "line_1098_to_1144_1_cp", type = "branch")
    data["branch_contingencies"][919] = (idx = 1286, label = "line_5103_to_5104_1_cp", type = "branch")
    data["branch_contingencies"][920] = (idx = 2892, label = "xf_3134_3135_3136_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][921] = (idx = 1268, label = "line_5090_to_5102_2_cp", type = "branch")
    data["branch_contingencies"][922] = (idx = 1961, label = "xf_3025_to_3024_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][923] = (idx = 797, label = "line_3222_to_3506_1_cp", type = "branch")
    data["branch_contingencies"][924] = (idx = 2586, label = "xf_4357_to_4015_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][925] = (idx = 2773, label = "xf_1106_1167_1537_4_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][926] = (idx = 738, label = "line_3150_to_3151_1_cp", type = "branch")
    data["branch_contingencies"][927] = (idx = 879, label = "line_3390_to_3534_2_cp", type = "branch")
    data["branch_contingencies"][928] = (idx = 1099, label = "line_4194_to_4204_1_cp", type = "branch")
    data["branch_contingencies"][929] = (idx = 1860, label = "xf_2180_to_2289_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][930] = (idx = 2114, label = "xf_3338_to_3339_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][931] = (idx = 142, label = "line_1179_to_1329_1_cp_merged_with_line_1329_to_1407_1_cp_merged_with_line_1263_to_1407_1_cp", type = "branch")
    data["branch_contingencies"][932] = (idx = 432, label = "line_1580_to_1594_1_cp", type = "branch")
    data["branch_contingencies"][933] = (idx = 588, label = "line_2258_to_2261_2_cp_merged_with_xf_2258_to_2065_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][934] = (idx = 319, label = "line_1297_to_1308_1_cp", type = "branch")
    data["branch_contingencies"][935] = (idx = 2925, label = "xf_3302_3304_3303_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][936] = (idx = 67, label = "line_1117_to_1140_1_cp", type = "branch")
    data["branch_contingencies"][937] = (idx = 821, label = "line_3263_to_3531_1_cp_merged_with_xf_3531_to_3604_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][938] = (idx = 2946, label = "xf_3362_3364_3363_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][939] = (idx = 1960, label = "xf_3024_to_3026_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][940] = (idx = 789, label = "line_3214_to_3255_1_cp", type = "branch")
    data["branch_contingencies"][941] = (idx = 2866, label = "xf_2191_2025_2026_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][942] = (idx = 2928, label = "xf_3333_3335_3336_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][943] = (idx = 927, label = "line_3545_to_3571_3_cp_merged_with_xf_3503_to_3571_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][944] = (idx = 2882, label = "xf_2195_2293_2332_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][945] = (idx = 1203, label = "line_4314_to_4315_1_cp", type = "branch")
    data["branch_contingencies"][946] = (idx = 226, label = "line_1206_to_1414_1_cp", type = "branch")
    data["branch_contingencies"][947] = (idx = 2758, label = "xf_1097_1098_1161_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][948] = (idx = 553, label = "line_2210_to_2252_1_cp", type = "branch")
    data["branch_contingencies"][949] = (idx = 644, label = "line_3061_to_3151_1_cp", type = "branch")
    data["branch_contingencies"][950] = (idx = 2954, label = "xf_3371_3372_3373_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][951] = (idx = 221, label = "line_1205_to_1487_1_cp_merged_with_line_1429_to_1487_1_cp", type = "branch")
    data["branch_contingencies"][952] = (idx = 690, label = "line_3096_to_3207_2_cp_merged_with_xf_3207_to_3459_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][953] = (idx = 134, label = "line_1169_to_1529_1_cp", type = "branch")
    data["branch_contingencies"][954] = (idx = 1400, label = "Dec5_line_4124_to_4125_1_dec", type = "branch")
    data["branch_contingencies"][955] = (idx = 560, label = "line_2214_to_2226_1_cp", type = "branch")
    data["branch_contingencies"][956] = (idx = 2763, label = "xf_1099_1100_1532_10_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][957] = (idx = 679, label = "line_3083_to_3182_1_cp", type = "branch")
    data["branch_contingencies"][958] = (idx = 307, label = "line_1285_to_1628_1_cp", type = "branch")
    data["branch_contingencies"][959] = (idx = 897, label = "line_3471_to_3503_1_cp", type = "branch")
    data["branch_contingencies"][960] = (idx = 409, label = "line_1435_to_1605_1_cp", type = "branch")
    data["branch_contingencies"][961] = (idx = 2981, label = "xf_3492_3565_3494_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][962] = (idx = 2889, label = "xf_2200_2196_2305_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][963] = (idx = 2913, label = "xf_3231_3644_3645_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][964] = (idx = 677, label = "line_3080_to_3523_1_cp", type = "branch")
    data["branch_contingencies"][965] = (idx = 939, label = "line_3549_to_3606_1_cp", type = "branch")
    data["branch_contingencies"][966] = (idx = 70, label = "line_1118_to_1151_1_cp", type = "branch")
    data["branch_contingencies"][967] = (idx = 2909, label = "xf_3231_3644_3645_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][968] = (idx = 1869, label = "xf_2184_to_2292_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][969] = (idx = 998, label = "line_3593_to_3595_1_cp", type = "branch")
    data["branch_contingencies"][970] = (idx = 2873, label = "xf_2191_2029_2030_4_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][971] = (idx = 2983, label = "xf_3492_3565_3495_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][972] = (idx = 306, label = "line_1285_to_1474_1_cp", type = "branch")
    data["branch_contingencies"][973] = (idx = 2765, label = "xf_1099_1100_1533_9_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][974] = (idx = 2472, label = "xf_4262_to_4055_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][975] = (idx = 605, label = "line_3017_to_3019_2_cp", type = "branch")
    data["branch_contingencies"][976] = (idx = 2846, label = "xf_2145_2243_2306_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][977] = (idx = 416, label = "line_1454_to_1456_1_cp", type = "branch")
    data["branch_contingencies"][978] = (idx = 23, label = "line_1096_to_1119_1_cp", type = "branch")
    data["branch_contingencies"][979] = (idx = 2208, label = "xf_3535_to_3613_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][980] = (idx = 323, label = "line_1305_to_1320_1_cp", type = "branch")
    data["branch_contingencies"][981] = (idx = 1296, label = "line_5117_to_5118_1_cp_merged_with_line_5034_to_5242_1_cp_merged_with_xf_5117_to_5242_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][982] = (idx = 167, label = "line_1189_to_1305_1_cp", type = "branch")
    data["branch_contingencies"][983] = (idx = 643, label = "line_3060_to_3274_1_cp", type = "branch")
    data["branch_contingencies"][984] = (idx = 2839, label = "xf_2077_2205_2347_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][985] = (idx = 3068, label = "xf_5088_5175_5241_4_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][986] = (idx = 1078, label = "line_4171_to_4183_1_cp", type = "branch")
    data["branch_contingencies"][987] = (idx = 2748, label = "xf_1090_1091_1523_9_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][988] = (idx = 1043, label = "line_4110_to_4143_1_cp", type = "branch")
    data["branch_contingencies"][989] = (idx = 1938, label = "xf_2310_to_2344_6_2winding_transformer", type = "branch")
    data["branch_contingencies"][990] = (idx = 2327, label = "xf_4135_to_4277_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][991] = (idx = 1710, label = "xf_1521_to_1000_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][992] = (idx = 704, label = "line_3108_to_3244_1_cp_merged_with_xf_3244_to_3659_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][993] = (idx = 1050, label = "line_4124_to_4150_1_cp", type = "branch")
    data["branch_contingencies"][994] = (idx = 1145, label = "line_4250_to_4251_1_cp", type = "branch")
    data["branch_contingencies"][995] = (idx = 554, label = "line_2210_to_2294_1_cp", type = "branch")
    data["branch_contingencies"][996] = (idx = 3071, label = "xf_5090_5200_5201_5_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][997] = (idx = 3012, label = "xf_4104_4041_4042_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][998] = (idx = 542, label = "line_2201_to_2208_1_cp", type = "branch")
    data["branch_contingencies"][999] = (idx = 389, label = "line_1390_to_1541_1_cp_merged_with_line_1280_to_1390_1_cp_merged_with_line_1280_to_1281_1_pi", type = "branch")
    data["branch_contingencies"][1000] = (idx = 1075, label = "line_4167_to_4182_1_cp", type = "branch")
    data["branch_contingencies"][1001] = (idx = 772, label = "line_3189_to_3223_1_cp", type = "branch")
    data["branch_contingencies"][1002] = (idx = 734, label = "line_3144_to_3523_1_cp", type = "branch")
    data["branch_contingencies"][1003] = (idx = 1810, label = "xf_2148_to_2251_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1004] = (idx = 2771, label = "xf_1106_1167_1537_4_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1005] = (idx = 2912, label = "xf_3231_3644_3645_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1006] = (idx = 1862, label = "xf_2181_to_2290_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][1007] = (idx = 992, label = "line_3583_to_3589_2_cp", type = "branch")
    data["branch_contingencies"][1008] = (idx = 3066, label = "xf_5087_5175_5176_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1009] = (idx = 56, label = "line_1110_to_1511_1_cp", type = "branch")
    data["branch_contingencies"][1010] = (idx = 1081, label = "line_4174_to_4200_1_cp", type = "branch")
    data["branch_contingencies"][1011] = (idx = 2761, label = "xf_1097_1098_1162_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1012] = (idx = 2942, label = "xf_3359_3360_3361_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1013] = (idx = 489, label = "line_2128_to_2161_2_cp", type = "branch")
    data["branch_contingencies"][1014] = (idx = 2867, label = "xf_2191_2025_2026_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1015] = (idx = 1246, label = "line_5071_to_5072_1_cp", type = "branch")
    data["branch_contingencies"][1016] = (idx = 2857, label = "xf_2191_2018_2019_6_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1017] = (idx = 213, label = "line_1204_to_1306_1_cp", type = "branch")
    data["branch_contingencies"][1018] = (idx = 2927, label = "xf_3333_3335_3336_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1019] = (idx = 404, label = "line_1425_to_1467_1_cp", type = "branch")
    data["branch_contingencies"][1020] = (idx = 1402, label = "Dec7_line_4125_to_4128_1_dec", type = "branch")
    data["branch_contingencies"][1021] = (idx = 1476, label = "xf_1123_to_1179_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][1022] = (idx = 804, label = "line_3226_to_3496_1_cp", type = "branch")
    data["branch_contingencies"][1023] = (idx = 811, label = "line_3238_to_3382_1_cp", type = "branch")
    data["branch_contingencies"][1024] = (idx = 1109, label = "line_4210_to_4211_1_cp", type = "branch")
    data["branch_contingencies"][1025] = (idx = 1205, label = "line_4318_to_4339_1_cp", type = "branch")
    data["branch_contingencies"][1026] = (idx = 1113, label = "line_4215_to_4217_1_cp", type = "branch")
    data["branch_contingencies"][1027] = (idx = 1188, label = "line_4301_to_4339_1_cp", type = "branch")
    data["branch_contingencies"][1028] = (idx = 1238, label = "line_5063_to_5066_1_cp", type = "branch")
    data["branch_contingencies"][1029] = (idx = 2924, label = "xf_3302_3304_3303_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1030] = (idx = 2948, label = "xf_3362_3364_3363_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1031] = (idx = 629, label = "line_3039_to_3217_2_cp", type = "branch")
    data["branch_contingencies"][1032] = (idx = 2881, label = "xf_2195_2293_2332_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1033] = (idx = 2943, label = "xf_3359_3360_3361_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1034] = (idx = 3013, label = "xf_4104_4041_4042_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1035] = (idx = 2809, label = "xf_1296_1504_1505_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1036] = (idx = 2841, label = "xf_2077_2205_2347_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1037] = (idx = 497, label = "line_2145_to_2179_1_cp", type = "branch")
    data["branch_contingencies"][1038] = (idx = 3043, label = "xf_4218_4392_4496_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1039] = (idx = 2883, label = "xf_2195_2293_2332_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1040] = (idx = 2099, label = "xf_3293_to_3294_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1041] = (idx = 570, label = "line_2230_to_2238_1_cp", type = "branch")
    data["branch_contingencies"][1042] = (idx = 2411, label = "xf_4220_to_4075_7_2winding_transformer", type = "branch")
    data["branch_contingencies"][1043] = (idx = 169, label = "line_1189_to_1457_1_cp", type = "branch")
    data["branch_contingencies"][1044] = (idx = 1354, label = "line_2017_to_2353_2_pi", type = "branch")
    data["branch_contingencies"][1045] = (idx = 2786, label = "xf_1121_1123_1635_7_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1046] = (idx = 391, label = "line_1391_to_1478_1_cp", type = "branch")
    data["branch_contingencies"][1047] = (idx = 64, label = "line_1115_to_1132_1_cp", type = "branch")
    data["branch_contingencies"][1048] = (idx = 91, label = "line_1132_to_1153_1_cp", type = "branch")
    data["branch_contingencies"][1049] = (idx = 2884, label = "xf_2200_2196_2304_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1050] = (idx = 498, label = "line_2146_to_2189_1_cp", type = "branch")
    data["branch_contingencies"][1051] = (idx = 490, label = "line_2128_to_2189_1_cp", type = "branch")
    data["branch_contingencies"][1052] = (idx = 1226, label = "line_5057_to_5063_1_cp", type = "branch")
    data["branch_contingencies"][1053] = (idx = 2956, label = "xf_3379_3380_3381_3_3winding_transformer_br1_merged_with_line_3379_to_3504_1_cp", type = "branch")
    data["branch_contingencies"][1054] = (idx = 1082, label = "line_4175_to_4200_1_cp_merged_with_line_4175_to_4190_1_cp", type = "branch")
    data["branch_contingencies"][1055] = (idx = 353, label = "line_1341_to_1488_1_cp", type = "branch")
    data["branch_contingencies"][1056] = (idx = 232, label = "line_1211_to_1222_1_cp", type = "branch")
    data["branch_contingencies"][1057] = (idx = 101, label = "line_1139_to_1395_1_cp", type = "branch")
    data["branch_contingencies"][1058] = (idx = 3016, label = "xf_4104_4043_4044_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1059] = (idx = 1115, label = "line_4216_to_4220_1_cp", type = "branch")
    data["branch_contingencies"][1060] = (idx = 1054, label = "line_4132_to_4235_1_cp", type = "branch")
    data["branch_contingencies"][1061] = (idx = 335, label = "line_1318_to_1319_1_cp", type = "branch")
    data["branch_contingencies"][1062] = (idx = 2767, label = "xf_1099_1100_1533_9_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1063] = (idx = 168, label = "line_1189_to_1371_1_cp", type = "branch")
    data["branch_contingencies"][1064] = (idx = 1405, label = "line_4139_to_4140_2_RLC_merged_with_line_4140_to_4149_2_cp", type = "branch")
    data["branch_contingencies"][1065] = (idx = 1027, label = "line_4071_to_4325_1_cp", type = "branch")
    data["branch_contingencies"][1066] = (idx = 2764, label = "xf_1099_1100_1532_10_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1067] = (idx = 2950, label = "xf_3371_3372_3373_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1068] = (idx = 1093, label = "line_4185_to_4187_2_cp_merged_with_xf_4187_4230_4495_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1069] = (idx = 1208, label = "line_4319_to_4321_1_cp", type = "branch")
    data["branch_contingencies"][1070] = (idx = 3017, label = "xf_4104_4043_4044_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1071] = (idx = 1342, label = "line_1357_to_1597_1_pi", type = "branch")
    data["branch_contingencies"][1072] = (idx = 2790, label = "xf_1148_1073_1074_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1073] = (idx = 761, label = "line_3172_to_3518_1_cp", type = "branch")
    data["branch_contingencies"][1074] = (idx = 2945, label = "xf_3362_3364_3363_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1075] = (idx = 1200, label = "line_4311_to_4342_1_cp", type = "branch")
    data["branch_contingencies"][1076] = (idx = 2090, label = "xf_3237_to_3239_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1077] = (idx = 488, label = "line_2128_to_2160_1_cp", type = "branch")
    data["branch_contingencies"][1078] = (idx = 2039, label = "xf_3137_to_3139_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1079] = (idx = 2091, label = "xf_3238_to_3239_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1080] = (idx = 105, label = "line_1146_to_1153_1_cp", type = "branch")
    data["branch_contingencies"][1081] = (idx = 547, label = "line_2203_to_2209_1_cp", type = "branch")
    data["branch_contingencies"][1082] = (idx = 2759, label = "xf_1097_1098_1162_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1083] = (idx = 3033, label = "xf_4166_4356_4492_4_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1084] = (idx = 1214, label = "line_4325_to_4338_1_cp", type = "branch")
    data["branch_contingencies"][1085] = (idx = 296, label = "line_1272_to_1382_1_cp", type = "branch")
    data["branch_contingencies"][1086] = (idx = 775, label = "line_3192_to_3467_1_cp", type = "branch")
    data["branch_contingencies"][1087] = (idx = 1039, label = "line_4107_to_4115_1_cp", type = "branch")
    data["branch_contingencies"][1088] = (idx = 1247, label = "line_5073_to_5074_1_cp", type = "branch")
    data["branch_contingencies"][1089] = (idx = 63, label = "line_1115_to_1126_1_cp", type = "branch")
    data["branch_contingencies"][1090] = (idx = 2224, label = "xf_3601_to_3445_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1091] = (idx = 2710, label = "xf_5151_to_5013_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][1092] = (idx = 1409, label = "xf_1010_to_1606_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][1093] = (idx = 1934, label = "xf_2306_to_2340_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][1094] = (idx = 286, label = "line_1260_to_1261_1_cp", type = "branch")
    data["branch_contingencies"][1095] = (idx = 2215, label = "xf_3573_to_3507_1_2winding_transformer_merged_with_line_3039_to_3507_1_cp", type = "branch")
    data["branch_contingencies"][1096] = (idx = 2878, label = "xf_2195_2293_2332_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1097] = (idx = 1128, label = "line_4236_to_4237_1_cp", type = "branch")
    data["branch_contingencies"][1098] = (idx = 779, label = "line_3195_to_3247_1_cp", type = "branch")
    data["branch_contingencies"][1099] = (idx = 110, label = "line_1159_to_1331_1_cp", type = "branch")
    data["branch_contingencies"][1100] = (idx = 1393, label = "Dec24_line_4276_to_4281_1_dec", type = "branch")
    data["branch_contingencies"][1101] = (idx = 1021, label = "line_4002_to_4109_1_cp", type = "branch")
    data["branch_contingencies"][1102] = (idx = 1141, label = "line_4244_to_4247_1_cp", type = "branch")
    data["branch_contingencies"][1103] = (idx = 597, label = "line_3004_to_3006_1_cp", type = "branch")
    data["branch_contingencies"][1104] = (idx = 736, label = "line_3147_to_3401_1_cp", type = "branch")
    data["branch_contingencies"][1105] = (idx = 2960, label = "xf_3413_3415_3414_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1106] = (idx = 1228, label = "line_5058_to_5064_1_cp", type = "branch")
    data["branch_contingencies"][1107] = (idx = 183, label = "line_1192_to_1423_1_cp", type = "branch")
    data["branch_contingencies"][1108] = (idx = 1781, label = "xf_2127_to_2234_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1109] = (idx = 1381, label = "Dec13_line_4135_to_4137_1_dec", type = "branch")
    data["branch_contingencies"][1110] = (idx = 631, label = "line_3044_to_3482_2_cp", type = "branch")
    data["branch_contingencies"][1111] = (idx = 2979, label = "xf_3486_3561_3489_3_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1112] = (idx = 1249, label = "line_5073_to_5123_1_cp", type = "branch")
    data["branch_contingencies"][1113] = (idx = 1202, label = "line_4313_to_4314_1_cp", type = "branch")
    data["branch_contingencies"][1114] = (idx = 1174, label = "line_4278_to_4296_1_cp", type = "branch")
    data["branch_contingencies"][1115] = (idx = 3076, label = "xf_5090_5200_5201_6_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1116] = (idx = 672, label = "line_3076_to_3401_1_cp", type = "branch")
    data["branch_contingencies"][1117] = (idx = 1142, label = "line_4246_to_4332_1_cp", type = "branch")
    data["branch_contingencies"][1118] = (idx = 7, label = "line_1061_to_1311_1_cp", type = "branch")
    data["branch_contingencies"][1119] = (idx = 1168, label = "line_4267_to_4292_1_cp", type = "branch")
    data["branch_contingencies"][1120] = (idx = 2111, label = "xf_3326_to_3325_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1121] = (idx = 1844, label = "xf_2171_to_2276_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][1122] = (idx = 2749, label = "xf_1090_1091_1523_9_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1123] = (idx = 1124, label = "line_4232_to_4274_1_cp", type = "branch")
    data["branch_contingencies"][1124] = (idx = 301, label = "line_1278_to_1294_1_cp", type = "branch")
    data["branch_contingencies"][1125] = (idx = 2891, label = "xf_3134_3135_3136_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1126] = (idx = 509, label = "line_2162_to_2179_1_cp", type = "branch")
    data["branch_contingencies"][1127] = (idx = 2901, label = "xf_3177_3179_3178_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1128] = (idx = 2072, label = "xf_3198_to_3200_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1129] = (idx = 2784, label = "xf_1121_1123_1634_6_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1130] = (idx = 1057, label = "line_4138_to_4151_1_cp", type = "branch")
    data["branch_contingencies"][1131] = (idx = 1902, label = "xf_2207_to_2194_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1132] = (idx = 406, label = "line_1430_to_1489_1_cp", type = "branch")
    data["branch_contingencies"][1133] = (idx = 1901, label = "xf_2206_to_2166_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1134] = (idx = 626, label = "line_3039_to_3050_2_cp", type = "branch")
    data["branch_contingencies"][1135] = (idx = 349, label = "line_1335_to_1628_1_cp", type = "branch")
    data["branch_contingencies"][1136] = (idx = 1175, label = "line_4279_to_4280_1_cp", type = "branch")
    data["branch_contingencies"][1137] = (idx = 1843, label = "xf_2170_to_2276_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][1138] = (idx = 856, label = "line_3325_to_3473_1_cp", type = "branch")
    data["branch_contingencies"][1139] = (idx = 1114, label = "line_4216_to_4218_1_cp", type = "branch")
    data["branch_contingencies"][1140] = (idx = 41, label = "line_1103_to_1148_1_cp", type = "branch")
    data["branch_contingencies"][1141] = (idx = 65, label = "line_1115_to_1145_1_cp", type = "branch")
    data["branch_contingencies"][1142] = (idx = 447, label = "line_1621_to_1630_1_cp", type = "branch")
    data["branch_contingencies"][1143] = (idx = 2651, label = "xf_5092_to_5224_1A_2winding_transformer", type = "branch")
    data["branch_contingencies"][1144] = (idx = 2042, label = "xf_3143_to_3145_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1145] = (idx = 2380, label = "xf_4194_to_4124_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1146] = (idx = 514, label = "line_2164_to_2165_1_cp_merged_with_xf_2206_to_2165_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1147] = (idx = 252, label = "line_1221_to_1461_1_cp", type = "branch")
    data["branch_contingencies"][1148] = (idx = 660, label = "line_3065_to_3277_1_cp", type = "branch")
    data["branch_contingencies"][1149] = (idx = 1718, label = "xf_1602_to_1089_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1150] = (idx = 1007, label = "line_3607_to_3616_1_cp", type = "branch")
    data["branch_contingencies"][1151] = (idx = 2352, label = "xf_4166_to_4356_5_2winding_transformer", type = "branch")
    data["branch_contingencies"][1152] = (idx = 633, label = "line_3048_to_3471_1_cp", type = "branch")
    data["branch_contingencies"][1153] = (idx = 887, label = "line_3411_to_3413_1_cp", type = "branch")
    data["branch_contingencies"][1154] = (idx = 1237, label = "line_5063_to_5065_1_cp", type = "branch")
    data["branch_contingencies"][1155] = (idx = 1355, label = "line_2039_to_2354_2_pi_merged_with_line_2145_to_2354_1_pi", type = "branch")
    data["branch_contingencies"][1156] = (idx = 1459, label = "xf_1114_to_1029_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1157] = (idx = 1211, label = "line_4320_to_4323_1_cp", type = "branch")
    data["branch_contingencies"][1158] = (idx = 2207, label = "xf_3535_to_3612_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1159] = (idx = 1033, label = "line_4104_to_4117_1_cp", type = "branch")
    data["branch_contingencies"][1160] = (idx = 2817, label = "xf_1428_1501_1540_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1161] = (idx = 1407, label = "xf_1003_to_1006_11_2winding_transformer", type = "branch")
    data["branch_contingencies"][1162] = (idx = 2973, label = "xf_3486_3561_3487_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1163] = (idx = 195, label = "line_1197_to_1342_1_cp_merged_with_xf_1149_to_1197_5_2winding_transformer_merged_with_line_1342_to_1463_1_cp", type = "branch")
    data["branch_contingencies"][1164] = (idx = 2828, label = "xf_1588_1327_1068_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1165] = (idx = 923, label = "line_3543_to_3567_1_cp", type = "branch")
    data["branch_contingencies"][1166] = (idx = 1079, label = "line_4171_to_4195_1_cp", type = "branch")
    data["branch_contingencies"][1167] = (idx = 146, label = "line_1183_to_1210_1_cp", type = "branch")
    data["branch_contingencies"][1168] = (idx = 1379, label = "Dec11_line_4129_to_4148_1_dec", type = "branch")
    data["branch_contingencies"][1169] = (idx = 1343, label = "line_1357_to_1651_1_pi", type = "branch")
    data["branch_contingencies"][1170] = (idx = 520, label = "line_2168_to_2180_1_cp", type = "branch")
    data["branch_contingencies"][1171] = (idx = 2200, label = "xf_3530_to_3604_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1172] = (idx = 2060, label = "xf_3184_to_3186_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1173] = (idx = 2961, label = "xf_3413_3415_3414_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1174] = (idx = 1388, label = "Dec1_line_4112_to_4124_1_dec", type = "branch")
    data["branch_contingencies"][1175] = (idx = 3060, label = "xf_4257_4379_4434_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1176] = (idx = 656, label = "line_3063_to_3277_1_cp", type = "branch")
    data["branch_contingencies"][1177] = (idx = 890, label = "line_3412_to_3413_2_cp", type = "branch")
    data["branch_contingencies"][1178] = (idx = 2837, label = "xf_2077_2205_2346_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1179] = (idx = 1172, label = "line_4276_to_4289_1_cp", type = "branch")
    data["branch_contingencies"][1180] = (idx = 103, label = "line_1141_to_1569_1_cp", type = "branch")
    data["branch_contingencies"][1181] = (idx = 53, label = "line_1109_to_1143_1_cp", type = "branch")
    data["branch_contingencies"][1182] = (idx = 2974, label = "xf_3486_3561_3488_2_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1183] = (idx = 3072, label = "xf_5090_5200_5201_5_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1184] = (idx = 1351, label = "line_1597_to_1651_1_pi", type = "branch")
    data["branch_contingencies"][1185] = (idx = 1130, label = "line_4237_to_4240_1_cp", type = "branch")
    data["branch_contingencies"][1186] = (idx = 1395, label = "Dec26_line_4285_to_4286_1_dec", type = "branch")
    data["branch_contingencies"][1187] = (idx = 857, label = "line_3333_to_3413_1_cp", type = "branch")
    data["branch_contingencies"][1188] = (idx = 632, label = "line_3048_to_3229_1_cp", type = "branch")
    data["branch_contingencies"][1189] = (idx = 1890, label = "xf_2201_to_2147_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1190] = (idx = 2073, label = "xf_3199_to_3200_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1191] = (idx = 776, label = "line_3192_to_3506_1_cp", type = "branch")
    data["branch_contingencies"][1192] = (idx = 3052, label = "xf_4220_4394_4497_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1193] = (idx = 1218, label = "line_4365_to_4366_1_cp", type = "branch")
    data["branch_contingencies"][1194] = (idx = 2020, label = "xf_3102_to_3103_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1195] = (idx = 634, label = "line_3050_to_3054_1_cp", type = "branch")
    data["branch_contingencies"][1196] = (idx = 2769, label = "xf_1106_1167_1536_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1197] = (idx = 2903, label = "xf_3226_3227_3228_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1198] = (idx = 388, label = "line_1388_to_1541_2_cp", type = "branch")
    data["branch_contingencies"][1199] = (idx = 729, label = "line_3141_to_3643_1_cp", type = "branch")
    data["branch_contingencies"][1200] = (idx = 698, label = "line_3101_to_3634_2_cp", type = "branch")
    data["branch_contingencies"][1201] = (idx = 1097, label = "line_4192_to_4193_1_cp", type = "branch")
    data["branch_contingencies"][1202] = (idx = 2815, label = "xf_1428_1501_1539_1_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1203] = (idx = 609, label = "line_3018_to_3312_1_cp", type = "branch")
    data["branch_contingencies"][1204] = (idx = 3030, label = "xf_4166_4356_4491_3_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1205] = (idx = 2653, label = "xf_5092_to_5226_3A_2winding_transformer", type = "branch")
    data["branch_contingencies"][1206] = (idx = 754, label = "line_3163_to_3635_1_cp", type = "branch")
    data["branch_contingencies"][1207] = (idx = 259, label = "line_1226_to_1322_1_cp", type = "branch")
    data["branch_contingencies"][1208] = (idx = 1809, label = "xf_2146_to_2250_8_2winding_transformer", type = "branch")
    data["branch_contingencies"][1209] = (idx = 207, label = "line_1200_to_1333_1_cp", type = "branch")
    data["branch_contingencies"][1210] = (idx = 47, label = "line_1105_to_1140_1_cp", type = "branch")
    data["branch_contingencies"][1211] = (idx = 238, label = "line_1215_to_1320_1_cp", type = "branch")
    data["branch_contingencies"][1212] = (idx = 1283, label = "line_5101_to_5102_2_cp", type = "branch")
    data["branch_contingencies"][1213] = (idx = 1201, label = "line_4312_to_4313_1_cp", type = "branch")
    data["branch_contingencies"][1214] = (idx = 158, label = "line_1185_to_1468_1_cp", type = "branch")
    data["branch_contingencies"][1215] = (idx = 229, label = "line_1207_to_1473_1_cp", type = "branch")
    data["branch_contingencies"][1216] = (idx = 398, label = "line_1401_to_1425_1_cp", type = "branch")
    data["branch_contingencies"][1217] = (idx = 769, label = "line_3184_to_3263_1_cp", type = "branch")
    data["branch_contingencies"][1218] = (idx = 1269, label = "line_5090_to_5103_1_cp", type = "branch")
    data["branch_contingencies"][1219] = (idx = 557, label = "line_2213_to_2216_1_cp", type = "branch")
    data["branch_contingencies"][1220] = (idx = 1219, label = "line_5049_to_5053_1_cp", type = "branch")
    data["branch_contingencies"][1221] = (idx = 2138, label = "xf_3390_to_3392_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1222] = (idx = 1029, label = "line_4091_to_4320_1_cp", type = "branch")
    data["branch_contingencies"][1223] = (idx = 2936, label = "xf_3358_3360_3361_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1224] = (idx = 122, label = "line_1166_to_1300_1_cp", type = "branch")
    data["branch_contingencies"][1225] = (idx = 2048, label = "xf_3158_to_3440_3_2winding_transformer", type = "branch")
    data["branch_contingencies"][1226] = (idx = 2766, label = "xf_1099_1100_1533_9_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1227] = (idx = 2071, label = "xf_3196_to_3197_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1228] = (idx = 1098, label = "line_4192_to_4194_1_cp", type = "branch")
    data["branch_contingencies"][1229] = (idx = 616, label = "line_3023_to_3114_1_cp", type = "branch")
    data["branch_contingencies"][1230] = (idx = 1000, label = "line_3598_to_3608_1_cp", type = "branch")
    data["branch_contingencies"][1231] = (idx = 2172, label = "xf_3481_to_3479_4_2winding_transformer_merged_with_line_3314_to_3481_2_cp", type = "branch")
    data["branch_contingencies"][1232] = (idx = 1794, label = "xf_2139_to_2089_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1233] = (idx = 601, label = "line_3010_to_3174_1_cp", type = "branch")
    data["branch_contingencies"][1234] = (idx = 1274, label = "line_5092_to_5095_2_cp", type = "branch")
    data["branch_contingencies"][1235] = (idx = 568, label = "line_2225_to_2226_1_cp", type = "branch")
    data["branch_contingencies"][1236] = (idx = 309, label = "line_1288_to_1294_1_cp", type = "branch")
    data["branch_contingencies"][1237] = (idx = 930, label = "line_3545_to_3593_1_cp", type = "branch")
    data["branch_contingencies"][1238] = (idx = 2666, label = "xf_5105_to_5211_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1239] = (idx = 2176, label = "xf_3490_to_3563_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1240] = (idx = 2077, label = "xf_3204_to_3206_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1241] = (idx = 688, label = "line_3096_to_3198_1_cp", type = "branch")
    data["branch_contingencies"][1242] = (idx = 699, label = "line_3102_to_3634_1_cp", type = "branch")
    data["branch_contingencies"][1243] = (idx = 3049, label = "xf_4220_4074_4499_5_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1244] = (idx = 1401, label = "Dec6_line_4124_to_4143_1_dec", type = "branch")
    data["branch_contingencies"][1245] = (idx = 968, label = "line_3563_to_3652_2_cp", type = "branch")
    data["branch_contingencies"][1246] = (idx = 322, label = "line_1302_to_1424_1_cp", type = "branch")
    data["branch_contingencies"][1247] = (idx = 1111, label = "line_4211_to_4212_1_cp", type = "branch")
    data["branch_contingencies"][1248] = (idx = 663, label = "line_3068_to_3259_1_cp", type = "branch")
    data["branch_contingencies"][1249] = (idx = 1154, label = "line_4260_to_4265_1_cp", type = "branch")
    data["branch_contingencies"][1250] = (idx = 3009, label = "xf_4104_4039_4040_1_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1251] = (idx = 1055, label = "line_4132_to_4343_1_cp", type = "branch")
    data["branch_contingencies"][1252] = (idx = 3057, label = "xf_4257_4379_4434_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1253] = (idx = 2194, label = "xf_3518_to_3591_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1254] = (idx = 2712, label = "xf_5152_to_5014_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][1255] = (idx = 1891, label = "xf_2202_to_2042_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1256] = (idx = 820, label = "line_3263_to_3530_2_cp", type = "branch")
    data["branch_contingencies"][1257] = (idx = 2826, label = "xf_1587_1328_1067_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1258] = (idx = 1484, label = "xf_1124_to_1552_4_2winding_transformer", type = "branch")
    data["branch_contingencies"][1259] = (idx = 2907, label = "xf_3226_3227_3228_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1260] = (idx = 541, label = "line_2201_to_2207_1_cp", type = "branch")
    data["branch_contingencies"][1261] = (idx = 298, label = "line_1275_to_1349_1_cp", type = "branch")
    data["branch_contingencies"][1262] = (idx = 985, label = "line_3573_to_3598_1_cp", type = "branch")
    data["branch_contingencies"][1263] = (idx = 689, label = "line_3096_to_3199_2_cp", type = "branch")
    data["branch_contingencies"][1264] = (idx = 512, label = "line_2163_to_2181_1_cp", type = "branch")
    data["branch_contingencies"][1265] = (idx = 1390, label = "Dec21_line_4233_to_4236_1_dec", type = "branch")
    data["branch_contingencies"][1266] = (idx = 1026, label = "line_4071_to_4324_1_cp", type = "branch")
    data["branch_contingencies"][1267] = (idx = 210, label = "line_1203_to_1380_1_cp", type = "branch")
    data["branch_contingencies"][1268] = (idx = 2877, label = "xf_2191_2031_2022_5_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1269] = (idx = 133, label = "line_1169_to_1528_2_cp", type = "branch")
    data["branch_contingencies"][1270] = (idx = 2788, label = "xf_1121_1123_1635_7_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1271] = (idx = 2939, label = "xf_3359_3360_3361_2_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1272] = (idx = 2854, label = "xf_2162_2271_2315_5_3winding_transformer_br1", type = "branch")
    data["branch_contingencies"][1273] = (idx = 1275, label = "line_5095_to_5100_1_cp", type = "branch")
    data["branch_contingencies"][1274] = (idx = 290, label = "line_1261_to_1438_1_cp", type = "branch")
    data["branch_contingencies"][1275] = (idx = 2806, label = "xf_1273_1572_1573_2_3winding_transformer_br3", type = "branch")
    data["branch_contingencies"][1276] = (idx = 114, label = "line_1164_to_1273_1_cp", type = "branch")
    data["branch_contingencies"][1277] = (idx = 31, label = "line_1099_to_1121_1_cp", type = "branch")
    data["branch_contingencies"][1278] = (idx = 274, label = "line_1241_to_1431_1_cp", type = "branch")
    data["branch_contingencies"][1279] = (idx = 1975, label = "xf_3044_to_3046_1_2winding_transformer", type = "branch")
    data["branch_contingencies"][1280] = (idx = 310, label = "line_1288_to_1306_1_cp", type = "branch")
    data["branch_contingencies"][1281] = (idx = 946, label = "line_3557_to_3558_1_cp", type = "branch")
    data["branch_contingencies"][1282] = (idx = 1324, label = "line_5160_to_5162_1_cp", type = "branch")
    data["branch_contingencies"][1283] = (idx = 1197, label = "line_4311_to_4312_1_cp", type = "branch")
    data["branch_contingencies"][1284] = (idx = 1042, label = "line_4110_to_4115_1_cp", type = "branch")
    data["branch_contingencies"][1285] = (idx = 2041, label = "xf_3141_to_3142_2_2winding_transformer", type = "branch")
    data["branch_contingencies"][1286] = (idx = 338, label = "line_1326_to_1391_1_cp", type = "branch")
    data["branch_contingencies"][1287] = (idx = 198, label = "line_1199_to_1229_1_cp", type = "branch")
    data["branch_contingencies"][1288] = (idx = 1234, label = "line_5061_to_5063_2_cp", type = "branch")
    data["branch_contingencies"][1289] = (idx = 2957, label = "xf_3379_3380_3381_3_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1290] = (idx = 1006, label = "line_3607_to_3615_1_cp", type = "branch")
    data["branch_contingencies"][1291] = (idx = 348, label = "line_1334_to_1447_1_cp", type = "branch")
    data["branch_contingencies"][1292] = (idx = 3028, label = "xf_4160_4097_4401_1_3winding_transformer_br2", type = "branch")
    data["branch_contingencies"][1293] = (idx = 732, label = "line_3142_to_3310_1_cp", type = "branch")

    # Add branchdc contingencies
    data["branchdc_contingencies"] = Vector{Any}(undef, 5)
    data["branchdc_contingencies"][1] = (idx = 1, label = "BASS_HVDC", type = "branchdc")
    data["branchdc_contingencies"][2] = (idx = 2, label = "TERRANORA_HVDC_1", type = "branchdc")
    data["branchdc_contingencies"][3] = (idx = 3, label = "TERRANORA_HVDC_2", type = "branchdc")
    data["branchdc_contingencies"][4] = (idx = 4, label = "TERRANORA_HVDC_3", type = "branchdc")
    data["branchdc_contingencies"][5] = (idx = 5, label = "MURRAY_HVDC", type = "branchdc")
    # data["branchdc_contingencies"][6] = (idx = 6, label = "HVDC_1", type = "branchdc")
    # data["branchdc_contingencies"][7] = (idx = 7, label = "HVDC_2", type = "branchdc")
    # data["branchdc_contingencies"][8] = (idx = 8, label = "HVDC_3", type = "branchdc")
    # data["branchdc_contingencies"][9] = (idx = 9, label = "HVDC_4", type = "branchdc")
    # data["branchdc_contingencies"][10] = (idx = 10, label = "HVDC_5", type = "branchdc")
    
    # Add convdc contingencies
    data["convdc_contingencies"] = []
    data["convdc_contingencies"] = Vector{Any}(undef, 6)
    data["convdc_contingencies"][1] = (idx = 1, label = "BASS_Conv_1", type = "convdc")
    data["convdc_contingencies"][2] = (idx = 2, label = "BASS_Conv_2", type = "convdc")
    data["convdc_contingencies"][3] = (idx = 3, label = "TERRANORA_MM_Conv_1", type = "convdc")
    data["convdc_contingencies"][4] = (idx = 4, label = "TERRANORA_MM_Conv_2", type = "convdc")
    data["convdc_contingencies"][5] = (idx = 5, label = "MURRAY_Conv_1", type = "convdc")
    data["convdc_contingencies"][6] = (idx = 6, label = "MURRAY_Conv_2", type = "convdc")

    return data
end

function split_large_coal_powerplants_to_units!(data)
    split_generators = []
    for (i,gen) in data["gen"]
        if gen["fuel"] == "Coal" && gen["pmax"] > 5.0
            push!(split_generators, i)
        end
    end
    index_new =  length(data["gen"]) + 1 : length(data["gen"]) + length(split_generators)
    new_gen_pairs =[]
    for i in eachindex(split_generators)  
        push!(new_gen_pairs, (index_new[i],split_generators[i]))
    end
    for (i,j) in new_gen_pairs
        data["gen"]["$i"] = deepcopy(data["gen"]["$j"])
        data["gen"]["$i"]["Ramp_Up_Rate(MW/h)"]     = data["gen"]["$i"]["Ramp_Up_Rate(MW/h)"]/2
        data["gen"]["$i"]["mbase"]                  = data["gen"]["$i"]["mbase"]/2
        data["gen"]["$i"]["qmax"]                   = data["gen"]["$i"]["qmax"]/2
        data["gen"]["$i"]["Ramp_Down_Rate(MW/h)"]   = data["gen"]["$i"]["Ramp_Down_Rate(MW/h)"]/2
        data["gen"]["$i"]["qmin"]                   = data["gen"]["$i"]["qmin"]/2
        data["gen"]["$i"]["pmin"]                   = data["gen"]["$i"]["pmin"]/2
        data["gen"]["$i"]["qg"]                     = data["gen"]["$i"]["qg"]/2
        data["gen"]["$i"]["source_id"]              = Any["gen", i]
        data["gen"]["$i"]["index"]                  = i
        data["gen"]["$i"]["pg"]                     = data["gen"]["$i"]["pg"]/2
        data["gen"]["$i"]["pmax"]                   = data["gen"]["$i"]["pmax"]/2
    
        data["gen"]["$j"]["Ramp_Up_Rate(MW/h)"]     = data["gen"]["$j"]["Ramp_Up_Rate(MW/h)"]/2
        data["gen"]["$j"]["mbase"]                  = data["gen"]["$j"]["mbase"]/2
        data["gen"]["$j"]["qmax"]                   = data["gen"]["$j"]["qmax"]/2
        data["gen"]["$j"]["Ramp_Down_Rate(MW/h)"]   = data["gen"]["$j"]["Ramp_Down_Rate(MW/h)"]/2
        data["gen"]["$j"]["qmin"]                   = data["gen"]["$j"]["qmin"]/2
        data["gen"]["$j"]["pmin"]                   = data["gen"]["$j"]["pmin"]/2
        data["gen"]["$j"]["qg"]                     = data["gen"]["$j"]["qg"]/2
        data["gen"]["$j"]["pg"]                     = data["gen"]["$j"]["pg"]/2
        data["gen"]["$j"]["pmax"]                   = data["gen"]["$j"]["pmax"]/2
    end
    return data
end

function fix_scopf_data_case5_acdc!(data)

    idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
    idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
    idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
    idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
    labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

    data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
    data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
    data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
    data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]


    data["area_gens"] = Dict{Int64, Set{Int64}}()
    data["area_gens"][1] = Set([2, 1])

    data["contingencies"] = []  # This to empty the existing contingencies in the data

    for i=1:length(data["gen"])
        data["gen"]["$i"]["ep"] = 1e-1
    end

    for i=1:length(data["convdc"])
        data["convdc"]["$i"]["ep"] = 1e-3
    end

    for i=1:length(data["convdc"])
        data["convdc"]["$i"]["ep"] = 1e-1
    end

    data["gen"]["1"]["alpha"] = 15.92 
    data["gen"]["2"]["alpha"] = 11.09 

    for i=1:length(data["branch"])
        data["branch"]["$i"]["tm_min"] = 0.9
        data["branch"]["$i"]["tm_max"] = 1.1
        data["branch"]["$i"]["ta_min"] = -15
        data["branch"]["$i"]["ta_max"] = 15
    end
    return data
end

function fix_scopf_data_case5_2grids_acdc!(data)
    fix_scopf_data_case5_acdc!(data)
    data["area_gens"][2] = Set([4, 3])
    data["gen"]["3"]["alpha"] = 15.92 
    data["gen"]["4"]["alpha"] = 11.09 
    return data
end


function fix_scopf_data_case24_3zones_acdc!(data)

    idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
    idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
    idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
    idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
    labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

    data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
    data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
    data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
    data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]

    data["area_gens"] = Dict{Int64, Set{Int64}}()
    data["area_gens"][11] = Set{Int64}()
    data["area_gens"][12] = Set{Int64}()
    data["area_gens"][13] = Set{Int64}()
    data["area_gens"][14] = Set{Int64}()

    for (i,gen) in data["gen"]
        bus_id = gen["gen_bus"]
        if data["bus"]["$bus_id"]["area"] == 11
            push!(data["area_gens"][11], parse(Int64, i))
        elseif data["bus"]["$bus_id"]["area"] == 12
            push!(data["area_gens"][12], parse(Int64, i))
        elseif data["bus"]["$bus_id"]["area"] == 13
            push!(data["area_gens"][13], parse(Int64, i))
        elseif data["bus"]["$bus_id"]["area"] == 14
            push!(data["area_gens"][14], parse(Int64, i))
        end
    end

    data["contingencies"] = []  # This to empty the existing contingencies in the data

    for i=1:length(data["gen"])
        data["gen"]["$i"]["ep"] = 1e-1
        data["gen"]["$i"]["alpha"] = 15.92 
    end

    for i=1:length(data["convdc"])
        data["convdc"]["$i"]["ep"] = 1e-1
    end

    for i=1:length(data["convdc"])
        data["convdc"]["$i"]["ep"] = 1e-1
        data["convdc"]["$i"]["Vdclow"] = 0.98
        data["convdc"]["$i"]["Vdchigh"] = 1.02
    end

    for i=1:length(data["branch"])
        data["branch"]["$i"]["tm_min"] = 0.9
        data["branch"]["$i"]["tm_max"] = 1.1
        data["branch"]["$i"]["ta_min"] = -15
        data["branch"]["$i"]["ta_max"] = 15
        
        data["branch"]["$i"]["rate_b"] = data["branch"]["$i"]["rate_c"] = data["branch"]["$i"]["rate_a"]
    end
    return data
end

function fix_scopf_data_case67_acdc!(data)
    
    idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
    idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
    idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
    idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
    labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

    data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
    data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
    data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
    data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]

    data["area_gens"] = Dict{Int64, Set{Int64}}()
    data["area_gens"][1] = Set([8, 7, 6, 5, 4, 3, 2, 1])
    data["area_gens"][2] = Set([14, 13, 12, 11, 10, 9])
    data["area_gens"][3] = Set([19, 18, 17, 16, 15])
    data["area_gens"][4] = Set([20])

    data["contingencies"] = []  # This to empty the existing contingencies in the data

    data["gen"]["1"]["alpha"] = 16.825
    data["gen"]["2"]["alpha"] = 4.48667
    data["gen"]["3"]["alpha"] = 30.5909 
    data["gen"]["4"]["alpha"] = 5.60833
    data["gen"]["5"]["alpha"] = 30.5909
    data["gen"]["6"]["alpha"] = 26.92
    data["gen"]["7"]["alpha"] = 22.4333
    data["gen"]["8"]["alpha"] = 15.7216
    data["gen"]["9"]["alpha"] = 7.12698
    data["gen"]["10"]["alpha"] = 5.28235
    data["gen"]["11"]["alpha"] = 6.23611
    data["gen"]["12"]["alpha"] = 5.51586
    data["gen"]["13"]["alpha"] = 6.23611
    data["gen"]["14"]["alpha"] = 6.23611
    data["gen"]["15"]["alpha"] = 5.33929
    data["gen"]["16"]["alpha"] = 4.15278 
    data["gen"]["17"]["alpha"] = 5.75
    data["gen"]["18"]["alpha"] = 7.44349
    data["gen"]["19"]["alpha"] = 4.74603
    data["gen"]["20"]["alpha"] = 1

    for i=1:length(data["gen"])
        data["gen"]["$i"]["ep"] = 1e-1
    end

    for i=1:length(data["convdc"])
        data["convdc"]["$i"]["ep"] = 1e-1
        data["convdc"]["$i"]["Vdclow"] = 0.98
        data["convdc"]["$i"]["Vdchigh"] = 1.02
    end

    for i=1:length(data["branch"])
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
    return data
end

function fix_scopf_data_case500_acdc!(data)

    data["contingencies"] = []  # This to empty the existing contingencies in the data
    data["dcline"]=Dict{String, Any}()

    for i=1:length(data["gen"])
        data["gen"]["$i"]["ep"] = 1e-1
    end

    for i=1:length(data["branch"])
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


    data["dcpol"] = 2
    data["busdc"] = Dict{String, Any}()
    data["busdc"]["1"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 1], "area"=>1, "busdc_i"=>1, "grid"=>1, "index"=>1, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["2"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 2], "area"=>1, "busdc_i"=>2, "grid"=>1, "index"=>2, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["3"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 3], "area"=>1, "busdc_i"=>3, "grid"=>1, "index"=>3, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["4"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 4], "area"=>1, "busdc_i"=>4, "grid"=>1, "index"=>4, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["5"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 5], "area"=>1, "busdc_i"=>5, "grid"=>1, "index"=>5, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["6"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 6], "area"=>1, "busdc_i"=>6, "grid"=>1, "index"=>6, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["7"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 7], "area"=>1, "busdc_i"=>7, "grid"=>1, "index"=>7, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["8"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 8], "area"=>1, "busdc_i"=>8, "grid"=>1, "index"=>8, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["9"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 9], "area"=>1, "busdc_i"=>9, "grid"=>1, "index"=>9, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)
    data["busdc"]["10"] = Dict{String, Any}("Vdc"=>1, "Cdc"=>0, "basekVdc"=>345, "source_id"=>Any["busdc", 10], "area"=>1, "busdc_i"=>10, "grid"=>1, "index"=>10, "Vdcmax"=>1.1, "Vdcmin"=>0.9, "Pdc" => 0)


    data["branchdc"] = Dict{String, Any}()
    data["branchdc"]["1"] = Dict{String, Any}("c"=>0, "r"=>0.052,"status"=>1, "rateB"=>100, "fbusdc"=>1, "source_id"=>Any["branchdc", 1], "rateA"=>100, "l"=>0, "index"=>1, "rateC"=>100, "tbusdc" => 2)
    data["branchdc"]["2"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>2, "source_id"=>Any["branchdc", 2], "rateA"=>100, "l"=>0, "index"=>2, "rateC"=>100, "tbusdc" => 3)
    data["branchdc"]["3"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>1, "source_id"=>Any["branchdc", 3], "rateA"=>100, "l"=>0, "index"=>3, "rateC"=>100, "tbusdc" => 4)
    data["branchdc"]["4"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>2, "source_id"=>Any["branchdc", 4], "rateA"=>100, "l"=>0, "index"=>4, "rateC"=>100, "tbusdc" => 4)
    data["branchdc"]["5"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>2, "source_id"=>Any["branchdc", 5], "rateA"=>100, "l"=>0, "index"=>5, "rateC"=>100, "tbusdc" => 4)
    data["branchdc"]["6"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>1, "source_id"=>Any["branchdc", 6], "rateA"=>100, "l"=>0, "index"=>6, "rateC"=>100, "tbusdc" => 5)
    data["branchdc"]["7"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>5, "source_id"=>Any["branchdc", 7], "rateA"=>100, "l"=>0, "index"=>7, "rateC"=>100, "tbusdc" => 6)
    data["branchdc"]["8"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>5, "source_id"=>Any["branchdc", 8], "rateA"=>100, "l"=>0, "index"=>8, "rateC"=>100, "tbusdc" => 7)
    data["branchdc"]["9"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>7, "source_id"=>Any["branchdc", 9], "rateA"=>100, "l"=>0, "index"=>9, "rateC"=>100, "tbusdc" => 4)
    data["branchdc"]["10"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>4, "source_id"=>Any["branchdc", 10], "rateA"=>100, "l"=>0, "index"=>10, "rateC"=>100, "tbusdc" => 8)
    data["branchdc"]["11"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>8, "source_id"=>Any["branchdc", 11], "rateA"=>100, "l"=>0, "index"=>11, "rateC"=>100, "tbusdc" => 9)
    data["branchdc"]["12"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>8, "source_id"=>Any["branchdc", 12], "rateA"=>100, "l"=>0, "index"=>12, "rateC"=>100, "tbusdc" => 10)
    data["branchdc"]["13"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>3, "source_id"=>Any["branchdc", 13], "rateA"=>100, "l"=>0, "index"=>13, "rateC"=>100, "tbusdc" => 10)
    data["branchdc"]["14"] = Dict{String, Any}("c"=>0, "r"=>0.052, "status"=>1, "rateB"=>100, "fbusdc"=>6, "source_id"=>Any["branchdc", 14], "rateA"=>100, "l"=>0, "index"=>14, "rateC"=>100, "tbusdc" => 9)

    data["convdc"]=Dict{String, Any}()
    data["convdc"]["1"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 1], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 1, "busac_i" => 7, "tm" => 1, "type_dc" => 2, "Q_g" => 0, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 1, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => 0, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["2"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 2], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 2, "busac_i" => 14, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 2, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["3"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 3], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 3, "busac_i" => 23, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 3, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["4"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 4], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 4, "busac_i" => 39, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 4, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["5"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 5], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 5, "busac_i" => 57, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 5, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["6"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 6], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 6, "busac_i" => 65, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 6, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["7"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 7], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 7, "busac_i" => 80, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 7, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["8"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 8], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 8, "busac_i" => 123, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 8, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["9"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 9], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 9, "busac_i" => 146, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 9, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)
    data["convdc"]["10"] = Dict{String, Any}("dVdcset" => 0, "Vtar" => 1, "Pacmax" => 100, "filter" => 0, "reactor" => 0, "Vdcset" => 1.0079, "Vmmax" => 1.1, "xtf" => 0.01, "Imax" => 1.1, "status" => 1, "Pdcset" => -58.6274, "islcc" => 0, "LossA" => 1.1033, "Qacmin" => -100, "rc" => 0.01, "source_id" => Any["convdc", 10], "rtf" => 0.01, "xc" => 0.01, "busdc_i" => 10, "busac_i" => 151, "tm" => 1, "type_dc" => 3, "Q_g" => -40, "LossB" => 0.887, "basekVac" => 345, "LossCrec" => 2.885, "droop" => 0.005, "Pacmin" => -100, "Qacmax" => 100, "index" => 10, "type_ac" => 1, "Vmmin" => 0.9, "P_g" => -60, "transformer" => 0, "bf" => 0.01, "LossCinv" => 2.885)


    for i=1:length(data["convdc"])
        data["convdc"]["$i"]["ep"] = 1e-1
        data["convdc"]["$i"]["Vdclow"] = 0.98
        data["convdc"]["$i"]["Vdchigh"] = 1.02
    end

    data["branchdc_contingencies"] = Vector{Any}(undef, 14)
    data["branchdc_contingencies"][1] = (idx = 1, label = "branchdc_1", type = "branchdc")
    data["branchdc_contingencies"][2] = (idx = 1, label = "branchdc_2", type = "branchdc")
    data["branchdc_contingencies"][3] = (idx = 1, label = "branchdc_3", type = "branchdc")
    data["branchdc_contingencies"][4] = (idx = 1, label = "branchdc_4", type = "branchdc")
    data["branchdc_contingencies"][5] = (idx = 1, label = "branchdc_5", type = "branchdc")
    data["branchdc_contingencies"][6] = (idx = 1, label = "branchdc_6", type = "branchdc")
    data["branchdc_contingencies"][7] = (idx = 1, label = "branchdc_7", type = "branchdc")
    data["branchdc_contingencies"][8] = (idx = 1, label = "branchdc_8", type = "branchdc")
    data["branchdc_contingencies"][9] = (idx = 1, label = "branchdc_9", type = "branchdc")
    data["branchdc_contingencies"][10] = (idx = 1, label = "branchdc_10", type = "branchdc")
    data["branchdc_contingencies"][11] = (idx = 1, label = "branchdc_11", type = "branchdc")
    data["branchdc_contingencies"][12] = (idx = 1, label = "branchdc_12", type = "branchdc")
    data["branchdc_contingencies"][13] = (idx = 1, label = "branchdc_13", type = "branchdc")
    data["branchdc_contingencies"][14] = (idx = 1, label = "branchdc_14", type = "branchdc")

    data["convdc_contingencies"] = []
    data["convdc_contingencies"] = Vector{Any}(undef, 10)
    data["convdc_contingencies"][1] = (idx = 1, label = "Conv_1", type = "convdc")
    data["convdc_contingencies"][2] = (idx = 2, label = "Conv_2", type = "convdc")
    data["convdc_contingencies"][3] = (idx = 3, label = "Conv_3", type = "convdc")
    data["convdc_contingencies"][4] = (idx = 4, label = "Conv_4", type = "convdc")
    data["convdc_contingencies"][5] = (idx = 5, label = "Conv_5", type = "convdc")
    data["convdc_contingencies"][6] = (idx = 6, label = "Conv_6", type = "convdc")
    data["convdc_contingencies"][7] = (idx = 7, label = "Conv_7", type = "convdc")
    data["convdc_contingencies"][8] = (idx = 8, label = "Conv_8", type = "convdc")
    data["convdc_contingencies"][9] = (idx = 9, label = "Conv_9", type = "convdc")
    data["convdc_contingencies"][10] = (idx = 10, label = "Conv_10", type = "convdc")

    return data
end


# FCAS

const gen_fcas_columns = [
    ("gen", Int),
    ("service", Int),
    ("emin", Float64),
    ("lb", Float64),
    ("ub", Float64),
    ("emax", Float64),
    ("amax", Float64)
]

const load_fcas_columns = [
    ("load", Int),
    ("service", Int),
    ("emin", Float64),
    ("lb", Float64),
    ("ub", Float64),
    ("emax", Float64),
    ("amax", Float64)
]

const _fcas_target_columns = [
    ("service", Int),
    ("p", Float64)
]

const _load_limit_columns = [
    ("load", Int),
    ("Pmax", Float64),
    ("Pmin", Float64)
]

const mlf_columns = [
    ("bus", Int),
    ("p", Float64),
    ("mlf", Float64),
    ("loss", Float64)
]

"""
    process_scenario_data!(data, scenario)

Extends the standard MatPower case format with additional gencost, loadcost and fcas
data. This data is only loaded if the extended data files exist.
"""
function process_scenario_data!(data::Dict, scenario::String)
    fcas_file = "./test/data/nem_market/$(scenario)/fcas.m"
    if isfile(fcas_file)
        scenario_fcas = _IM.parse_matlab_file(fcas_file)

        if haskey(scenario_fcas, "mpc.fcas_gen")
            fcas = []
            for (i, row) in enumerate(scenario_fcas["mpc.fcas_gen"])
                row_data = _IM.row_to_typed_dict(row, gen_fcas_columns)
                row_data["index"] = i
                row_data["source_id"] = ["fcas_gen", i]
                push!(fcas, row_data)
            end
            data["fcas_gen"] = fcas
        end

        if haskey(scenario_fcas, "mpc.fcas_load")
            fcas = []
            for (i, row) in enumerate(scenario_fcas["mpc.fcas_load"])
                row_data = _IM.row_to_typed_dict(row, load_fcas_columns)
                row_data["index"] = i
                row_data["source_id"] = ["fcas_load", i]
                push!(fcas, row_data)
            end
            data["fcas_load"] = fcas
        end

        if haskey(scenario_fcas, "mpc.fcas_cost_gen")
            fcas = []
            for (i, row) in enumerate(scenario_fcas["mpc.fcas_cost_gen"])
                row_data = map_fcas_cost_data(row)
                row_data["index"] = i
                row_data["source_id"] = ["fcas_cost_gen", i]
                push!(fcas, row_data)
            end
            data["fcas_cost_gen"] = fcas
        end

        if haskey(scenario_fcas, "mpc.fcas_cost_load")
            fcas = []
            for (i, row) in enumerate(scenario_fcas["mpc.fcas_cost_load"])
                row_data = map_fcas_cost_data(row)
                row_data["index"] = i
                row_data["source_id"] = ["fcas_cost_load", i]
                push!(fcas, row_data)
            end
            data["fcas_cost_load"] = fcas
        end

        if haskey(scenario_fcas, "mpc.fcas_target")
            fcas = []
            for (i, row) in enumerate(scenario_fcas["mpc.fcas_target"])
                row_data = _IM.row_to_typed_dict(row, _fcas_target_columns)
                row_data["index"] = i
                row_data["source_id"] = ["fcas_target", i]
                push!(fcas, row_data)
            end
            data["fcas_target"] = fcas
        end
    end

    gencost_file = "./test/data/nem_market/$(scenario)/gencost.m"
    if isfile(gencost_file)
        scenario_gen_cost = _IM.parse_matlab_file(gencost_file)

        if haskey(scenario_gen_cost, "mpc.gencost")
            cost = []
            for (i, row) in enumerate(scenario_gen_cost["mpc.gencost"])
                row_data = map_cost_data(row)
                row_data["index"] = i
                row_data["source_id"] = ["gencost", i]
                push!(cost, row_data)
            end
            data["gen_cost"] = cost
        end
    end

    loadcost_file = "./test/data/nem_market/$(scenario)/loadcost.m"
    if isfile(loadcost_file)
        scenario_load_cost = _IM.parse_matlab_file(loadcost_file)

        if haskey(scenario_load_cost, "mpc.load_limit")
            limit = []
            for (i, row) in enumerate(scenario_load_cost["mpc.load_limit"])
                row_data = _IM.row_to_typed_dict(row, _load_limit_columns)
                row_data["index"] = i
                row_data["source_id"] = ["load_limit", i]
                push!(limit, row_data)
            end
            data["load_limit"] = limit
        end

        if haskey(scenario_load_cost, "mpc.loadcost")
            cost = []
            for (i, row) in enumerate(scenario_load_cost["mpc.loadcost"])
                row_data = map_cost_data(row)
                row_data["index"] = i
                row_data["source_id"] = ["loadcost", i]
                push!(cost, row_data)
            end
            data["load_cost"] = cost
        end
    end

    mlf_file = "./test/data/nem_market/$(scenario)/mlf.m"
    if isfile(mlf_file)
        scenario_mlf = _IM.parse_matlab_file(mlf_file)

        if haskey(scenario_mlf, "mpc.bus_mlf")
            mlf = []
            for (i, row) in enumerate(scenario_mlf["mpc.bus_mlf"])
                row_data = _IM.row_to_typed_dict(row, mlf_columns)
                row_data["index"] = i
                row_data["source_id"] = ["bus_mlf", i]
                push!(mlf, row_data)
            end
            data["mlf"] = mlf
        end
    end

    merge_cost_data!(data)
    merge_load_limit_data!(data)
    merge_fcas_data!(data)
    merge_fcas_cost_data!(data)
end

"""
    map_cost_data(cost_row) 

Cost data in a MatPower file does not have column names due to the variable width of the 
cost data. This function converts the parsed MatPower cost data and maps it to a standard
cost data dictionary format.
"""
function map_cost_data(cost_row)
    ncost = _IM.check_type(Int, cost_row[4])
    model = _IM.check_type(Int, cost_row[1])

    if model == 1
        nr_parameters = ncost * 2
    elseif model == 2
        nr_parameters = ncost
    end

    cost_data = Dict(
        "model" => model,
        "startup" => _IM.check_type(Float64, cost_row[2]),
        "shutdown" => _IM.check_type(Float64, cost_row[3]),
        "ncost" => ncost,
        "cost" => [_IM.check_type(Float64, cost_row[x]) for x in 5:5+nr_parameters-1]
    )

    return cost_data
end

"""
    map_fcas_cost_data(cost_row) 

Cost data in a MatPower file does not have column names due to the variable width of the 
cost data. This function converts the parsed MatPower cost data and maps it to fcas
cost data dictionary format.
"""
function map_fcas_cost_data(cost_row)
    participant = _IM.check_type(Int, cost_row[1])
    service = _IM.check_type(Int, cost_row[2])
    ncost = _IM.check_type(Int, cost_row[3])

    nr_parameters = ncost * 2

    cost_data = Dict(
        "participant" => participant,
        "service" => service,
        "ncost" => ncost,
        "cost" => [_IM.check_type(Float64, cost_row[x]) for x in 4:4+nr_parameters-1]
    )

    return cost_data
end

"""
    merge_cost_data!(cost_row) 

Converts cost quantity values to p.u and merges the data with the gen/load dictionaries
"""
function merge_cost_data!(data::Dict{String,Any})
    if haskey(data, "gen_cost")
        gen = data["gen"]
        gen_cost = data["gen_cost"]

        if length(gen) != length(gen_cost)
            if length(gen_cost) > length(gen)
                Memento.warn(_LOGGER, "The last $(length(gen_cost) - length(gen)) gen offer records will be ignored due to too few gen records.")
                gen_cost = gen_cost[1:length(gen)]
            else
                Memento.warn(_LOGGER, "The number of generators ($(length(gen))) does not match the number of generator offer records ($(length(gen_cost))).")
            end
        end

        MVAbase = data["baseMVA"]
        cost_pu!(gen_cost, MVAbase)

        for (i, gc) in enumerate(gen_cost)
            g = gen["$(i)"]
            merge!(g, gc)
        end

        delete!(data, "gen_cost")
    end

    if haskey(data, "load_cost")
        load = data["load"]
        load_cost = data["load_cost"]

        if length(load) != length(load_cost)
            if length(load_cost) > length(load)
                Memento.warn(_LOGGER, "The last $(length(load_cost) - length(load)) load bid records will be ignored due to too few load records.")
                gen_cost = gen_cost[1:length(gen)]
            else
                Memento.warn(_LOGGER, "The number of loads ($(length(load))) does not match the number of load bid records ($(length(load_cost))).")
            end
        end

        MVAbase = data["baseMVA"]
        cost_pu!(load_cost, MVAbase)

        for (i, lc) in enumerate(load_cost)
            l = load["$(i)"]
            merge!(l, lc)
        end

        delete!(data, "load_cost")
    end
end

"""
    merge_load_limit_data!(data)

Merges scheduled load limit data with the load data dictionary
"""
function merge_load_limit_data!(data)
    MVAbase = data["baseMVA"]
    rescale_power = x -> x / MVAbase

    if haskey(data, "load_limit")
        limits = data["load_limit"]
        for limit in values(limits)
            load = data["load"]["$(limit["load"])"]
            load["pmin"] = _PM._apply_func!(limit, "Pmin", rescale_power)
            load["pmax"] = _PM._apply_func!(limit, "Pmax", rescale_power)
        end
    end

end

"""
    merge_fcas_data!(data)

Merges fcas trapezium data with generator/load dictionaries
"""
function merge_fcas_data!(data)
    MVAbase = data["baseMVA"]


    if haskey(data, "fcas_gen")
        fcas_gen = data["fcas_gen"]
        for fcas_data in fcas_gen
            gen = data["gen"]["$(fcas_data["gen"])"]

            if !haskey(gen, "fcas")
                gen["fcas"] = Dict{Int,Any}()
            end

            set_fcas_pu!(fcas_data, MVAbase)
            calculate_slope_coefficients!(fcas_data)

            gen["fcas"][fcas_data["service"]] = fcas_data
        end
    end

    if haskey(data, "fcas_load")
        fcas_load = data["fcas_load"]
        for fcas_data in fcas_load
            load = data["load"]["$(fcas_data["load"])"]

            if !haskey(load, "fcas")
                load["fcas"] = Dict{Int,Any}()
            end

            set_fcas_pu!(fcas_data, MVAbase)
            calculate_slope_coefficients!(fcas_data)

            load["fcas"][fcas_data["service"]] = fcas_data
        end
    end

    if haskey(data, "fcas_target")
        targets = data["fcas_target"]
        for target in targets
            set_fcas_targets_pu!(target, MVAbase)
        end
    else
        data["fcas_target"] = Dict()
    end

end

function merge_fcas_cost_data!(data)
    if haskey(data, "fcas_cost_gen")
        merge_fcas_cost_data!(data, "fcas_cost_gen", "gen")
    end

    if haskey(data, "fcas_cost_load")
        merge_fcas_cost_data!(data, "fcas_cost_load", "load")
    end
end

"""
    merge_fcas_data!(data)

Merges fcas cost data with generator/load dictionaries
"""
function merge_fcas_cost_data!(data, name::String, participant_type::String)
    participants = data[participant_type]
    costs = data[name]

    MVAbase = data["baseMVA"]
    cost_pu!(costs, MVAbase)

    for (i, item) in participants
        participant_key = parse(Int, i)
        participant_costs = filter(p -> haskey(p, "participant") && p["participant"] == participant_key, collect(values(costs)))

        item["fcas_cost"] = Dict{Int,Dict}()
        for cost in participant_costs
            item["fcas_cost"][cost["service"]] = cost
            delete!(cost, "participant")
            delete!(cost, "service")
        end
    end

    delete!(data, name)
end

function set_fcas_pu!(data, MVAbase)
    rescale_power = x -> x / MVAbase

    _PM._apply_func!(data, "emin", rescale_power)
    _PM._apply_func!(data, "lb", rescale_power)
    _PM._apply_func!(data, "ub", rescale_power)
    _PM._apply_func!(data, "emax", rescale_power)
    _PM._apply_func!(data, "amax", rescale_power)
end

function set_fcas_targets_pu!(data, MVAbase)
    rescale_power = x -> x / MVAbase

    _PM._apply_func!(data, "p", rescale_power)
end

function cost_pu!(costs, MVAbase)
    for n in keys(costs)
        cost = costs[n]["cost"]
        for i in 1:2:length(cost)
            cost[i] = cost[i] / MVAbase
        end
    end
end

function calculate_slope_coefficients!(fcas)
    fcas["lower_slope"] = fcas["amax"] > 0.0 ? (fcas["lb"] - fcas["emin"]) / fcas["amax"] : 0.0
    fcas["upper_slope"] = fcas["amax"] > 0.0 ? (fcas["emax"] - fcas["ub"]) / fcas["amax"] : 0.0
end


"""
    get_dispatchable_participants(participants)

Returns only dispatchable participants (generators/loads)
"""
function get_dispatchable_participants(participants::Dict)
    return filter(x -> is_dispatchable(x[2]), participants)
end

"""
    is_dispatchable(participants)

Returns true if a participant is dispatchable
"""
function is_dispatchable(participant::Dict)
    return haskey(participant, "pmin") || haskey(participant, "pmax")
end




"""
    set_reference_bus(data, refs)

Set each bus in the refs argument as reference/slack buses

# Arguments
- `data::Dict{String, Any}`: The network data dictionary
- `refs::Vector{String}`: A list of references bus indexes
"""
function set_reference_bus(data, ref::String)
    area_data = deepcopy(data)

    for bus in [bus for (i, bus) in area_data["bus"] if bus["bus_type"] == 3]
        if bus["index"] != parse(Int, ref)
            bus["bus_type"] = 2
        end
    end

    # for ref in refs
    area_data["bus"][ref]["bus_type"] = 3
    gens = filter(x -> x[2]["gen_bus"] == parse(Int, ref), area_data["gen"])
    if isempty(gens)
        gen_count = length(area_data["gen"])
        area_data["gen"]["$(gen_count + 1)"] = Dict("index" => gen_count + 1, "gen_status" => 1, "gen_bus" => parse(Int, ref), "pg" => 0.0, "qg" => 0.0, "pmin" => 0.0, "pmax" => 0.0, "qmin" => 0.0, "qmax" => 0.0, "model" => 1, "ncost" => 2, "cost" => [10.0, 1.0, 10.0, 1.0])
    end
    # end

    return area_data
end


"""
    inject_load(extra_p, idx, ref, data, solver, setting)

Inject a small load at the bus specified by idx and measure the change in generation
at the reference bus specified by the ref argument
"""
function inject_load(extra_p::Float64, idx::String, ref::String, data, nlp_solver, setting)
    data_cp = deepcopy(data)
    load_count = length(keys(data_cp["load"]))

    i = parse(Int, idx)

    if extra_p > 0.0
        data_cp["load"]["$(load_count + 1)"] = Dict("index" => load_count + 1, "status" => 1, "load_bus" => i, "pd" => extra_p, "qd" => 0.0)
    end

    result = _PMACDC.run_acdcpf(data_cp, _PM.ACPPowerModel, nlp_solver, setting=setting)
    PowerModels.update_data!(data_cp, result["solution"])

    generation = get_slack_generation(ref, data_cp)
    return generation
end

"""
    finite_difference(fx, f, x, [h])

Used to estimate the change in a function (in this case the generation at the reference bus)
based on a change the input (in this case a small injection of power at a specified load)
"""
function finite_difference(fx, f, x, h=1e-6)
    fxh = f(x + h)
    df = (fxh - fx) / (h)
    return (fxh, df)
end

"""
    get_slack_generation(ref, data)

Calculates the change in generation at the reference bus specified by the ref argument.
"""
function get_slack_generation(ref::String, data)
    gens = filter(x -> x[2]["gen_bus"] == parse(Int, ref), data["gen"])
    # gens = filter(x -> data["bus"]["$(x[2]["gen_bus"])"]["bus_type"] == 3, data["gen"])
    return sum(x -> x[2]["pg"], gens)
end

"""
    export_mlfs(mlfs, scenario)

Generates a file in MatPower case format containing the calculated MLF values.

# Arguments
- `mlfs::Vector{Tuple{Float64,Float64}}`: List of power and mlf values for each node
- `scenario::String`: The scenario to store the MLF values against
"""
function export_mlfs(mlfs::Vector{Tuple{Float64,Float64}}, scenario::String)
    mlf_line(bus, values) = """
    $(bus)\t\
    $(values[1])\t\
    $(values[2]);\
    """

    lines = map(x -> mlf_line(x...), enumerate(mlfs))

    template = """
    %%-----  MLF Data  -----%%
    %column_names% 	bus	p mlf
    mpc.bus_mlf = [
    $(join(lines, "\n"))
    ];
    """

    open("./data/nem/$(scenario)/mlf.m", "w+") do io
        print(io, template)
    end
end


"""
    solution_processor(pm, solution)

Can be used to add extra values to the solution result set
"""
function solution_processor(pm::_PM.AbstractPowerModel, solution::Dict{String, Any})
    solution["dual_objective"] = JuMP.dual_objective_value(pm.model)
    # solution["lambda1"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[1]"))
    # solution["lambda2"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[2]"))
    # solution["lambda3"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[3]"))
    # solution["lambda4"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[4]"))
    # solution["lambda5"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[5]"))
    # solution["lambda6"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[6]"))
    # solution["lambda7"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[7]"))
    # solution["lambda8"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[8]"))
    # solution["lambda9"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[9]"))
    # solution["lambda10"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[10]"))
end
