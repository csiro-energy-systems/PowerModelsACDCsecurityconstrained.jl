"""
    set_reference_bus(data, refs)

Set each bus in the refs argument as reference/slack buses

# Arguments
- `data::Dict{String, Any}`: The network data dictionary
- `refs::Vector{String}`: A list of references bus indexes
"""
function set_reference_bus(data, refs::Vector{String})
    area_data = deepcopy(data)

    for ref in refs
        area_data["bus"][ref]["bus_type"] = 3
        gens = filter(x -> x[2]["gen_bus"] == parse(Int, ref), area_data["gen"])
        if isempty(gens)
            gen_count = length(area_data["gen"])
            area_data["gen"]["$(gen_count + 1)"] = Dict("index" => gen_count + 1, "gen_status" => 1, "gen_bus" => parse(Int, ref), "pg" => 0.0, "qg" => 0.0)
        end
    end

    return area_data
end

"""
    mlf_initialise!(data)

Run an OPF to find an initial solution for subsequent PF solves
"""
function mlf_initialise!(data)
    setting = Dict("output" => Dict("branch_flows" => true, "duals" => true), "conv_losses_mp" => true)
    nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
    
    result = PowerModelsNEM.run_acdcopf(data, PowerModels.ACPPowerModel, nlp_solver, setting=setting)
    PowerModels.update_data!(data, result["solution"])
    for (i, conv) in data["convdc"]
        conv["P_g"] = -result["solution"]["convdc"][i]["pgrid"]
        conv["Q_g"] = -result["solution"]["convdc"][i]["qgrid"]
    end
end

"""
    inject_load(extra_p, idx, ref, data)

Inject a small load at the bus specified by idx and measure the change in generation
at the reference bus specified by the ref argument
"""
function inject_load(extra_p::Float64, idx::String, ref::String, data)
    data_cp = deepcopy(data)

    load_count = length(keys(data["load"]))

    i = parse(Int, idx)
    data_cp["load"]["$(load_count + 1)"] = Dict("index" => load_count + 1, "status" => 1, "load_bus" => i, "pd" => extra_p, "qd" => 0.0)

    result = PowerModelsACDC.run_sacdcpf(data_cp)
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