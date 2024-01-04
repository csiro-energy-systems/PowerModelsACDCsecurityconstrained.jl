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