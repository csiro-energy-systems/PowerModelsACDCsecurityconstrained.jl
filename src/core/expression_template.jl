
function expression_branchdc_powerflow(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    if !haskey(_PM.var(pm, nw), :branchdc_p_fr)
        _PM.var(pm, nw)[:branchdc_p_fr] = Dict{Int,Any}()
    end
    if !haskey(_PM.var(pm, nw), :branchdc_p_to)
        _PM.var(pm, nw)[:branchdc_p_to] = Dict{Int,Any}()
    end
    
    branchdc = _PM.ref(pm, nw, :branchdc, i)
    fr_idx = (i, branchdc["fbusdc"], branchdc["tbusdc"])
    to_idx = (i, branchdc["tbusdc"], branchdc["fbusdc"])

    expression_branchdc_powerflow(pm, nw, i, fr_idx, to_idx)
end




function expression_branch_powerflow(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    if !haskey(_PM.var(pm, nw), :branch_p_fr)
        _PM.var(pm, nw)[:branch_p_fr] = Dict{Int,Any}(i => 0 for i in parse.(Int64, keys(pm.data["branch"])))
    end

    if !haskey(_PM.var(pm, nw), :branch_p_to)
        _PM.var(pm, nw)[:branch_p_to] = Dict{Int,Any}(i => 0 for i in parse.(Int64, keys(pm.data["branch"])))
    end
    
    branch = _PM.ref(pm, nw, :branch, i)
    fr_idx = (i, branch["f_bus"], branch["t_bus"])
    to_idx = (i, branch["t_bus"], branch["f_bus"])

    expression_branch_powerflow(pm, nw, i, fr_idx, to_idx)
end


