# a global network variable used for iterative computations
# network_global = Dict{String,Any}()

# # a global contingency list used for iterative computations
# contingency_order_global = []

function load_network_global(network)
    Memento.info(_LOGGER, "loading global network data")

    global network_global = network          
    global contingency_order_global = contingency_order(network_global)

    return 0
end

function contingency_order(network)
    gen_cont_order = sort(network["gen_contingencies"], by=(x) -> x.label)
    branch_cont_order = sort(network["branch_contingencies"], by=(x) -> x.label)
    branchdc_cont_order = sort(network["branchdc_contingencies"], by=(x) -> x.label)
    convdc_cont_order = sort(network["convdc_contingencies"], by=(x) -> x.label)

    gen_cont_total = length(gen_cont_order)
    branch_cont_total = length(branch_cont_order)
    branchdc_cont_total = length(branchdc_cont_order)
    convdc_cont_total = length(convdc_cont_order)

    # gen_rate = 1.0
    # branch_rate = 1.0
    # branchdc_rate = 1.0
    # convdc_rate = 1.0

    # steps = 1
    # if gen_cont_total == 0 && branch_cont_total == 0
    #     # defaults are good
    # elseif gen_cont_total == 0 && branch_cont_total != 0
    #     steps = branch_cont_total
    # elseif gen_cont_total != 0 && branch_cont_total == 0
    #     steps = gen_cont_total
    # elseif gen_cont_total == branch_cont_total
    #     steps = branch_cont_total
    # elseif gen_cont_total < branch_cont_total
    #     gen_rate = 1.0
    #     branch_rate = branch_cont_total/gen_cont_total
    #     steps = gen_cont_total
    # elseif gen_cont_total > branch_cont_total
    #     gen_rate = gen_cont_total/branch_cont_total
    #     branch_rate = 1.0 
    #     steps = branch_cont_total
    # end

    cont_order = []
    # gen_cont_start = 1
    # branch_cont_start = 1
    # for s in 1:steps
    #     gen_cont_end = min(gen_cont_total, trunc(Int,ceil(s*gen_rate)))
    #     #println(gen_cont_start:gen_cont_end)
    #     for j in gen_cont_start:gen_cont_end
    #         push!(cont_order, gen_cont_order[j])
    #     end
    #     gen_cont_start = gen_cont_end+1

    #     branch_cont_end = min(branch_cont_total, trunc(Int,ceil(s*branch_rate)))
    #     #println("$(s) - $(branch_cont_start:branch_cont_end)")
    #     for j in branch_cont_start:branch_cont_end
    #         push!(cont_order, branch_cont_order[j])
    #     end
    #     branch_cont_start = branch_cont_end+1
    # end

    append!(cont_order, gen_cont_order)
    append!(cont_order, branch_cont_order)
    append!(cont_order, branchdc_cont_order)
    append!(cont_order, convdc_cont_order)

    @assert(length(cont_order) == gen_cont_total + branch_cont_total + branchdc_cont_total + convdc_cont_total)

    return cont_order
end

