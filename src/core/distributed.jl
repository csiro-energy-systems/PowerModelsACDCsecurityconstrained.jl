

"function to merge distributed contingency evaluation results"
function organize_distributed_conts(conts)
    gen_cuts = []
    branch_cuts = []
    branchdc_cuts = []
    convdc_cuts = []
    active_conts_by_branch = Dict()
    active_conts_by_branchdc = Dict()
    for i in eachindex(conts)
        append!(gen_cuts, conts[i].gen_contingencies)
        append!(branch_cuts, conts[i].branch_contingencies)
        append!(branchdc_cuts, conts[i].branchdc_contingencies)
        append!(convdc_cuts, conts[i].convdc_contingencies)
        merge!(active_conts_by_branch, conts[i].active_conts_by_branch)
        merge!(active_conts_by_branchdc, conts[i].active_conts_by_branchdc)
    end
    return gen_cuts, branch_cuts, branchdc_cuts, convdc_cuts, active_conts_by_branch, active_conts_by_branchdc
end