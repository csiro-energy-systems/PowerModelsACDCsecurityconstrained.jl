duid = :DUID
type = Symbol("Dispatch Type")
fuel = Symbol("Fuel Source - Primary")

gen_filter = (participant) -> (capacity, fuel) -> capacity / 100 <= participant.pmax && participant.type == fuel
load_filter = (participant) -> (capacity, fuel) -> capacity / 100 <= participant.pmax


"""
    get_capacity(participant_type::String)

Reads the maximum capacity for each participant and adds it to the Data Frame.

# Arguments
- `participant_type::String`: eg. Generator/Load
"""
function get_capacity(participant_type::String)
    participants = CSV.read("./data/NEM/participants.csv", DataFrame)
    participants[!, :"Max Cap (MW)"] = something.(tryparse.(Float64, participants[!, :"Max Cap (MW)"]), 0.0)

    participants = groupby(participants, [duid, type, fuel])
    participants = combine(participants, :"Max Cap (MW)" => sum => :capacity)

    participants = @orderby participants -:capacity
    participants = filter([type, :capacity, fuel] => (type, capacity, fuel) -> type == participant_type && capacity > 0 && !ismissing(fuel), participants)

    return participants
end

"""
    assign_participant(participants, participant_type, selector)

Maps an NEM participant DUID to a generator/load

# Arguments
- `selector::Function`: used to select participants based on their type
"""
function assign_participant(participants::DataFrame, participant_type::String, selector::Function)
    df = copy(participants)
    df.DUID .= ""
    df.MaxCap .= 0.0
    df.Fuel .= ""

    capacity = get_capacity(participant_type)

    @orderby df -:"pmax"

    for participant in eachrow(df)
        filtered = filter([:capacity, fuel] => selector(participant), capacity)
        if nrow(filtered) > 0
            value = first(filtered)
            filter!(duid => row -> row != value.DUID, capacity)
            participant.DUID = value[duid]
            participant.MaxCap = value.capacity
            participant.Fuel = value[fuel]
        end
    end

    return df
end

"""
    join_offers(participants, scenario)

Joins BIDPEROFFER table values to a generator/load based on the assigned DUID
"""
function join_offers(participants::DataFrame, scenario::String)
    dateformat = "dd/mm/yyyy HH:MM"
    columns = Dict(
        :DUID => String,
        :BIDTYPE => String,
        :MAXAVAIL => Float64,
        :ENABLEMENTMIN => Float64,
        :ENABLEMENTMAX => Float64,
        :LOWBREAKPOINT => Float64,
        :HIGHBREAKPOINT => Float64,
        :BANDAVAIL1 => Float64,
        :BANDAVAIL2 => Float64,
        :BANDAVAIL3 => Float64,
        :BANDAVAIL4 => Float64,
        :BANDAVAIL5 => Float64,
        :BANDAVAIL6 => Float64,
        :BANDAVAIL7 => Float64,
        :BANDAVAIL8 => Float64,
        :BANDAVAIL9 => Float64,
        :BANDAVAIL10 => Float64
    )

    offers = CSV.read("./data/NEM/$(scenario)/BIDPEROFFER.csv", DataFrame, dateformat=dateformat, select=collect(keys(columns)), types=columns)
    return leftjoin(participants, offers, on=:DUID, matchmissing=:notequal)
end

