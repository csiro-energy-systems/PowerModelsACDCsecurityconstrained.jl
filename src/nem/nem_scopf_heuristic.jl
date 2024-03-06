
# Script for AC-DC SCOPF implementation on SNEM2000acdc using flow cuts

using Ipopt
using JuMP
using PowerModels
using PowerModelsACDC
using PowerModelsSecurityConstrained
using PowerModelsACDCsecurityconstrained
using InfrastructureModels
using Memento
using IterativeSolvers
using Distributed

# Distributed.clear!

max_node_processes = 32

node_processes = min(Sys.CPU_THREADS - 2, max_node_processes)

if Distributed.nprocs() >= 2
    return
end

Distributed.addprocs(node_processes, topology=:master_worker)

@everywhere begin
    using Ipopt
    using JuMP
    using PowerModels
    using PowerModelsACDC
    using PowerModelsSecurityConstrained
    using PowerModelsACDCsecurityconstrained
    using InfrastructureModels
    using Memento
    using IterativeSolvers

    nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0) 

    const _PM = PowerModels
    const _PMSC = PowerModelsSecurityConstrained
    const _PMSCACDC = PowerModelsACDCsecurityconstrained
    const _PMACDC = PowerModelsACDC
    const _DI = Distributed
    const _IM = InfrastructureModels
    const _LOGGER = Memento.getlogger(@__MODULE__)
    const _IS = IterativeSolvers

    # include helper functions
    include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/core/distributed.jl")
    include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/util/ndc_filter.jl")
    include("C:/Users/moh050/OneDrive - CSIRO/Documents/Local/PowerModelsACDCsecurityconstrained/src/util/contingency_filter.jl")
    
    # suppress warn and info from other packages
    _PMSCACDC.silence()
end

file = "./test/data/matpower/snem2000_acdc.m"
data = parse_file(file)
_PMSCACDC.fix_scopf_data_issues!(data)

# modifying peak minimum load
# for (i, load) in data["load"]
#     load["pd"] = 0.85*load["pd"]
#     load["qd"] = 0.85*load["qd"]
# end
# Adding REZs
# gen_id = [gen["index"] for (i,gen) in data["gen"] if gen["pmax"] == 0]
# for i in gen_id
#     data["gen"]["$i"]["pmax"] = 0.6
# end

# file = "./test/data/case5_acdc_scopf.m"
# data = _PM.parse_file(file)
# _PMSCACDC.fix_scopf_data_case5_acdc!(data)

data["convdc_contingencies"] = []
_PMACDC.process_additional_data!(data)
setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

network = deepcopy(data) 
    
result_base = _PMACDC.run_acdcopf(network, _PM.ACPPowerModel, nlp_solver)
if !(result_base["termination_status"] == _PM.OPTIMAL || result_base["termination_status"] == _PM.LOCALLY_SOLVED || result_base["termination_status"] == _PM.ALMOST_LOCALLY_SOLVED)
    Memento.error(_LOGGER, "base-case ACDCOPF solve failed in run_c1_scopf_ptdf_cuts, status $(result_base["termination_status"])")
end
Memento.info(_LOGGER, "objective: $(result_base["objective"])")

_PM.update_data!(network, result_base["solution"])
_PMSCACDC.update_data_converter_setpoints!(network, result_base["solution"])

# add loss distribution factors and total loss
_PMSCACDC.add_losses_and_loss_distribution_factors!(network)  
     
# time_worker_start = time()
    
workers = _DI.workers()
# Memento.info(_LOGGER, "start warmup on $(length(workers)) workers")
    
worker_futures = []
for wid in workers
    future = _DI.remotecall(load_network_global_new, wid, network)
    push!(worker_futures, future)
end
# setup for contigency solve
gen_cont_total = length(network["gen_contingencies"])
branch_cont_total = length(network["branch_contingencies"])
branchdc_cont_total = length(network["branchdc_contingencies"])
convdc_cont_total = length(network["convdc_contingencies"])
cont_total = gen_cont_total + branch_cont_total + branchdc_cont_total + convdc_cont_total
cont_per_proc = cont_total/length(workers)

cont_order = contingency_order(network)

cont_range = []
for p in 1:length(workers)
    cont_start = trunc(Int, ceil(1+(p-1)*cont_per_proc))
    cont_end = min(cont_total, trunc(Int,ceil(p*cont_per_proc)))
    push!(cont_range, cont_start:cont_end,)
end

# for (i,rng) in enumerate(cont_range)
    # Memento.info(_LOGGER, "task $(i): $(length(rng)) / $(rng)")
# end
    
# Memento.info(_LOGGER, "waiting for worker warmup to complete: $(time())")
for future in worker_futures
    wait(future)
end 

# time_worker = time() - time_worker_start
# Memento.info(_LOGGER, "total worker warmup time: $(time_worker)")
    
# result_scopf = Dict{String,Any}()
iteration  = 1
# while true
    # time_start_iteration = time()
    # contingency evaluation 
    t_conts = @elapsed @time conts = _DI.pmap(check_contingency_violations_distributed_remote, cont_range, [iteration for p in 1:length(workers)], distributed=true, batch_size=1)
    # Memento.info(_LOGGER, "total contingencies found: $(length(conts))")

    # function to merge distributed contingency evaluation results
    t_conts_org = @elapsed gen_cuts, branch_cuts, branchdc_cuts, convdc_cuts, active_conts_by_branch, active_conts_by_branchdc = organize_distributed_conts(conts)

    # filtering dominated contingencies
    t_conts_ndc = @elapsed conts_ndc =  filter_non_dominated_contingencies(gen_cuts, branch_cuts, branchdc_cuts, convdc_cuts, active_conts_by_branch, active_conts_by_branchdc)

    # update the contingency sets in network data set
    network["gen_contingencies"] = conts_ndc.gen_contingencies
    network["branch_contingencies"] = conts_ndc.branch_contingencies
    network["branchdc_contingencies"] = conts_ndc.branchdc_contingencies
    network["convdc_contingencies"] = conts_ndc.convdc_contingencies

    # solving ac-dc scopf heuristic with ptdf and dcdf cuts
    t_scopf = @elapsed @time result_scopf = _PMSCACDC.run_scopf_acdc_cuts_remote(network, _PM.ACPPowerModel, _PM.DCPPowerModel, _PMSCACDC.run_acdc_scopf_cuts_soft, nlp_solver, nlp_solver, setting)
 
    # if result_scopf["final"]["iterations"] < 2
    #     time_iteration = time() - time_start_iteration
    #     Memento.info(_LOGGER, "iteration time: $(time_iteration)")
    #     break
    # end
   
    # update results
    # _PM.update_data!(network, result_scopf["final"]["solution"])
    # _PMSCACDC.update_data_converter_setpoints!(network, result_scopf["final"]["solution"])
    # iteration += 1
# end