function check_contingency_violations_distributed_remote(cont_range, cont_num; kwargs...)
    if length(network_global) <= 0 || length(contingency_order_global) <= 0
        Memento.error(_LOGGER, "check_contingency_violations_distributed_remote called before load_network_global_new")
    end

    # warm start
    # sol = read_solution(network_global, output_dir=output_dir, state_file=solution_file)
    # _PM.update_data!(network_global, sol)
    # _PMSCACDC.update_data_converter_setpoints!(network_global, sol)

    # update active cuts
    # active_cuts = read_active_flow_cuts(output_dir=output_dir)
    # gen_flow_cuts = []
    # branch_flow_cuts = []
    # branchdc_flow_cuts = []
    # for cut in active_cuts
    #     if cut.cont_type == "gen"
    #         push!(gen_flow_cuts, cut)
    #     elseif cut.cont_type == "branch"
    #         push!(branch_flow_cuts, cut)
    #     elseif cut.cont_type == "branchdc"
    #         push!(branchdc_flow_cuts, cut)
    #     elseif cut.cont_type == "convdc"
    #         push!(convdc_flow_cuts, cut)
    #     else
    #         Memento.warn(_LOGGER, "unknown contingency type in cut $(cut)")
    #     end
    # end
    
    nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)
    network = deepcopy(network_global)
    contingencies = contingency_order_global[cont_range]
    setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
    network["gen_contingencies"] = [c for c in contingencies if c.type == "gen"]
    network["branch_contingencies"] = [c for c in contingencies if c.type == "branch"]
    network["branchdc_contingencies"] = [c for c in contingencies if c.type == "branchdc"]
    network["convdc_contingencies"] = [c for c in contingencies if c.type == "convdc"]

    cuts = check_contingency_violations_distributed(network, _PM.DCPPowerModel, nlp_solver, setting)

    return cuts
end

