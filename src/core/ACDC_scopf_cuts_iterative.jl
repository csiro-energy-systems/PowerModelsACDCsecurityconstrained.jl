"""
Solves a SCOPF problem by iteratively checking for violated branch flow
constraints in contingencies and resolving until a fixed-point is reached.

The base-case model is formulation agnostic.  The flow cuts are based on PTDF
and utilize the DC Power Flow assumption.
"""
function run_acdc_scopf_ptdf_dcdf_cuts(network::Dict{String,<:Any}, model_type::Type, run_scopf_prob::Function, optimizer; kwargs...)
    return run_acdc_scopf_ptdf_dcdf_cuts!(network, model_type, run_scopf_prob, optimizer; kwargs...)
end

function run_acdc_scopf_ptdf_dcdf_cuts!(network::Dict{String,<:Any}, model_type::Type, run_scopf_prob::Function, optimizer; max_iter::Int=1000, time_limit::Float64=Inf)
    if _IM.ismultinetwork(network)
        error(_LOGGER, "run_c1_scopf_ptdf_cuts can only be used on single networks")
    end

    time_start = time()

    result_scopf = Dict{String,Any}()

    network["gen_flow_cuts"] = []
    network["branch_flow_cuts"] = []
    network["branchdc_flow_cuts"] = []
    network["convdc_flow_cuts"] = []

    result_scopf["gen_flow_cuts_unsecure"] = []
    result_scopf["branch_flow_cuts_unsecure"] = []
    result_scopf["branchdc_flow_cuts_unsecure"] = []
    result_scopf["convdc_flow_cuts_unsecure"] = []

    result = _PMACDC.run_acdcopf(network, model_type, optimizer)
    if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
        error(_LOGGER, "base-case ACDCOPF solve failed in run_c1_scopf_ptdf_cuts, status $(result["termination_status"])")
    end
    _PMSC.info(_LOGGER, "objective: $(result["objective"])")
    _PM.update_data!(network, result["solution"])
#
    # for (i,bus) in network["bus"]
    #     if haskey(bus, "evhi")
    #         bus["vmax"] = bus["evhi"]
    #     end
    #     if haskey(bus, "evlo")
    #         bus["vmin"] = bus["evlo"]
    #     end
    # end
    # for (i,gen) in network["gen"]
    #     gen["pg_start"] = gen["pg"]
    #     gen["qg_start"] = gen["qg"]
    # end

    # for (i,bus) in network["bus"]
    #     bus["vm_start"] = bus["vm"]
    #     bus["va_start"] = bus["va"]
    # end
