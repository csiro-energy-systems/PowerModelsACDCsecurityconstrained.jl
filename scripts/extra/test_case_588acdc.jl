using Pkg
Pkg.activate("./scripts")

using Ipopt
using Cbc
using Juniper
using HiGHS
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained


const PM = PowerModels
const PM_acdc = PowerModelsACDC
const PM_sc = PowerModelsSecurityConstrained
const PM_acdc_sc = PowerModelsACDCsecurityconstrained


nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time" => 3600.0)  # "print_level"=>0, "tol"=>1e-6
# lp_solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
# mip_solver = optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
# minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nlp_solver, "mip_solver"=>mip_solver)

file = "./data/pglib_opf_case588_sdet_acdc_sc.m"
data = parse_file(file)

idx_ac = [contingency["branch_id1"] for (i, contingency) in data["contingencies"]]
idx_dc = [contingency["dcbranch_id1"] for (i, contingency) in data["contingencies"]]
idx_gen = [contingency["gen_id1"] for (i, contingency) in data["contingencies"]]
idx_convdc = [contingency["dcconv_id1"] for (i, contingency) in data["contingencies"]]
labels = [contingency["source_id"][2] for (i, contingency) in data["contingencies"]]

data["branch_contingencies"] = [(idx = id, label = string(labels[i]), type = "branch") for (i,id) in enumerate(idx_ac) if id != 0]
data["branchdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "branchdc") for (i,id) in enumerate(idx_dc) if id != 0]
data["gen_contingencies"] = [(idx = id, label = string(labels[i]), type = "gen") for (i,id) in enumerate(idx_gen) if id != 0]
data["convdc_contingencies"] = [(idx = id, label = string(labels[i]), type = "convdc") for (i,id) in enumerate(idx_convdc) if id != 0]

gen1 =[]
gen2 =[]
gen3 =[]
gen4 =[]
gen5 =[]
gen6 =[]
gen7 =[]
gen8 =[]

for (i, gen) in data["gen"]
    if gen["gen_bus"] <= 65
        if !(gen["index"] in gen1)
            push!(gen1, gen["index"]) 
        end
    elseif gen["gen_bus"] <= 130
        if !(gen["index"] in gen2)
            push!(gen2, gen["index"])
        end
    elseif gen["gen_bus"] <= 180
        if !(gen["index"] in gen3)
            push!(gen3, gen["index"])
        end
    elseif gen["gen_bus"] <= 230
        if !(gen["index"] in gen4)
            push!(gen4, gen["index"])
        end
    elseif gen["gen_bus"] <= 351
        if !(gen["index"] in gen5)
            push!(gen5, gen["index"])
        end
    elseif gen["gen_bus"] <= 418
        if !(gen["index"] in gen6)
            push!(gen6, gen["index"])
        end
    elseif gen["gen_bus"] <= 535
        if !(gen["index"] in gen7)
            push!(gen7, gen["index"])
        end
    elseif gen["gen_bus"] <= 588
        if !(gen["index"] in gen8)
        push!(gen8, gen["index"])
        end
    end
end


data["area_gens"] = Dict{Int64, Set{Int64}}()
data["area_gens"][1] = Set([21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
data["area_gens"][2] = Set([42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22])
data["area_gens"][3] = Set([60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43])
data["area_gens"][4] = Set([78, 77, 76, 75, 74, 73, 72, 71, 70, 69, 68, 67, 66, 65, 64, 63, 62, 61])
data["area_gens"][5] = Set([94, 93, 92, 91, 90, 89, 88, 87, 86, 85, 84, 83, 82, 81, 80, 79])
data["area_gens"][6] = Set([130, 129, 128, 127, 126, 125, 124, 123, 122, 121, 120, 119, 118, 117, 116, 115, 114, 113, 112, 111, 110, 109, 108, 107, 106, 105, 104, 103, 102, 101, 100, 99, 98, 97, 96, 95])
data["area_gens"][7] = Set([150, 149, 148, 147, 146, 145, 144, 143, 142, 141, 140, 139, 138, 137, 136, 135, 134, 133, 132, 131])
data["area_gens"][8] = Set([167, 166, 165, 164, 163, 162, 161, 160, 159, 158, 157, 156, 155, 154, 153, 152, 151])

data["contingencies"] = []  # This to empty the existing contingencies in the data

for i=1:length(data["gen"])
    data["gen"]["$i"]["ep"] = 1e-1
end

for i=1:length(data["convdc"])
    data["convdc"]["$i"]["ep"] = 1e-1
    data["convdc"]["$i"]["Vdclow"] = 0.98
    data["convdc"]["$i"]["Vdchigh"] = 1.02
end
for i=1:length(data["gen"])
    data["gen"]["$i"]["alpha"] = 15.92
end 

for i=1:length(data["branch"])
    if data["branch"]["$i"]["tap"] !== 1 
        data["branch"]["$i"]["tm_min"] = 0.9
        data["branch"]["$i"]["tm_max"] = 1.1
    end
    if data["branch"]["$i"]["tap"] == 1 
        data["branch"]["$i"]["tm_min"] = 1
        data["branch"]["$i"]["tm_max"] = 1
    end
    if data["branch"]["$i"]["shift"] !== 0
        data["branch"]["$i"]["ta_min"] = -15
        data["branch"]["$i"]["ta_max"] = 15
    end
    if data["branch"]["$i"]["shift"] == 0
        data["branch"]["$i"]["ta_min"] = 0
        data["branch"]["$i"]["ta_max"] = 0
    end
end

for (i,branch) in data["branch"]
    branch["rate_a"] = min(branch["rate_a"], branch["rate_b"], branch["rate_c"])
    branch["rate_c"] = max(branch["rate_a"], branch["rate_b"], branch["rate_c"])
end

PM_acdc.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
data_SI = deepcopy(data)
@time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data_SI, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations_SI, nlp_solver, setting) 

# @time result_ACDC_scopf_soft = PM_acdc_sc.run_ACDC_scopf_contigency_cuts(data, PM.ACPPowerModel, PM_acdc_sc.run_scopf_soft, PM_acdc_sc.check_contingency_violations, nlp_solver, setting) 