function check_contingency_violations_distributed(network, model_type, optimizer, setting;
    gen_contingency_limit=5000, branch_contingency_limit=5000, branchdc_contingency_limit=5000, 
    convdc_contingency_limit=5000, contingency_limit=typemax(Int64),gen_eval_limit=typemax(Int64),
    branch_eval_limit=typemax(Int64), branchdc_eval_limit=typemax(Int64), convdc_eval_limit=typemax(Int64), 
    sm_threshold=0.01, smdc_threshold=0.01, pg_threshold=0.01, qg_threshold=0.01,vm_threshold=0.01)     

    if _IM.ismultinetwork(network)
        error(_LOGGER, "the check_contingency_violations_distributed can only be used on single networks")
    end

    time_contingencies_start = time()

    network_lal = deepcopy(network)     # lal -> losses as loads

    gen_pg_init = Dict(i => gen["pg"] for (i,gen) in network_lal["gen"])
    load_active = Dict(i => load for (i, load) in network_lal["load"] if load["status"] != 0)
    pd_total = sum(load["pd"] for (i,load) in load_active)
    p_losses = sum(gen["pg"] for (i,gen) in network_lal["gen"] if gen["gen_status"] != 0) - pd_total
   
    if model_type <: _PM.DCPPowerModel
        p_delta = 0.0
        if p_losses > C1_PG_LOSS_TOL
            load_count = length(load_active)
            p_delta = p_losses/load_count
            for (i,load) in load_active
                load["pd"] += p_delta
            end
            Memento.warn(_LOGGER, "ac active power losses found $(p_losses) increasing loads by $(p_delta)")         
        end
    end
    
    gen_contingencies = network["gen_contingencies"]
    branch_contingencies = network["branch_contingencies"]
    branchdc_contingencies = network["branchdc_contingencies"]
    convdc_contingencies = network["convdc_contingencies"]

    active_conts_by_branch = Dict()
    active_conts_by_branchdc = Dict()
    
    gen_cuts = []
    gen_cut_vio = 0.0
    for (i,cont) in enumerate(gen_contingencies)
        for (i,gen) in network_lal["gen"]
            gen["pg"] = gen_pg_init[i]
        end

        cont_gen = network_lal["gen"]["$(cont.idx)"]
        pg_lost = cont_gen["pg"]

        cont_gen["gen_status"] = 0
        cont_gen["pg"] = 0.0

        gen_bus = network_lal["bus"]["$(cont_gen["gen_bus"])"]
        gen_set = network_lal["area_gens"][gen_bus["area"]]

        gen_active = Dict(i => gen for (i,gen) in network_lal["gen"] if gen["index"] != cont.idx && gen["index"] in gen_set && gen["gen_status"] != 0)

        alpha_gens = [gen["alpha"] for (i,gen) in gen_active]
        if length(alpha_gens) == 0 || isapprox(sum(alpha_gens), 0.0)
            Memento.warn(_LOGGER, "no available active power response in cont $(cont.label), active gens $(length(alpha_gens))") 
            continue
        end

        alpha_total = sum(alpha_gens)
        delta = pg_lost/alpha_total
        network_lal["delta"] = delta
        # Memento.info(_LOGGER, "$(pg_lost) - $(alpha_total) - $(delta)")

        for (i,gen) in gen_active
            gen["pg"] += gen["alpha"]*delta
        end

        try
            solution =  _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")    
            continue
        end

        vio = calc_violations(network_lal, network_lal, return_vio_data = true)
            
        # if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > smdc_threshold
            if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                const_akeys = collect(keys(vio.vio_data["branch"]))
                push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
            end
            if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
            end
            if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                const_akeys = collect(keys(vio.vio_data["branch"]))
                const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                else
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
            end
            Memento.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")          
            push!(gen_cuts, cont)
            gen_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
        else
            gen_cut_vio = 0.0
        end
            
        cont_gen["gen_status"] = 1
        cont_gen["pg"] = pg_lost
        network_lal["delta"] = 0.0        
    end
    
    branch_cuts = []
    branch_cut_vio = 0.0
    for (i,cont) in enumerate(branch_contingencies)
        cont_branch = network_lal["branch"]["$(cont.idx)"]
        cont_branch["br_status"] = 0
        _PMACDC.fix_data!(network_lal)

        try
            solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")
            continue
        end
            
        vio = calc_violations(network_lal, network_lal, return_vio_data = true)          
            
        # if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > sm_threshold
            if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                const_akeys = collect(keys(vio.vio_data["branch"]))
                push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
            end
            if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
            end
            if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                const_akeys = collect(keys(vio.vio_data["branch"]))
                const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                else
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
            end
            Memento.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")                           
            push!(branch_cuts, cont)
            branch_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
        else
            branch_cut_vio = 0.0
        end

        cont_branch["br_status"] = 1
    end
    
    branchdc_cuts = []       
    branchdc_cut_vio = 0.0
    for (i,cont) in enumerate(branchdc_contingencies)       
        cont_branchdc = network_lal["branchdc"]["$(cont.idx)"]            
        cont_branchdc["status"] = 0                                       

        try
            solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")     
            continue
        end

        vio = calc_violations(network_lal, network_lal, return_vio_data = true)          
   
        # if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.smdc > sm_threshold || vio.smdc > sm_threshold
            if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                const_akeys = collect(keys(vio.vio_data["branch"]))
                push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
            end
            if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
            end
            if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                const_akeys = collect(keys(vio.vio_data["branch"]))
                const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                else
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
            end
                Memento.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")       
                push!(branchdc_cuts, cont)
                branchdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
        else
            branchdc_cut_vio = 0.0
        end

        cont_branchdc["status"] = 1
    end

    convdc_cuts = []  
    convdc_cut_vio = 0.0
    for (i,cont) in enumerate(convdc_contingencies)        
        cont_convdc = network_lal["convdc"]["$(cont.idx)"]            
        cont_convdc["status"] = 0                                       

        try
            solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")     
            continue
        end

        vio = calc_violations(network_lal, network_lal, return_vio_data = true)           

        # if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold || vio.cmac > sm_threshold || vio.cmdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > sm_threshold 
            if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                const_akeys = collect(keys(vio.vio_data["branch"]))
                push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
            end
            if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
            end
            if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                const_akeys = collect(keys(vio.vio_data["branch"]))
                const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                else
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
            end
            Memento.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")          
            push!(convdc_cuts, cont)
            convdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
        else
            convdc_cut_vio = 0.0
        end

        cont_convdc["status"] = 1
    end

    if model_type <: _PM.DCPPowerModel
        if p_delta != 0.0
            Memento.warn(_LOGGER, "re-adjusting ac loads by $(-p_delta)")       
            for (i,load) in load_active
                load["pd"] -= p_delta
            end
        end
    end
    
    time_contingencies = time() - time_contingencies_start
    Memento.info(_LOGGER, "contingency eval time: $(time_contingencies)")       

    return (gen_contingencies=gen_cuts, branch_contingencies=branch_cuts, branchdc_contingencies=branchdc_cuts, convdc_contingencies=convdc_cuts, active_conts_by_branch=active_conts_by_branch, active_conts_by_branchdc=active_conts_by_branchdc)
