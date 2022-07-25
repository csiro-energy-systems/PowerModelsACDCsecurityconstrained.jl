function calc_c1_branchdc_contingency_subset(network::Dict{String,<:Any}; branchdc_eval_limit=length(network["branchdc_contingencies"]))        


    line_imp_mag = Dict(branchdc["index"] => branchdc["rateA"]*(branchdc["r"]) for (i,branchdc) in network["branchdc"])                       

    branchdc_contingencies =sort(network["branchdc_contingencies"], rev=true, by=x -> line_imp_mag[x.idx])                                     

    branchdc_cont_limit = min(branchdc_eval_limit, length(network["branchdc_contingencies"]))                                                    

    branchdc_contingencies = branchdc_contingencies[1:branchdc_cont_limit]                                            

    return branchdc_contingencies                                                     
end


