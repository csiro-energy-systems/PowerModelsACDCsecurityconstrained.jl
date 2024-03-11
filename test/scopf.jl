

file = "./test/data/matpower/case5_acdc_scopf.m"
data = _PM.parse_file(file)
PowerModelsACDCsecurityconstrained.fix_scopf_data_case5_acdc!(data)
PowerModelsACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

@testset "5-bus case" begin
    result = PowerModelsACDCsecurityconstrained.run_scopf_acdc_contingencies(data, PowerModels.ACPPowerModel, PowerModels.ACPPowerModel, PowerModelsACDCsecurityconstrained.run_scopf, nlp_solver, nlp_solver, setting)

    @test result["final"]["termination_status"] == LOCALLY_SOLVED
    @test isapprox(result["final"]["objective"], 252.89929598946964; atol = 1e0)
end