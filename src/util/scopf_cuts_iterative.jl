
function run_scopf_acdc_cuts(network::Dict{String,<:Any}, model_type_scopf::Type, model_type_filter::Type, run_scopf_prob::Function, optimizer_scopf, optimizer_filter, setting; kwargs...)
    return build_scopf_acdc_cuts(network, model_type_scopf, model_type_filter, run_scopf_prob, optimizer_scopf, optimizer_filter, setting; kwargs...)
end

function build_scopf_acdc_cuts(network::Dict{String,<:Any}, model_type_scopf::Type, model_type_filter::Type, run_scopf_prob::Function, optimizer_scopf, optimizer_filter, setting; max_iter::Int=1000, time_limit::Float64=Inf)
    if _IM.ismultinetwork(network)
        Memento.error(_LOGGER, "run_scopf_acdc_cuts can only be used on single networks")
    end

    time_start = time()

    result = Dict{String,Any}()
    result_scopf = Dict{String,Any}()

    network["gen_flow_cuts"] = []
    network["branch_flow_cuts"] = []
    network["branchdc_flow_cuts"] = []
    network["convdc_flow_cuts"] = []

    result = _PMACDC.run_acdcopf(network, model_type_scopf, optimizer_scopf, setting = setting)
    if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        Memento.error(_LOGGER, "base-case acdcopf solve failed in run_scopf_acdc_cuts, status $(result["termination_status"])")
    end
    Memento.info(_LOGGER, "objective: $(result["objective"])")
    _PM.update_data!(network, result["solution"])
    update_data_converter_setpoints!(network, result["solution"])
    add_losses_and_loss_distribution_factors!(network)

    result["iterations"] = 0

    iteration = 1
    cuts_found = 1
    while cuts_found > 0
        time_start_iteration = time()

        cuts = check_acdc_contingency_branch_power(network, model_type_filter, optimizer_filter, setting, total_cut_limit=iteration, gen_flow_cuts = network["gen_flow_cuts"], branch_flow_cuts = network["branch_flow_cuts"], branchdc_flow_cuts = network["branchdc_flow_cuts"])
        
        cuts_found = length(cuts.gen_cuts)+length(cuts.branch_cuts)+length(cuts.branchdc_cuts)
        if cuts_found <= 0
            Memento.info(_LOGGER, "no violated cuts found scopf fixed-point reached")
            break
        else
            Memento.info(_LOGGER, "found $(cuts_found) ac or dc branch flow violations")
        end
        
        append!(network["gen_flow_cuts"], cuts.gen_cuts)
        append!(network["branch_flow_cuts"], cuts.branch_cuts)
        append!(network["branchdc_flow_cuts"], cuts.branchdc_cuts)

        Memento.info(_LOGGER, "active cuts: gen $(length(network["gen_flow_cuts"])), branch $(length(network["branch_flow_cuts"])), branchdc $(length(network["branchdc_flow_cuts"]))")

        time_solve_start = time()
        result = run_scopf_prob(network, model_type_scopf, optimizer_scopf)
        if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
            Memento.warn(_LOGGER, "scopf solve failed in run_scopf_acdc_cuts with status $(result["termination_status"]), terminating fixed-point early")
            break
        end
        Memento.info(_LOGGER, "objective: $(result["objective"])")
        _PM.update_data!(network, result["solution"])
        update_data_converter_setpoints!(network, result["solution"])

        time_iteration = time() - time_start_iteration
        time_remaining = time_limit - (time() - time_start)
        if time_remaining < time_iteration
            Memento.warn(_LOGGER, "insufficent time for next iteration, time remaining $(time_remaining), estimated iteration time $(time_iteration)")
            break
        end
        iteration += 1
    end

    result["iterations"] = iteration
    result_scopf["final"] = result 

    return result_scopf
end


function run_scopf_acdc_cuts_remote(network::Dict{String,<:Any}, model_type_scopf::Type, model_type_filter::Type, run_scopf_prob::Function, optimizer_scopf, optimizer_filter, setting; kwargs...)
    return build_scopf_acdc_cuts_remote(network, model_type_scopf, model_type_filter, run_scopf_prob, optimizer_scopf, optimizer_filter, setting; kwargs...)
end

function build_scopf_acdc_cuts_remote(network::Dict{String,<:Any}, model_type_scopf::Type, model_type_filter::Type, run_scopf_prob::Function, optimizer_scopf, optimizer_filter, setting; max_iter::Int=1000, time_limit::Float64=Inf)
    if _IM.ismultinetwork(network)
        Memento.error(_LOGGER, "run_scopf_acdc_cuts can only be used on single networks")
    end

    time_start = time()

    result_scopf = Dict{String,Any}()

    network["gen_flow_cuts"] = []
    network["branch_flow_cuts"] = []
    network["branchdc_flow_cuts"] = []
    network["convdc_flow_cuts"] = []

    result = Dict{String,Any}()
    result["iterations"] = 0

    iteration = 1
    cuts_found = 1
    while cuts_found > 0
        time_start_iteration = time()

        cuts = check_acdc_contingency_branch_power(network, model_type_filter, optimizer_filter, setting, total_cut_limit=iteration, gen_flow_cuts = network["gen_flow_cuts"], branch_flow_cuts = network["branch_flow_cuts"], branchdc_flow_cuts = network["branchdc_flow_cuts"])
        
        cuts_found = length(cuts.gen_cuts)+length(cuts.branch_cuts)+length(cuts.branchdc_cuts)
        if cuts_found <= 0
            Memento.info(_LOGGER, "no violated cuts found scopf fixed-point reached")
            break
        else
            Memento.info(_LOGGER, "found $(cuts_found) ac or dc branch flow violations")
        end
        
        append!(network["gen_flow_cuts"], cuts.gen_cuts)
        append!(network["branch_flow_cuts"], cuts.branch_cuts)
        append!(network["branchdc_flow_cuts"], cuts.branchdc_cuts)

        Memento.info(_LOGGER, "active cuts: gen $(length(network["gen_flow_cuts"])), branch $(length(network["branch_flow_cuts"])), branchdc $(length(network["branchdc_flow_cuts"]))")

        time_solve_start = time()
        result = run_scopf_prob(network, model_type_scopf, optimizer_scopf)
        if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
            Memento.warn(_LOGGER, "scopf solve failed in run_scopf_acdc_cuts with status $(result["termination_status"]), terminating fixed-point early")
            break
        end
        Memento.info(_LOGGER, "objective: $(result["objective"])")
        _PM.update_data!(network, result["solution"])

        for (i,conv) in network["convdc"]
            conv["P_g"] = -result["solution"]["convdc"][i]["pgrid"]
            conv["Q_g"] = -result["solution"]["convdc"][i]["qgrid"]
        end

        time_iteration = time() - time_start_iteration
        time_remaining = time_limit - (time() - time_start)
        if time_remaining < time_iteration
            Memento.warn(_LOGGER, "insufficent time for next iteration, time remaining $(time_remaining), estimated iteration time $(time_iteration)")
            break
        end
        iteration += 1
    end

    result["iterations"] = iteration
    result_scopf["final"] = result 

    return result_scopf
end