"""
    join_energy_prices(participants, scenario)

Joins BIDDAYOFFER energy bid/offeres to a generator/load based on the assigned DUID
"""
function join_energy_prices(participants::DataFrame, scenario::String)
    dateformat = "dd/mm/yyyy HH:MM"
    columns = Dict(
        :DUID => String,
        :BIDTYPE => String,
        :PRICEBAND1 => Float64,
        :PRICEBAND2 => Float64,
        :PRICEBAND3 => Float64,
        :PRICEBAND4 => Float64,
        :PRICEBAND5 => Float64,
        :PRICEBAND6 => Float64,
        :PRICEBAND7 => Float64,
        :PRICEBAND8 => Float64,
        :PRICEBAND9 => Float64,
        :PRICEBAND10 => Float64,
        :LASTCHANGED => DateTime
    )

    prices = CSV.read("./data/NEM/$(scenario)/BIDDAYOFFER.csv", DataFrame, dateformat=dateformat, select=collect(keys(columns)), types=columns)
    filter!([:BIDTYPE] => (type) -> type == "ENERGY", prices)

    # get latest entry for each participant (maybe DAILY or REBID)

    combine(groupby(prices, [:DUID, :BIDTYPE])) do sdf
        sdf[argmax(sdf.LASTCHANGED), :]
    end

    df = filter([:BIDTYPE] => (type) -> ismissing(type) || type == "ENERGY", participants)
    return leftjoin(df, prices, on=[:DUID, :BIDTYPE], matchmissing=:notequal)
end

"""
    join_fcas_prices(participants, scenario)

Joins BIDDAYOFFER FCAS bid/offeres to a generator/load based on the assigned DUID
"""
function join_fcas_prices(participants::DataFrame, scenario::String)
    dateformat = "dd/mm/yyyy HH:MM"
    columns = Dict(
        :DUID => String,
        :BIDTYPE => String,
        :PRICEBAND1 => Float64,
        :PRICEBAND2 => Float64,
        :PRICEBAND3 => Float64,
        :PRICEBAND4 => Float64,
        :PRICEBAND5 => Float64,
        :PRICEBAND6 => Float64,
        :PRICEBAND7 => Float64,
        :PRICEBAND8 => Float64,
        :PRICEBAND9 => Float64,
        :PRICEBAND10 => Float64,
        :LASTCHANGED => DateTime
    )

    services = collect(keys(fcas_services))

    prices = CSV.read("./data/NEM/$(scenario)/BIDDAYOFFER.csv", DataFrame, dateformat=dateformat, select=collect(keys(columns)), types=columns)
    filter!([:BIDTYPE] => (type) -> type in services, prices)

    prices
    # get latest entry for each participant (maybe DAILY or REBID)

    combine(groupby(prices, [:DUID, :BIDTYPE])) do sdf
        sdf[argmax(sdf.LASTCHANGED), :]
    end

    df = filter([:BIDTYPE] => (type) -> ismissing(type) || type in services, participants)
    return innerjoin(df, prices, on=[:DUID, :BIDTYPE], matchmissing=:notequal)
end

