_IM.@def fields begin
    id::Int
end

abstract type FCASService end
abstract type FCASRegulatingService <: FCASService end
abstract type FCASContingencyService <: FCASService end

struct LReg <: FCASRegulatingService
    @fields
end
struct RReg <: FCASRegulatingService
    @fields
end
struct L1S <: FCASContingencyService
    @fields
end
struct R1S <: FCASContingencyService
    @fields
end
struct L6S <: FCASContingencyService
    @fields
end
struct R6S <: FCASContingencyService
    @fields
end
struct L60S <: FCASContingencyService
    @fields
end
struct R60S <: FCASContingencyService
    @fields
end
struct L5M <: FCASContingencyService
    @fields
end
struct R5M <: FCASContingencyService
    @fields
end

function fcas_name(service::FCASService)
    return String(nameof(typeof(service)))
end

"""
    fcas_enabled(service, data)

Test if a participant is enabled for a specific FCAS service
"""
function fcas_enabled(service::FCASService, participant::Dict)
    return haskey(participant, "fcas") &&
           haskey(participant["fcas"], service.id) &&
           participant["fcas"][service.id]["amax"] > 0 &&
           participant["fcas"][service.id]["emax"] >= 0 &&
           participant["pmax"] >= participant["fcas"][service.id]["emin"] &&
           haskey(participant, "fcas_cost") &&
           haskey(participant["fcas_cost"], service.id) &&
           any(>(0), participant["fcas_cost"][service.id]["cost"][1:2:end])
end

"""
    is_regulating_service(service)

Returns true if the FCAS service is a regulating service
"""
function is_regulating_service(service::FCASService)
    return isa(service, FCASRegulatingService)
end

"""
    is_contingency_service(service)

Returns true if the FCAS service is a contingency service
"""
function is_contingency_service(service::FCASService)
    return isa(service, FCASContingencyService)
end

"""
    get_fcas_participants(participants, service)

For a given set of participants, returns only those that are enabled for the specified 
FCAS service
"""
function get_fcas_participants(participants::Dict, service::FCASService)
    fcas_participants = filter(x -> fcas_enabled(service, x[2]), participants)

    not_dispatchable = filter(x -> !is_dispatchable(x[2]), fcas_participants)
    for (i, participant) in not_dispatchable
        Memento.warn(_LOGGER, "skipping participant $(haskey(participant["fcas"][service.id], "load") ? "load" : "gen") $(i) from FCAS service '$(fcas_name(service))' as it is not dispatchable")
    end

    return filter(x -> is_dispatchable(x[2]), fcas_participants)
end

fcas_services = Dict{String,FCASService}(
    "LOWERREG" => LReg(1),
    "RAISEREG" => RReg(2),
    "LOWER1SEC" => L1S(3),
    "RAISE1SEC" => R1S(4),
    "LOWER6SEC" => L6S(5),
    "RAISE6SEC" => R6S(6),
    "LOWER60SEC" => L60S(7),
    "RAISE60SEC" => R60S(8),
    "LOWER5MIN" => L5M(9),
    "RAISE5MIN" => R5M(10)
)

"""
    get_cost_data(model, participant)

Returns the participant cost data when running a DC Model. Use MLF values if available.
"""
function get_cost_data(model::_PM.DCPPowerModel, participant::Dict{String, Any})
    data = _PM.ref(model, 0)
    bus = undef

    if (haskey(participant, "gen_bus"))
        bus = participant["gen_bus"]
    end

    if (haskey(participant, "load_bus"))
        bus = participant["load_bus"]
    end

    if (haskey(data, :mlf))
        mlf = filter(x -> x["index"] == bus, data[:mlf])
        original_price = [value for value in participant["cost"][2:2:end]]
        quantity = [value for value in participant["cost"][1:2:end]]

        price = Float64[]
        for i in 1:10
            push!(price, quantity[i], original_price[i] / mlf[1]["mlf"])
        end

        return price
    else
        return participant["cost"]
    end
end

"""
    get_cost_data(model, participant)

Returns the participant cost data when running a AC Model.
"""
function get_cost_data(model::_PM.ACPPowerModel, participant::Dict{String, Any})
    return participant["cost"]
end

