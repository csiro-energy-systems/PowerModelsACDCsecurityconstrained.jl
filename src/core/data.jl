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
    fcas_file = "./data/nem/$(scenario)/fcas.m"
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

    gencost_file = "./data/nem/$(scenario)/gencost.m"
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

    loadcost_file = "./data/nem/$(scenario)/loadcost.m"
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

    mlf_file = "./data/nem/$(scenario)/mlf.m"
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