"""
    gen_convert_to_pwl!(participants)

Converts generator offer bands (each containing a quantity and price) to Piecewise Linear functions
"""
function gen_convert_to_pwl!(participants::DataFrame)
    # calculate breakpoints using cummulative sum of bands.

    breakpoint_MW1 = participants.BANDAVAIL1
    breakpoint_MW2 = breakpoint_MW1 + participants.BANDAVAIL2
    breakpoint_MW3 = breakpoint_MW2 + participants.BANDAVAIL3
    breakpoint_MW4 = breakpoint_MW3 + participants.BANDAVAIL4
    breakpoint_MW5 = breakpoint_MW4 + participants.BANDAVAIL5
    breakpoint_MW6 = breakpoint_MW5 + participants.BANDAVAIL6
    breakpoint_MW7 = breakpoint_MW6 + participants.BANDAVAIL7
    breakpoint_MW8 = breakpoint_MW7 + participants.BANDAVAIL8
    breakpoint_MW9 = breakpoint_MW8 + participants.BANDAVAIL9
    breakpoint_MW10 = breakpoint_MW9 + participants.BANDAVAIL10

    # find the midpoint between consecutive breakpoints.

    participants.midpoint_MW1 = 0.0 .+ ((breakpoint_MW1 .- 0.0) / 2)
    participants.midpoint_MW2 = breakpoint_MW1 + ((breakpoint_MW2 - breakpoint_MW1) / 2)
    participants.midpoint_MW3 = breakpoint_MW2 + ((breakpoint_MW3 - breakpoint_MW2) / 2)
    participants.midpoint_MW4 = breakpoint_MW3 + ((breakpoint_MW4 - breakpoint_MW3) / 2)
    participants.midpoint_MW5 = breakpoint_MW4 + ((breakpoint_MW5 - breakpoint_MW4) / 2)
    participants.midpoint_MW6 = breakpoint_MW5 + ((breakpoint_MW6 - breakpoint_MW5) / 2)
    participants.midpoint_MW7 = breakpoint_MW6 + ((breakpoint_MW7 - breakpoint_MW6) / 2)
    participants.midpoint_MW8 = breakpoint_MW7 + ((breakpoint_MW8 - breakpoint_MW7) / 2)
    participants.midpoint_MW9 = breakpoint_MW8 + ((breakpoint_MW9 - breakpoint_MW8) / 2)
    participants.midpoint_MW10 = breakpoint_MW9 + ((breakpoint_MW10 - breakpoint_MW9) / 2)

    # If availability bands are zero, the cost curve will be vertical and the slope
    # will be Inf which causes errors. If an availability band is zero, take the previous
    # band's price. This will cause duplicate breakpoints which can easily be handled
    # by the PowerModels calc_pwl_points function.

    transform!(participants, [:PRICEBAND1, :PRICEBAND2, :BANDAVAIL2] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND2)
    transform!(participants, [:PRICEBAND2, :PRICEBAND3, :BANDAVAIL3] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND3)
    transform!(participants, [:PRICEBAND3, :PRICEBAND4, :BANDAVAIL4] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND4)
    transform!(participants, [:PRICEBAND4, :PRICEBAND5, :BANDAVAIL5] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND5)
    transform!(participants, [:PRICEBAND5, :PRICEBAND6, :BANDAVAIL6] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND6)
    transform!(participants, [:PRICEBAND6, :PRICEBAND7, :BANDAVAIL7] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND7)
    transform!(participants, [:PRICEBAND7, :PRICEBAND8, :BANDAVAIL8] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND8)
    transform!(participants, [:PRICEBAND8, :PRICEBAND9, :BANDAVAIL9] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND9)
    transform!(participants, [:PRICEBAND9, :PRICEBAND10, :BANDAVAIL10] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND10)
end

