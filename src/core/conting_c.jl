
"ranks branchdc contingencies and down selects based on evaluation limits"
function calc_c1_branchdc_contingency_subset(network::Dict{String,<:Any}; branchdc_eval_limit=length(network["branchdc_contingencies"]))        
    line_imp_mag = Dict(branchdc["index"] => branchdc["rateA"]*(branchdc["r"]) for (i,branchdc) in network["branchdc"])                       
    branchdc_contingencies =sort(network["branchdc_contingencies"], rev=true, by=x -> line_imp_mag[x.idx])                                     

    branchdc_cont_limit = min(branchdc_eval_limit, length(network["branchdc_contingencies"]))                                                    
    branchdc_contingencies = branchdc_contingencies[1:branchdc_cont_limit]                                            

    return branchdc_contingencies                                                     
end




"ranks converter contingencies and down selects based on evaluation limits"
function calc_convdc_contingency_subset(network::Dict{String,<:Any}; convdc_eval_limit=length(network["convdc_contingencies"]))
    convdc_cap = Dict(convdc["index"] => sqrt(max(abs(convdc["Pacmin"]), abs(convdc["Pacmax"]))^2 + max(abs(convdc["Qacmin"]), abs(convdc["Qacmax"]))^2) for (i,convdc) in network["convdc"])
    convdc_contingencies = sort(network["convdc_contingencies"], rev=true, by=x -> convdc_cap[x.idx])

    convdc_cont_limit = min(convdc_eval_limit, length(network["convdc_contingencies"]))
    convdc_contingencies = convdc_contingencies[1:convdc_cont_limit]

    return convdc_contingencies
end