#
    for (i,conv) in network["convdc"]
        conv["P_g"] = -result["solution"]["convdc"][i]["pgrid"]
        conv["Q_g"] = result["solution"]["convdc"][i]["qgrid"]
        if conv["type_dc"] == 2
            conv["type_dc"] == 2
        else
            conv["type_dc"] == 1
        end
        # conv["Pdcset"] = solution["convdc"][i]["pdc"]
    end

    # for (i, branch) in network["branch"]
    #     if haskey(result["solution"]["branch"], i)
    #         branch["tap"] = result["solution"]["branch"][i]["tm"]
    #         branch["shift"] = result["solution"]["branch"][i]["ta"]
    #     end
    # end


    result["iterations"] = 0

    iteration = 1
    cuts_found = 1
    while cuts_found > 0
        time_start_iteration = time()

         cuts = check_c1_contingencies_branch_power_GM(network, optimizer, total_cut_limit=iteration, gen_flow_cuts=[], branch_flow_cuts=[])

        cuts_found = 0
        #append!(network["gen_flow_cuts"], cuts.gen_cuts) 
        for cut in cuts.gen_cuts
            if cut.cont_label in [cont_label for (cont_id, cont_label) in network["gen_flow_cuts"]]    
                _PMSC.warn(_LOGGER, "for generator contingency $(cut.cont_label) flow cut $(cut.branch_id) is active but not secure.")
                if !(cut in result_scopf["gen_flow_cuts_unsecure"])
                    push!(result_scopf["gen_flow_cuts_unsecure"], cut)
                end
            else
                push!(network["gen_flow_cuts"], cut)
                # network["gen_flow_cut_vio"] += cuts.gen_flow_cut_vio           # To introduce
                cuts_found += 1
            end
        end

        #append!(network["branch_flow_cuts"], cuts.branch_cuts)
        for cut in cuts.branch_cuts
            if cut.cont_label in [cont_label for (cont_id, cont_label) in network["branch_flow_cuts"]]
                _PMSC.warn(_LOGGER, "for branch contingency $(cut.cont_label) flow cut $(cut.branch_id) is active but not secure.")
                if !(cut in result_scopf["branch_flow_cuts_unsecure"])
                    push!(result_scopf["branch_flow_cuts_unsecure"], cut)
                end
            else
                push!(network["branch_flow_cuts"], cut)
                # network["branch_flow_cut_vio"] += cuts.branch_flow_cut_vio       # To introduce
                cuts_found += 1
            end
        end

        #append!(network["branchdc_flow_cuts"], cuts.branchdc_cuts)
        for cut in cuts.branchdc_cuts
            if cut.cont_label in [cont_label for (cont_id, cont_label) in network["branchdc_flow_cuts"]]         
                _PMSC.warn(_LOGGER, "for branchdc contingency $(cut.cont_label) flow cut $(cut.branchdc_id) is active but not secure.")
                if !(cut in result_scopf["branchdc_flow_cuts_unsecure"])
                    push!(result_scopf["branchdc_flow_cuts_unsecure"], cut)
                end
            else
                push!(network["branchdc_flow_cuts"], cut)
                #network["branchdc_flow_cuts_vio"] += cuts.branchdc_flow_cuts_vio
                cuts_found += 1
            end
        end

        #cuts_found = length(cuts.gen_cuts) + length(cuts.branch_cuts) + length(cuts.branchdc_cuts)

        if cuts_found <= 0
            _PMSC.info(_LOGGER, "no violated cuts found scopf fixed-point reached.")
            break
        else
            _PMSC.info(_LOGGER, "found $(cuts_found) new flow violations.")
        end  

        _PMSC.info(_LOGGER, "active cuts: gen $(length(network["gen_flow_cuts"])), branch $(length(network["branch_flow_cuts"])), branchdc $(length(network["branchdc_flow_cuts"]))")

        time_solve_start = time()
        result = run_scopf_prob(network, model_type, optimizer)
        if !(result["termination_status"] == _PM.OPTIMAL || result["termination_status"] == _PM.LOCALLY_SOLVED || result["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
            _PMSC.warn(_LOGGER, "scopf solve failed with status $(result["termination_status"]), terminating fixed-point early")
            break
        end
        _PMSC.info(_LOGGER, "objective: $(result["objective"])")
        _PM.update_data!(network, result["solution"])

        # for (i,gen) in network["gen"]
        #     gen["pg_start"] = gen["pg"]
        #     gen["qg_start"] = gen["qg"]
        # end
    
        # for (i,bus) in network["bus"]
        #     bus["vm_start"] = bus["vm"]
        #     bus["va_start"] = bus["va"]
        # end
    #
        for (i,conv) in network["convdc"]
            conv["P_g"] = -result["solution"]["convdc"][i]["pgrid"]
            conv["Q_g"] = result["solution"]["convdc"][i]["qgrid"]
            if conv["type_dc"] == 2
                conv["type_dc"] == 2
            else
                conv["type_dc"] == 1
            end
            # conv["Pdcset"] = solution["convdc"][i]["pdc"]
        end

        time_iteration = time() - time_start_iteration
        time_remaining = time_limit - (time() - time_start)
        if time_remaining < time_iteration
            _PMSC.warn(_LOGGER, "insufficent time for next iteration, time remaining $(time_remaining), estimated iteration time $(time_iteration)")
            break
        end
        iteration += 1
    end

    result["iterations"] = iteration
    result_scopf["final"] = result 
    return result_scopf
end