"""
    load_convert_to_pwl!(participants)

Converts load bid bands (each containing a quantity and price) to Piecewise Linear functions
"""
function load_convert_to_pwl!(participants::DataFrame)
    # calculate breakpoints using cummulative sum of bands.

    breakpoint_MW1 = participants.BANDAVAIL10
    breakpoint_MW2 = breakpoint_MW1 + participants.BANDAVAIL9
    breakpoint_MW3 = breakpoint_MW2 + participants.BANDAVAIL8
    breakpoint_MW4 = breakpoint_MW3 + participants.BANDAVAIL7
    breakpoint_MW5 = breakpoint_MW4 + participants.BANDAVAIL6
    breakpoint_MW6 = breakpoint_MW5 + participants.BANDAVAIL5
    breakpoint_MW7 = breakpoint_MW6 + participants.BANDAVAIL4
    breakpoint_MW8 = breakpoint_MW7 + participants.BANDAVAIL3
    breakpoint_MW9 = breakpoint_MW8 + participants.BANDAVAIL2
    breakpoint_MW10 = breakpoint_MW9 + participants.BANDAVAIL1

    # find the midpoint between consecutive breakpoints.

    participants.midpoint_MW1 = 0.0 .+ ((breakpoint_MW1 .- 0.0) / 2)
    participants.midpoint_MW2 = breakpoint_MW1 + ((breakpoint_MW2 - breakpoint_MW1) / 2)
    participants.midpoint_MW3 = breakpoint_MW2 + ((breakpoint_MW3 - breakpoint_MW2) / 2)
    participants.midpoint_MW4 = breakpoint_MW3 + ((breakpoint_MW4 - breakpoint_MW3) / 2)
    participants.midpoint_MW5 = breakpoint_MW4 + ((breakpoint_MW5 - breakpoint_MW4) / 2)
    participants.midpoint_MW6 = breakpoint_MW5 + ((breakpoint_MW6 - breakpoint_MW5) / 2)
    participants.midpoint_MW7 = breakpoint_MW6 + ((breakpoint_MW7 - breakpoint_MW6) / 2)
    participants.midpoint_MW8 = breakpoint_MW7 + ((breakpoint_MW8 - breakpoint_MW7) / 2)
    participants.midpoint_MW9 = breakpoint_MW8 + ((breakpoint_MW9 - breakpoint_MW8) / 2)
    participants.midpoint_MW10 = breakpoint_MW9 + ((breakpoint_MW10 - breakpoint_MW9) / 2)

    # If availability bands are zero, the cost curve will be vertical and the slope
    # will be Inf which causes errors. If an availability band is zero, take the previous
    # band's price. This will cause duplicate breakpoints which can easily be handled
    # by the PowerModels calc_pwl_points function.

    transform!(participants, [:PRICEBAND10, :PRICEBAND9, :BANDAVAIL9] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND9)
    transform!(participants, [:PRICEBAND9, :PRICEBAND8, :BANDAVAIL8] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND8)
    transform!(participants, [:PRICEBAND8, :PRICEBAND7, :BANDAVAIL7] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND7)
    transform!(participants, [:PRICEBAND7, :PRICEBAND6, :BANDAVAIL6] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND6)
    transform!(participants, [:PRICEBAND6, :PRICEBAND5, :BANDAVAIL5] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND5)
    transform!(participants, [:PRICEBAND5, :PRICEBAND4, :BANDAVAIL4] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND4)
    transform!(participants, [:PRICEBAND4, :PRICEBAND3, :BANDAVAIL3] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND3)
    transform!(participants, [:PRICEBAND3, :PRICEBAND2, :BANDAVAIL2] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND2)
    transform!(participants, [:PRICEBAND2, :PRICEBAND1, :BANDAVAIL1] => ByRow((p1, p2, mw) -> coalesce(mw, 0) == 0.0 ? p1 : p2) => :PRICEBAND1)
end

"""
    export_gen_cost(participants, scenario)

Generates a file in MatPower case format containing the generator cost data.
"""
function export_gen_cost(participants::DataFrame, scenario::String)
    cost_pwl(participant) = """
    1\t\
    $(coalesce(participant.startup, 0))\t\
    $(coalesce(participant.shutdown, 0))\t\
    10\t\
    $(coalesce(participant.midpoint_MW1, 0))\t\
    $(coalesce(participant.PRICEBAND1, 0))\t\
    $(coalesce(participant.midpoint_MW2, 0))\t\
    $(coalesce(participant.PRICEBAND2, 0))\t\
    $(coalesce(participant.midpoint_MW3, 0))\t\
    $(coalesce(participant.PRICEBAND3, 0))\t\
    $(coalesce(participant.midpoint_MW4, 0))\t\
    $(coalesce(participant.PRICEBAND4, 0))\t\
    $(coalesce(participant.midpoint_MW5, 0))\t\
    $(coalesce(participant.PRICEBAND5, 0))\t\
    $(coalesce(participant.midpoint_MW6, 0))\t\
    $(coalesce(participant.PRICEBAND6, 0))\t\
    $(coalesce(participant.midpoint_MW7, 0))\t\
    $(coalesce(participant.PRICEBAND7, 0))\t\
    $(coalesce(participant.midpoint_MW8, 0))\t\
    $(coalesce(participant.PRICEBAND8, 0))\t\
    $(coalesce(participant.midpoint_MW9, 0))\t\
    $(coalesce(participant.PRICEBAND9, 0))\t\
    $(coalesce(participant.midpoint_MW10, 0))\t\
    $(coalesce(participant.PRICEBAND10, 0));\
    """

    lines = cost_pwl.(eachrow(participants))

    template = """
    %%-----  OPF Data  -----%%
    %% cost data
    %    1    startup    shutdown    n    x1    y1    ...    xn    yn
    %    2    startup    shutdown    n    c(n-1)    ...    c0
    mpc.gencost = [
    $(join(lines, "\n"))
    ];
    """

    open("./data/nem/$(scenario)/gencost.m", "w+") do io
        print(io, template)
    end
