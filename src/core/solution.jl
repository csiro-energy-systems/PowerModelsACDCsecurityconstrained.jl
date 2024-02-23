"""
    solution_processor(pm, solution)

Can be used to add extra values to the solution result set
"""
function solution_processor(pm::_PM.AbstractPowerModel, solution::Dict{String, Any})
    solution["dual_objective"] = JuMP.dual_objective_value(pm.model)
    # solution["lambda1"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[1]"))
    # solution["lambda2"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[2]"))
    # solution["lambda3"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[3]"))
    # solution["lambda4"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[4]"))
    # solution["lambda5"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[5]"))
    # solution["lambda6"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[6]"))
    # solution["lambda7"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[7]"))
    # solution["lambda8"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[8]"))
    # solution["lambda9"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[9]"))
    # solution["lambda10"] = JuMP.value(JuMP.variable_by_name(pm.model, "0_2_pg_cost_lambda[10]"))
end