end

function filter_dominated_contingencies(gen_cuts, branch_cuts, branchdc_cuts, convdc_cuts, active_conts_by_branch, active_conts_by_branchdc)

    dominated_contingencies = []
    if !isempty(gen_cuts)
        for contn in gen_cuts
            for (i, x) in active_conts_by_branch
                if haskey(active_conts_by_branch, "$(contn.label)")
                    if active_conts_by_branch["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branch["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branch, i)
                            Memento.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            Memento.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
            end
        end
    end

    if !isempty(branch_cuts)
        for contn in branch_cuts
            for (i, x) in active_conts_by_branch
                if haskey(active_conts_by_branch, "$(contn.label)")
                    if active_conts_by_branch["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branch["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branch, i)
                            Memento.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            Memento.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
            end
        end
    end

    if !isempty(branchdc_cuts)
        for contn in branchdc_cuts
            for (i, x) in active_conts_by_branch
                if haskey(active_conts_by_branch, "$(contn.label)")
                    if active_conts_by_branch["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branch["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branch, i)
                            Memento.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            Memento.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
            end
        end
    end

    if !isempty(convdc_cuts)
        for contn in convdc_cuts
            for (i, x) in active_conts_by_branch
                if haskey(active_conts_by_branch, "$(contn.label)")
                    if active_conts_by_branch["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branch["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branch, i)
                            Memento.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            Memento.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
            end
        end
    end

    gen_cuts_delete_index =[]
    if !isempty(gen_cuts)
        for (i,contn) in enumerate(gen_cuts)            
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                push!(gen_cuts_delete_index, findfirst(isequal(contn), gen_cuts))  
                Memento.info(_LOGGER, "gen contingency $(contn.label) removed")
            end
        end
        deleteat!(gen_cuts, sort(gen_cuts_delete_index[1:length(gen_cuts_delete_index)]) )            
    end
    branch_cuts_delete_index =[]
    if !isempty(branch_cuts)
        for (i,contn) in enumerate(branch_cuts)            
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                push!(branch_cuts_delete_index, findfirst(isequal(contn), branch_cuts))  
                Memento.info(_LOGGER, "branch contingency $(contn.label) removed")
            end
        end
        deleteat!(branch_cuts, sort(branch_cuts_delete_index[1:length(branch_cuts_delete_index)]) )           
    end

    branchdc_cuts_delete_index =[]
    if !isempty(branchdc_cuts)
        for (i,contn) in enumerate(branchdc_cuts)            
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                push!(branchdc_cuts_delete_index, findfirst(isequal(contn), branchdc_cuts))  
                Memento.info(_LOGGER, "branchdc contingency $(contn.label) removed")
            end
        end
        deleteat!(branchdc_cuts, sort(branchdc_cuts_delete_index[1:length(branchdc_cuts_delete_index)]) )            
    end

    convdc_cuts_delete_index =[]
    if !isempty(convdc_cuts)
        for (i,contn) in enumerate(convdc_cuts)            
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                push!(convdc_cuts_delete_index, findfirst(isequal(contn), convdc_cuts))  
                Memento.info(_LOGGER, "convdc contingency $(contn.label) removed")
            end
        end
        deleteat!(convdc_cuts, sort(convdc_cuts_delete_index[1:length(convdc_cuts_delete_index)]) )           
    end
 

    return (gen_contingencies=gen_cuts, branch_contingencies=branch_cuts, branchdc_contingencies=branchdc_cuts, convdc_contingencies=convdc_cuts) 
end