end

"""
    export_load_data(participants, scenario)

Generates a file in MatPower case format containing the load limits and cost data.
"""
function export_load_data(participants::DataFrame, scenario::String)
    open("./data/nem/$(scenario)/loadcost.m", "w+") do io
        export_load_limits(participants, io)
        println(io)
        export_load_cost(participants, io)
    end
end

"""
    export_load_cost(participants, io)

Generates data in MatPower case format containing the load costs.
"""
function export_load_cost(participants::DataFrame, io::IO)
    cost_pwl(participant) = """
    1\t\
    0\t\
    0\t\
    10\t\
    $(coalesce(participant.midpoint_MW1, 0))\t\
    $(coalesce(participant.PRICEBAND10, 0))\t\
    $(coalesce(participant.midpoint_MW2, 0))\t\
    $(coalesce(participant.PRICEBAND9, 0))\t\
    $(coalesce(participant.midpoint_MW3, 0))\t\
    $(coalesce(participant.PRICEBAND8, 0))\t\
    $(coalesce(participant.midpoint_MW4, 0))\t\
    $(coalesce(participant.PRICEBAND7, 0))\t\
    $(coalesce(participant.midpoint_MW5, 0))\t\
    $(coalesce(participant.PRICEBAND6, 0))\t\
    $(coalesce(participant.midpoint_MW6, 0))\t\
    $(coalesce(participant.PRICEBAND5, 0))\t\
    $(coalesce(participant.midpoint_MW7, 0))\t\
    $(coalesce(participant.PRICEBAND4, 0))\t\
    $(coalesce(participant.midpoint_MW8, 0))\t\
    $(coalesce(participant.PRICEBAND3, 0))\t\
    $(coalesce(participant.midpoint_MW9, 0))\t\
    $(coalesce(participant.PRICEBAND2, 0))\t\
    $(coalesce(participant.midpoint_MW10, 0))\t\
    $(coalesce(participant.PRICEBAND1, 0));\
    """

    lines = cost_pwl.(eachrow(participants))

    template = """
    %% load cost data
    %	1	startup	shutdown	n	x1	y1	...	xn	yn
    %	2	startup	shutdown	n	c(n-1)	...	c0
    mpc.loadcost = [
    $(join(lines, "\n"))
    ];
    """

    print(io, template)
end

"""
    export_load_limits(participants, io)

Generates data in MatPower case format containing the load power limits.
"""
function export_load_limits(participants::DataFrame, io::IO)
    participants = filter([:DUID] => x -> x != "", participants)

    limits(load) = """
    $(load.index)\t\
    $(load.MaxCap)\t\
    0;\
    """

    lines = limits.(eachrow(participants))

    template = """
    %% load limit data
    %column_names% 	bus	Pmax	Pmin
    mpc.load_limit = [
    $(join(lines, "\n"))
    ];
    """

    print(io, template)
end

"""
    export_fcas_data(scenario, gens, loads)

Generates a file in MatPower case format containing FCAS trapezium and cost data.
"""
function export_fcas_data(scenario::String, gens::DataFrame=DataFrame(), loads::DataFrame=DataFrame())
    open("./data/nem/$(scenario)/fcas.m", "w+") do io
        if nrow(gens) > 0
            export_gen_fcas_trapezium(gens, io)
            println(io)
            export_gen_fcas_cost(gens, io)
            println(io)
        end

        if nrow(loads) > 0       
            export_load_fcas_trapezium(loads, io)
            println(io)
            export_load_fcas_cost(loads, io)
            println(io)
        end

        export_fcas_target(io)
    end
