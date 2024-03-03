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
