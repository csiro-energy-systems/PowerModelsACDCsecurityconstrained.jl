#Adding new variables for including voilations into the objective function 

function variable_branch_contigency_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    branch_cont_vio = var(pm, nw)[:branch_cont_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :branch_cuts))], base_name="$(nw)_branch_cont_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :branch_cuts))
            JuMP.set_lower_bound(branch_cont_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :branch_cont_vio, :branch_cuts )
end


function variable_gen_contigency_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    gen_cont_vio = var(pm, nw)[:gen_cont_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :gen_cuts))], base_name="$(nw)_gen_cont_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branch_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :gen_cuts))
            JuMP.set_lower_bound(gen_cont_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :gen_cont_vio, :gen_cuts)
end


function variable_branchdc_contigency_violation(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    branchdc_cont_vio = var(pm, nw)[:branchdc_cont_vio] = JuMP.@variable(pm.model,
        [i in 1:length(ref(pm, :branchdc_cuts))], base_name="$(nw)_branchdc_cont_vio",
        #start = _PM.comp_start_value(ref(pm, nw, :bus, i), "cont_branchdc_vio_start")
    )

    if bounded
        for i in 1:length(ref(pm, :branchdc_cuts))
            JuMP.set_lower_bound(branchdc_cont_vio[i], 0.0)
        end
    end

    #report && _PM.sol_component_value(pm, nw, :branchdc_cont_vio, :branchdc_cuts )
end