end

"""
    export_gen_fcas_trapezium(gens, io)

Generates data in MatPower case format containing the generator FCAS trapezium.
"""
function export_gen_fcas_trapezium(gens::DataFrame, io::IO)
    trapezium(participant) = """
    $(participant.index)\t\
    $(fcas_services[participant.BIDTYPE].id)\t\
    $(coalesce(participant.ENABLEMENTMIN, 0))\t\
    $(coalesce(participant.LOWBREAKPOINT, 0))\t\
    $(coalesce(participant.HIGHBREAKPOINT, 0))\t\
    $(coalesce(participant.ENABLEMENTMAX, 0))\t\
    $(coalesce(participant.MAXAVAIL, 0));\
    """

    lines = trapezium.(eachrow(gens))

    template = """%% generator fcas trapezium
    % service (1=LReg, 2=RReg, 3=L1S, 4=R1S, 5=L6S, 6=R6S, 7=L60S, 8=R60S, 9=L5M, 10=R5M)
    %column_names%   gen  service emin    lb  ub  emax  amax
    mpc.fcas_gen = [
    $(join(lines, "\n"))     
    ];
    """

    print(io, template)
end

"""
    export_load_fcas_trapezium(loads, io)

Generates data in MatPower case format containing the load FCAS trapezium.
"""
function export_load_fcas_trapezium(loads::DataFrame, io::IO)
    trapezium(participant) = """
    $(participant.index)\t\
    $(fcas_services[participant.BIDTYPE].id)\t\
    $(coalesce(participant.ENABLEMENTMIN, 0))\t\
    $(coalesce(participant.LOWBREAKPOINT, 0))\t\
    $(coalesce(participant.HIGHBREAKPOINT, 0))\t\
    $(coalesce(participant.ENABLEMENTMAX, 0))\t\
    $(coalesce(participant.MAXAVAIL, 0));\
    """

    lines = trapezium.(eachrow(loads))

    template = """
    %% load fcas trapezium
    % service (1=RReg, 2=LReg, 3=L1S, 4=R1S, 5=L6S, 6=R6S, 7=L60S, 8=R60S, 9=L5M, 10=R5M)
    %column_names%   load  service emin    lb  ub  emax  amax
    mpc.fcas_load = [
    $(join(lines, "\n"))     
    ];
    """

    print(io, template)
end

"""
    export_gen_fcas_cost(participants, io)

Generates data in MatPower case format containing the generator FCAS costs.
"""
function export_gen_fcas_cost(participants::DataFrame, io::IO)
    cost_pwl(participant) = """
    $(participant.index)\t\
    $(fcas_services[participant.BIDTYPE].id)\t\
    10\t\
    $(coalesce(participant.midpoint_MW1, 0))\t\
    $(coalesce(participant.PRICEBAND1, 0))\t\
    $(coalesce(participant.midpoint_MW2, 0))\t\
    $(coalesce(participant.PRICEBAND2, 0))\t\
    $(coalesce(participant.midpoint_MW3, 0))\t\
    $(coalesce(participant.PRICEBAND3, 0))\t\
    $(coalesce(participant.midpoint_MW4, 0))\t\
    $(coalesce(participant.PRICEBAND4, 0))\t\
    $(coalesce(participant.midpoint_MW5, 0))\t\
    $(coalesce(participant.PRICEBAND5, 0))\t\
    $(coalesce(participant.midpoint_MW6, 0))\t\
    $(coalesce(participant.PRICEBAND6, 0))\t\
    $(coalesce(participant.midpoint_MW7, 0))\t\
    $(coalesce(participant.PRICEBAND7, 0))\t\
    $(coalesce(participant.midpoint_MW8, 0))\t\
    $(coalesce(participant.PRICEBAND8, 0))\t\
    $(coalesce(participant.midpoint_MW9, 0))\t\
    $(coalesce(participant.PRICEBAND9, 0))\t\
    $(coalesce(participant.midpoint_MW10, 0))\t\
    $(coalesce(participant.PRICEBAND10, 0));\
    """

    lines = cost_pwl.(eachrow(participants))

    template = """
    %% generator fcas cost
    % service (1=LReg, 2=RReg, 3=L1S, 4=R1S, 5=L6S, 6=R6S, 7=L60S, 8=R60S, 9=L5M, 10=R5M)
    %	gen    service n	x1	y1	...	xn	yn
    mpc.fcas_cost_gen = [
    $(join(lines, "\n"))
    ];
    """

    print(io, template)
