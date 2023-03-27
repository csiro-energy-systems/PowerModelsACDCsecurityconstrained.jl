"""
Solves an SCOPF problem for integrated HVAC and HVDC grid by iteratively checking for
violated contingencies and resolving until a fixed-point is reached.

"""
function run_ACDC_scopf_re_dispatch(network::Dict{String,<:Any}, result_ACDC_scopf_soft::Dict{String,<:Any}, model_type::Type, optimizer)   
    result_ACDC_scopf_re_dispatch_oltc_pst = Dict()
    data = deepcopy(network)
    # updating reference point 
    for i = 1:length(data["gen"])
        data["gen"]["$i"]["pgref"] = result_ACDC_scopf_soft["final"]["solution"]["nw"]["0"]["gen"]["$i"]["pg"]
    end 
    # embedding unsecure contingencies
    if haskey(result_ACDC_scopf_soft, "gen_contingencies_unsecure") 
        for (idx, label, type) in result_ACDC_scopf_soft["gen_contingencies_unsecure"]
            data1 = deepcopy(data)
            data1["gen"]["$idx"]["gen_status"] = 0
            result_ACDC_scopf_re_dispatch_oltc_pst["gen$idx"] =  run_acdcreopf_oltc_pst(data1,  model_type, optimizer)
            if (result_ACDC_scopf_re_dispatch_oltc_pst["gen$idx"]["termination_status"] == _PM.OPTIMAL || result_ACDC_scopf_re_dispatch_oltc_pst["gen$idx"]["termination_status"] == _PM.LOCALLY_SOLVED || result_ACDC_scopf_re_dispatch_oltc_pst["gen$idx"]["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
                _PMSC.info(_LOGGER, "generator contingency: $idx is curratively secured")   
            else
                _PMSC.warn(_LOGGER, "generator contingency: $idx cannot be curratively secured")
            end
        end
    end
    if haskey(result_ACDC_scopf_soft, "branch_contingencies_unsecure")
        for (idx, label, type) in result_ACDC_scopf_soft["branch_contingencies_unsecure"]
            data1 = deepcopy(data)
            data1["branch"]["$idx"]["br_status"] = 0
            result_ACDC_scopf_re_dispatch_oltc_pst["branch$idx"] =  run_acdcreopf_oltc_pst(data1, model_type, optimizer)
            if (result_ACDC_scopf_re_dispatch_oltc_pst["branch$idx"]["termination_status"] == _PM.OPTIMAL || result_ACDC_scopf_re_dispatch_oltc_pst["branch$idx"]["termination_status"] == _PM.LOCALLY_SOLVED || result_ACDC_scopf_re_dispatch_oltc_pst["branch$idx"]["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
                _PMSC.info(_LOGGER, "branch contingency: $idx is curratively secured")  
            else
                _PMSC.warn(_LOGGER, "branch contingency: $idx cannot be curratively secured")
            end
        end
    end
    if haskey(result_ACDC_scopf_soft, "branchdc_contingencies_unsecure") 
        for (idx, label, type) in result_ACDC_scopf_soft["branchdc_contingencies_unsecure"]
            data1 = deepcopy(data)
            data1["branchdc"]["$idx"]["status"] = 0
            result_ACDC_scopf_re_dispatch_oltc_pst["branchdc$idx"] =  run_acdcreopf_oltc_pst(data1, model_type, optimizer)
            if (result_ACDC_scopf_re_dispatch_oltc_pst["branchdc$idx"]["termination_status"] == _PM.OPTIMAL || result_ACDC_scopf_re_dispatch_oltc_pst["branchdc$idx"]["termination_status"] == _PM.LOCALLY_SOLVED || result_ACDC_scopf_re_dispatch_oltc_pst["branchdc$idx"]["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
                _PMSC.info(_LOGGER, "branchdc contingency: $idx is curratively secured")  
            else
                _PMSC.warn(_LOGGER, "branchdc contingency: $idx cannot be curratively secured")
            end
        end
    end
    if haskey(result_ACDC_scopf_soft, "convdc_contingencies_unsecure") 
        for (idx, label, type) in result_ACDC_scopf_soft["convdc_contingencies_unsecure"]
            data1 = deepcopy(data)
            data1["convdc"]["$idx"]["status"] = 0
            result_ACDC_scopf_re_dispatch_oltc_pst["convdc$idx"] =  run_acdcreopf_oltc_pst(data1, model_type, optimizer)
            if (result_ACDC_scopf_re_dispatch_oltc_pst["convdc$idx"]["termination_status"] == _PM.OPTIMAL || result_ACDC_scopf_re_dispatch_oltc_pst["convdc$idx"]["termination_status"] == _PM.LOCALLY_SOLVED || result_ACDC_scopf_re_dispatch_oltc_pst["convdc$idx"]["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
                _PMSC.info(_LOGGER, "convdc contingency: $idx is curratively secured")   
            else
                _PMSC.warn(_LOGGER, "convdc contingency: $idx cannot be curratively secured")
            end
        end
    end
    return  result_ACDC_scopf_re_dispatch_oltc_pst
end