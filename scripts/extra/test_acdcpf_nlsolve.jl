
########## Test file for sequential ac-dc power flow using _PM.calculate_ac_pf

using Ipopt
using JuMP
using PowerModels
using PowerModelsACDC
using SparseArrays
using NLsolve
using Memento

const _PM = PowerModels
const _PMACDC = PowerModelsACDC
const _LOGGER = Memento.getlogger(@__MODULE__)

file = "./data/case5_acdc_scopf.m"
data = _PM.parse_file(file)
_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6)

result_acdcpf = _PMACDC.run_acdcpf(data, _PM.ACPPowerModel, nlp_solver, setting=setting )

for (c, conv) in result_acdcpf["solution"]["convdc"]
    println("converter $c ptf = $(conv["pgrid"])")
    println("converter $c qtf = $(conv["qgrid"])")
    println("converter $c ptf = $(conv["pconv"])")
    println("converter $c qtf = $(conv["qconv"])")
    println("..... converter $c pdc = $(conv["pdc"])")
end
for (b, bus) in result_acdcpf["solution"]["busdc"]
    println("busdc $b Vdc = $(bus["vm"])")
end

include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/core/add_injections.jl")
include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/core/converter_quantities.jl")
include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/core/dcpf_struct.jl")
include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/core/acdcpf_seq.jl")


function compute_sacdc_pf(data)
   
    # STEP 1: Add converter injections as additional injections, e.g. generators
    add_converter_injections!(data)

    # STEP 2: Calculate AC power flow
    result = _PM.compute_ac_pf(data)

    result_sacdcpf = Dict{String,Any}()
    result_sacdcpf["iterations"] = 0
    iteration = 1
    convergence = 1
    time_start_iteration = time()
    while convergence > 0
        # STEP 3: Calculate converter voltages, currents, losses, and DC side PowerModels
        conv_qnts = compute_converter_quantities(result["solution"], data)
        println(".............. $(conv_qnts["2"]["Pdc"])")
        vm_p = Float64[]
        va_p = Float64[]
        for (i,bus) in data["bus"]
            push!(vm_p, result["solution"]["bus"]["$i"]["vm"])
            push!(va_p, result["solution"]["bus"]["$i"]["va"])
        end

        # STEP 4: Calculate DC grid power flows
        resultdc = compute_dc_pf(data, conv_qnts)

        # STEP 5: Calculate AC power injections from slack converter_quantities

        pgrid_slack, slack_gen_id = compute_slack_converter_ac_injection(resultdc["solution"], data, conv_qnts)

        # STEP 6: Update slack converter injection
        data["gen"]["$slack_gen_id"]["pg"] = pgrid_slack

        print("Pgslack = $pgrid_slack\n")

        # STEP 7: Re-calculate AC power flows
        result = _PM.compute_ac_pf(data)

        # STEP 8: Check "vm" and "va" for convergence
        vm_c = Float64[]
        va_c = Float64[]
        for (j,bus) in data["bus"]
            push!(vm_c, result["solution"]["bus"]["$j"]["vm"])
            push!(va_c, result["solution"]["bus"]["$j"]["va"])
        end

        if isapprox(vm_p,vm_c; atol = 0.001) && isapprox(abs.(va_p), abs.(va_c); atol = 0.001)
            convergence = 0
            Memento.info(_LOGGER, "sequential ac-dc power flow has converged in iteration $iteration.")
        end

        iteration += 1
        print("iteration = $iteration\n")
    end
    result_sacdcpf["time_iteration"] = time() - time_start_iteration
    result_sacdcpf["iterations"] = iteration

    return result_sacdcpf
end

result = compute_sacdc_pf(data)