end

"""
    export_load_fcas_cost(participants, io)

Generates data in MatPower case format containing the load FCAS costs.
"""
function export_load_fcas_cost(participants::DataFrame, io::IO)
    cost_pwl(participant) = """
    $(participant.index)\t\
    $(fcas_services[participant.BIDTYPE].id)\t\
    10\t\
    $(coalesce(participant.midpoint_MW1, 0))\t\
    $(coalesce(participant.PRICEBAND10, 0))\t\
    $(coalesce(participant.midpoint_MW2, 0))\t\
    $(coalesce(participant.PRICEBAND9, 0))\t\
    $(coalesce(participant.midpoint_MW3, 0))\t\
    $(coalesce(participant.PRICEBAND8, 0))\t\
    $(coalesce(participant.midpoint_MW4, 0))\t\
    $(coalesce(participant.PRICEBAND7, 0))\t\
    $(coalesce(participant.midpoint_MW5, 0))\t\
    $(coalesce(participant.PRICEBAND6, 0))\t\
    $(coalesce(participant.midpoint_MW6, 0))\t\
    $(coalesce(participant.PRICEBAND5, 0))\t\
    $(coalesce(participant.midpoint_MW7, 0))\t\
    $(coalesce(participant.PRICEBAND4, 0))\t\
    $(coalesce(participant.midpoint_MW8, 0))\t\
    $(coalesce(participant.PRICEBAND3, 0))\t\
    $(coalesce(participant.midpoint_MW9, 0))\t\
    $(coalesce(participant.PRICEBAND2, 0))\t\
    $(coalesce(participant.midpoint_MW10, 0))\t\
    $(coalesce(participant.PRICEBAND1, 0));\
    """

    lines = cost_pwl.(eachrow(participants))

    template = """
    %% load fcas cost
    %	load    service n	x1	y1	...	xn	yn
    mpc.fcas_cost_load = [
    $(join(lines, "\n"))
    ];
    """

    print(io, template)
end

"""
    export_fcas_target(io)

Generates data in MatPower case format containing the FCAS service targets.
"""
function export_fcas_target(io::IO)
    target(service) = """
    $(service)\t\
    0;\
    """

    lines = target.(1:10)

    template = """
    %% fcas targets
    % service (1=LReg, 2=RReg, 3=L1S, 4=R1S, 5=L6S, 6=R6S, 7=L60S, 8=R60S, 9=L5M, 10=R5M)
    %column_names%   service p
    mpc.fcas_target = [
    $(join(lines, "\n"))
    ];
    """

    print(io, template)
end

"""
    get_df_from_dict(data::Dict, columns::Vector{String}, mapping::Vector{Pair{String, String}}=Pair{String, String}[])

Creates a DataFrame from a dictionary

# Arguments
- `columns::Vector{String}`: dictionary keys to using in DataFrame
- `mapping::Vector{Pair{String, String}}`: maps a key in the dict to a new name in the DataFrame
"""
function get_df_from_dict(data::Dict, columns::Vector{String}, mapping::Vector{Pair{String, String}}=Pair{String, String}[])
    mapping_dict = Dict(mapping)
    df = [Dict([get(mapping_dict, key, key) => value for (key, value) in entry]) for (i, entry) in data]
    
    columns = append!(columns, values(mapping_dict))
    selected = filter.(p -> p[1] in columns, df)
    return DataFrame(selected)
end
