

function expression_branchdc_powerflow(pm::_PM.AbstractPowerModel, n::Int, i::Int, fr_idx, to_idx)
    p_dcgrid = get(_PM.var(pm, n), :p_dcgrid, Dict())

    # parallel lines not supported

    _PM.var(pm, n, :branchdc_p_fr)[i] = p_dcgrid[fr_idx]
    _PM.var(pm, n, :branchdc_p_to)[i] = p_dcgrid[to_idx]
end


function expression_branch_powerflow(pm::_PM.AbstractPowerModel, n::Int, i::Int, fr_idx, to_idx)
    pf = get(_PM.var(pm, n), :p, Dict())

    _PM.var(pm, n, :branch_p_fr)[i] = pf[fr_idx]
    _PM.var(pm, n, :branch_p_to)[i] = pf[to_idx]
end