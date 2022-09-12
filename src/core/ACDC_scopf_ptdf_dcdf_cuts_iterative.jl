"""
Solves a SCOPF problem by iteratively checking for violated branch flow
constraints in contingencies and resolving until a fixed-point is reached.

The base-case model is formulation agnostic.  The flow cuts are based on PTDF
and utilize the DC Power Flow assumption.
"""
function run_c1_scopf_ptdf_cuts_GM(network::Dict{String,<:Any}, model_type::Type, optimizer; kwargs...)
    return run_c1_scopf_ptdf_cuts_GM!(network, model_type, optimizer; kwargs...)
end

function run_c1_scopf_ptdf_cuts_GM!(network::Dict{String,<:Any}, model_type::Type, optimizer; max_iter::Int=100, time_limit::Float64=Inf)
    if _IM.ismultinetwork(network)
        error(_LOGGER, "run_c1_scopf_ptdf_cuts can only be used on single networks")
    end

    time_start = time()

    network["gen_flow_cuts"] = []
    network["branch_flow_cuts"] = []
    network["branchdc_flow_cuts"] = []

    result = _PMACDC.run_acdcopf(network, model_type, optimizer)
    if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        error(_LOGGER, "base-case ACDCOPF solve failed in run_c1_scopf_ptdf_cuts, status $(result["termination_status"])")
    end
    _PMSC.info(_LOGGER, "objective: $(result["objective"])")
    _PM.update_data!(network, result["solution"])

    result["iterations"] = 0

    iteration = 1
    cuts_found = 1
    while cuts_found > 0
        time_start_iteration = time()

        cuts = check_c1_contingencies_branch_power_GM(network, optimizer, total_cut_limit=iteration, gen_flow_cuts=[], branch_flow_cuts=[])

        cuts_found = length(cuts.gen_cuts) + length(cuts.branch_cuts) + length(cuts.branchdc_cuts)
        if cuts_found <= 0
            _PMSC.info(_LOGGER, "no violated cuts found scopf fixed-point reached")
            break
        else
            _PMSC.info(_LOGGER, "found $(cuts_found) branch flow violations")
        end

        append!(network["gen_flow_cuts"], cuts.gen_cuts)
        append!(network["branch_flow_cuts"], cuts.branch_cuts)
        append!(network["branchdc_flow_cuts"], cuts.branchdc_cuts)

        _PMSC.info(_LOGGER, "active cuts: gen $(length(network["gen_flow_cuts"])), branch $(length(network["branch_flow_cuts"])), branchdc $(length(network["branchdc_flow_cuts"]))")

        time_solve_start = time()
        result = run_c1_scopf_cuts_GM(network, model_type, optimizer)
        if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
            _PMSC.warn(_LOGGER, "scopf solve failed with status $(result["termination_status"]), terminating fixed-point early")
            break
        end
        _PMSC.info(_LOGGER, "objective: $(result["objective"])")
        _PM.update_data!(network, result["solution"])

        time_iteration = time() - time_start_iteration
        time_remaining = time_limit - (time() - time_start)
        if time_remaining < time_iteration
            _PMSC.warn(_LOGGER, "insufficent time for next iteration, time remaining $(time_remaining), estimated iteration time $(time_iteration)")
            break
        end
        iteration += 1
    end

    result["iterations"] = iteration
    return result
end