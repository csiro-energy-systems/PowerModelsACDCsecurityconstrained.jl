"""
This function checks a given operating point against the contingencies to look
for branch HVAC and HVDC flow violations. The ACDC Power Flow is used for flow
simulation. It returns a list of contingencies where a violation is found.

"""

function filter_dominated_contingencies(network, model_type, optimizer, setting;
    gen_contingency_limit=5000, branch_contingency_limit=5000, branchdc_contingency_limit=5000, convdc_contingency_limit=5000, contingency_limit=typemax(Int64),gen_eval_limit=typemax(Int64),
    branch_eval_limit=typemax(Int64), branchdc_eval_limit=typemax(Int64), convdc_eval_limit=typemax(Int64), sm_threshold=0.01, smdc_threshold=0.01, pg_threshold=0.01, qg_threshold=0.01,vm_threshold=0.01)     # Update_GM

    ### results_c = Dict{String,Any}()

    if _IM.ismultinetwork(network)
        error(_LOGGER, "the branch flow cut generator can only be used on single networks")
    end
    time_contingencies_start = time()

    network_lal = deepcopy(network)     # lal -> losses as loads

    #ref_bus_id = _PM.reference_bus(network_lal)["index"]

    gen_pg_init = Dict(i => gen["pg"] for (i,gen) in network_lal["gen"])

    load_active = Dict(i => load for (i, load) in network_lal["load"] if load["status"] != 0)
    
    pd_total = sum(load["pd"] for (i,load) in load_active)
    p_losses = sum(gen["pg"] for (i,gen) in network_lal["gen"] if gen["gen_status"] != 0) - pd_total
    p_delta = 0.0
    
    # if p_losses > C1_PG_LOSS_TOL
    #     load_count = length(load_active)
    #     p_delta = p_losses/load_count
    #     for (i,load) in load_active
    #         load["pd"] += p_delta
    #     end
    #     _PMSC.warn(_LOGGER, "ac active power losses found $(p_losses) increasing loads by $(p_delta)")         # Update_GM
    # end

            gen_contingencies = _PMSC.calc_c1_gen_contingency_subset(network_lal, gen_eval_limit=gen_eval_limit)
            branch_contingencies = _PMSC.calc_c1_branch_contingency_subset(network_lal, branch_eval_limit=branch_eval_limit)
            branchdc_contingencies = calc_c1_branchdc_contingency_subset(network_lal, branchdc_eval_limit=branchdc_eval_limit)            # Update_GM
            convdc_contingencies = calc_convdc_contingency_subset(network_lal, convdc_eval_limit=convdc_eval_limit)

    ######################################################################################################################################################
    active_conts_by_branch = Dict()
    active_conts_by_branchdc = Dict()
    total_cuts_pre_filter = []
    gen_cuts = []
    gen_cut_vio = 0.0
    for (i,cont) in enumerate(gen_contingencies)
        # if cont.label ∉ dominated_contingencies 
                # if length(gen_cuts) >= gen_contingency_limit
                #     _PMSC.info(_LOGGER, "hit gen cut limit $(gen_contingency_limit)")       # Update_GM
                #     break
                # end
                # if length(gen_cuts) >= contingency_limit
                #     _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")              # Update_GM
                #     break
                # end
            #info(_LOGGER, "working on ($(i)/$(gen_eval_limit)/$(gen_cont_total)): $(cont.label)")

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
                _PMSC.warn(_LOGGER, "no available active power response in cont $(cont.label), active gens $(length(alpha_gens))")  # Update_GM
                continue
            end

            alpha_total = sum(alpha_gens)
            delta = pg_lost/alpha_total
            network_lal["delta"] = delta
            #info(_LOGGER, "$(pg_lost) - $(alpha_total) - $(delta)")

            for (i,gen) in gen_active
                gen["pg"] += gen["alpha"]*delta
            end

            try
                solution =  _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
                _PM.update_data!(network_lal, solution)
                ### results_c["c$(cont.label)"] = solution  
            catch exception
                _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
                continue
            end

            vio = calc_violations(network_lal, network_lal)            # Update_GM
            ### results_c["vio_c$(cont.label)"] = vio
            #info(_LOGGER, "$(cont.label) violations $(vio)")
            #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
            if vio.sm > sm_threshold || vio.smdc > smdc_threshold
                if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    #active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                end
                if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    #active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
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
                _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")           # Update
                push!(gen_cuts, cont)
                gen_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
            else
                gen_cut_vio = 0.0
            end
            
            cont_gen["gen_status"] = 1
            cont_gen["pg"] = pg_lost
            network_lal["delta"] = 0.0
        # end
    end
    ######################################################################################################################################################

    branch_cuts = []
    branch_cut_vio = 0.0
    for (i,cont) in enumerate(branch_contingencies)
        # if cont.label ∉ dominated_contingencies
                        # if length(branch_cuts) >= branch_contingency_limit
                        #     _PMSC.info(_LOGGER, "hit branch flow cut limit $(branch_contingency_limit)")                   # Update_GM
                        #     break
                        # end
                        # if length(gen_cuts) + length(branch_cuts) >= contingency_limit
                        #     _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                                      # Update_GM
                        #     break
                        # end

            # info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

            cont_branch = network_lal["branch"]["$(cont.idx)"]
            cont_branch["br_status"] = 0
            _PMACDC.fix_data!(network_lal)
            try
                solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
                _PM.update_data!(network_lal, solution)
                ### results_c["c$(cont.label)"] = solution
            catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")
            continue
            end
            
            vio = calc_violations(network_lal, network_lal)          # Update_GM 
            ### results_c["vio_c$(cont.label)"] = vio
        
            #info(_LOGGER, "$(cont.label) violations $(vio)")
            #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
            if vio.sm > sm_threshold || vio.smdc > sm_threshold
                if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                end
                if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
                if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                        # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                        push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    else
                        # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                        push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    end
                end
                _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")                              # Update_GM
                push!(branch_cuts, cont)
                branch_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
            else
                branch_cut_vio = 0.0
            end

            cont_branch["br_status"] = 1
        # end
    end

    ######################################################################################################################################################
    
    branchdc_cuts = []       # Update_GM
    branchdc_cut_vio = 0.0
    for (i,cont) in enumerate(branchdc_contingencies)        # Update_GM
        # if cont.label ∉ dominated_contingencies
                            # if length(branchdc_cuts) >= branchdc_contingency_limit       # Update_GM
                            #     _PMSC.info(_LOGGER, "hit branchdc flow cut limit $(branchdc_contingency_limit)")                # Update_GM
                            #     break
                            # end
                            # if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) >= contingency_limit       # Update_GM
                            #     _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                  # Update_GM
                            #     break
                            # end

            #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

            cont_branchdc = network_lal["branchdc"]["$(cont.idx)"]            # Update_GM
            cont_branchdc["status"] = 0                                       # Update_GM

            try
                solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
                _PM.update_data!(network_lal, solution)
                ### results_c["c$(cont.label)"] = solution
            catch exception
                _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
                continue
            end

            vio = calc_violations(network_lal, network_lal)          # Update_GM 
            ### results_c["vio_c$(cont.label)"] = vio
            #info(_LOGGER, "$(cont.label) violations $(vio)")
            #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
            if vio.smdc > sm_threshold || vio.smdc > sm_threshold
                if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                end
                if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
                if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                        # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                        push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    else
                        # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                        push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    end
                end
                _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")            # Update_GM
                push!(branchdc_cuts, cont)
                branchdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
            else
                branchdc_cut_vio = 0.0
            end

            cont_branchdc["status"] = 1
        # end
    end

    ######################################################################################################################################################
    convdc_cuts = []  
    convdc_cut_vio = 0.0
    for (i,cont) in enumerate(convdc_contingencies)        # Update_GM
        # if cont.label ∉ dominated_contingencies
                                # if length(convdc_cuts) >= convdc_contingency_limit       # Update_GM
                                #     _PMSC.info(_LOGGER, "hit convdc cut limit $(convdc_contingency_limit)")                # Update_GM
                                #     break
                                # end
                                # if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) + length(convdc_cuts) >= contingency_limit       # Update_GM
                                #     _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                  # Update_GM
                                #     break
                                # end

            #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

            cont_convdc = network_lal["convdc"]["$(cont.idx)"]            # Update_GM
            cont_convdc["status"] = 0                                       # Update_GM

            try
                solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
                _PM.update_data!(network_lal, solution)
                ### results_c["c$(cont.label)"] = solution
            catch exception
                _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
                continue
            end

            vio = calc_violations(network_lal, network_lal)          # Update_GM 
            ### results_c["vio_c$(cont.label)"] = vio
            #info(_LOGGER, "$(cont.label) violations $(vio)")
            #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold || vio.cmac > sm_threshold || vio.cmdc > sm_threshold
            if vio.sm > sm_threshold || vio.smdc > sm_threshold 
                if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                end
                if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
                if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                        # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                        push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    else
                        # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                        push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    end
                end
                _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")            # Update_GM
                push!(convdc_cuts, cont)
                convdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
            else
                convdc_cut_vio = 0.0
            end

            cont_convdc["status"] = 1
        # end
    end
    ################### filtering non-dominated contingencies ###########################

                    # if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) + length(convdc_cuts) >= contingency_limit 
                    #     total_cuts_pre_filter = length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) + length(convdc_cuts)
                    #     _PMSC.info(_LOGGER, "total cuts hit total cut limit $(contingency_limit)")
                    # else
                    #     total_cuts_pre_filter = 0
                    # end

    ################### filtering non-dominated contingencies ###########################
    dominated_contingencies = []
    if !isempty(gen_cuts)
        for contn in gen_cuts
            for (i, x) in active_conts_by_branch
                if haskey(active_conts_by_branch, "$(contn.label)")
                    if active_conts_by_branch["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branch["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branch, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
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
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
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
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
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
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
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
                push!(gen_cuts_delete_index, findfirst(isequal(contn), gen_cuts))  # deleteat!(gen_cuts, findfirst(isequal(contn), gen_cuts))
                _PMSC.info(_LOGGER, "gen contingency $(contn.label) removed")
            end
        end
        deleteat!(gen_cuts, sort(gen_cuts_delete_index[1:length(gen_cuts_delete_index)]) )            # TO DO for other suchas branch
        end
    branch_cuts_delete_index =[]
    if !isempty(branch_cuts)
        for (i,contn) in enumerate(branch_cuts)
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                deleteat!(branch_cuts, findfirst(isequal(contn), branch_cuts))
                _PMSC.info(_LOGGER, "branch contingency $(contn.label) removed")
            end
        end
    end
    branchdc_cuts_delete_index =[]
    if !isempty(branchdc_cuts)
        for (i,contn) in enumerate(branchdc_cuts)
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                deleteat!(branchdc_cuts, findfirst(isequal(contn), branchdc_cuts))
                _PMSC.info(_LOGGER, "branchdc contingency $(contn.label) removed")
            end
        end
    end
    convdc_cuts_delete_index =[]
    if !isempty(convdc_cuts)
        for (i,contn) in enumerate(convdc_cuts)
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                deleteat!(convdc_cuts, findfirst(isequal(contn), convdc_cuts))
                _PMSC.info(_LOGGER, "convdc contingency $(contn.label) removed")
            end
        end
    end

    ######################################################################################################################################################

    # if total_cuts < length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) + length(convdc_cuts)
    #      = length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) + length(convdc_cuts)
    #     _PMSC.info(_LOGGER, "total cuts hit total cut limit $(contingency_limit)")  
    # end


    ######################################################################################################################################################

    # if p_delta != 0.0
    #     _PMSC.warn(_LOGGER, "re-adjusting ac loads by $(-p_delta)")        # TO DO dc lossess
    #         load["pd"] -= p_delta
    #     end
    # end

    time_contingencies = time() - time_contingencies_start
    _PMSC.info(_LOGGER, "contingency eval time: $(time_contingencies)")            # Update_GM

    return (gen_contingencies=gen_cuts, branch_contingencies=branch_cuts, branchdc_contingencies=branchdc_cuts, convdc_contingencies=convdc_cuts) 
end

function load_network_global_new(network_data)
    # info(_LOGGER, "skipping goc and power models data warnings")
    # pm_logger_level = getlevel(getlogger(PowerModels))
    # goc_logger_level = getlevel(_LOGGER)

    # setlevel!(getlogger(PowerModels), "error")
    # setlevel!(_LOGGER, "error")

    # goc_data = parse_c1_files(con_file, inl_file, raw_file, rop_file, scenario_id=scenario_id)
    global network_global = network_data           #build_c1_pm_model
    global contingency_order_global = contingency_order(network_global)

    # setlevel!(getlogger(PowerModels), pm_logger_level)
    # setlevel!(_LOGGER, goc_logger_level)

    return 0
end



"build a static ordering of all contingencies"
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

    #println(gen_cont_total)
    #println(branch_cont_total)
    #println(steps)

    #println(gen_rate)
    #println(branch_rate)
    #println("")

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



function check_contingency_violations_distributed_remote(cont_range, output_dir, contingency_limit=1, solution_file="solution1.txt")
    if length(network_global) <= 0 || length(contingency_order_global) <= 0
        Memento.error(_LOGGER, "check_contingency_violations_distributed_remote called before load_network_global_new")
    end
    nlp_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0) 
    # sol = read_c1_solution1(c1_network_global, output_dir=output_dir, state_file=solution_file)
    # _PM.update_data!(c1_network_global, sol)

    # active_cuts = read_c1_active_flow_cuts(output_dir=output_dir)
    # gen_flow_cuts = []
    # branch_flow_cuts = []
    # for cut in active_cuts
    #     if cut.cont_type == "gen"
    #         push!(gen_flow_cuts, cut)
    #     elseif cut.cont_type == "branch"
    #         push!(branch_flow_cuts, cut)
    #     else
    #         warn(_LOGGER, "unknown contingency type in cut $(cut)")
    #     end
    # end
    
    network = deepcopy(network_global)
    contingencies = contingency_order_global[cont_range]
    # nlp_solver = optimizer_with_attributes(Ipopt.Optimizer)
    setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
    network["gen_contingencies"] = [c for c in contingencies if c.type == "gen"]
    network["branch_contingencies"] = [c for c in contingencies if c.type == "branch"]
    network["branchdc_contingencies"] = [c for c in contingencies if c.type == "branchdc"]
    network["convdc_contingencies"] = [c for c in contingencies if c.type == "convdc"]

    cuts = check_contingency_violations_distributed(network, _PM.DCPPowerModel, nlp_solver, setting)

    return cuts
end

function check_contingency_violations_distributed(network, model_type, optimizer, setting;
    gen_contingency_limit=5000, branch_contingency_limit=5000, branchdc_contingency_limit=5000, convdc_contingency_limit=5000, contingency_limit=typemax(Int64),gen_eval_limit=typemax(Int64),
    branch_eval_limit=typemax(Int64), branchdc_eval_limit=typemax(Int64), convdc_eval_limit=typemax(Int64), sm_threshold=0.01, smdc_threshold=0.01, pg_threshold=0.01, qg_threshold=0.01,vm_threshold=0.01)     # Update_GM

    ### results_c = Dict{String,Any}()
    

    if _IM.ismultinetwork(network)
        error(_LOGGER, "the branch flow cut generator can only be used on single networks")
    end
    time_contingencies_start = time()

    network_lal = deepcopy(network)     # lal -> losses as loads

    #ref_bus_id = _PM.reference_bus(network_lal)["index"]

    gen_pg_init = Dict(i => gen["pg"] for (i,gen) in network_lal["gen"])

    load_active = Dict(i => load for (i, load) in network_lal["load"] if load["status"] != 0)
    
    pd_total = sum(load["pd"] for (i,load) in load_active)
    p_losses = sum(gen["pg"] for (i,gen) in network_lal["gen"] if gen["gen_status"] != 0) - pd_total
    p_delta = 0.0
    
    # if p_losses > C1_PG_LOSS_TOL
    #     load_count = length(load_active)
    #     p_delta = p_losses/load_count
    #     for (i,load) in load_active
    #         load["pd"] += p_delta
    #     end
    #     _PMSC.warn(_LOGGER, "ac active power losses found $(p_losses) increasing loads by $(p_delta)")        
    # end

            gen_contingencies = _PMSC.calc_c1_gen_contingency_subset(network_lal, gen_eval_limit=gen_eval_limit)
            branch_contingencies = _PMSC.calc_c1_branch_contingency_subset(network_lal, branch_eval_limit=branch_eval_limit)
            branchdc_contingencies = calc_branchdc_contingency_subset(network_lal, branchdc_eval_limit=branchdc_eval_limit)       
            convdc_contingencies = calc_convdc_contingency_subset(network_lal, convdc_eval_limit=convdc_eval_limit)


    ######################################################################################################################################################
    active_conts_by_branch = Dict()
    active_conts_by_branchdc = Dict()
    total_cuts_pre_filter = []
    gen_cuts = []
    gen_cut_vio = 0.0
    for (i,cont) in enumerate(gen_contingencies)
        # if cont.label ∉ dominated_contingencies 
                # if length(gen_cuts) >= gen_contingency_limit
                #     _PMSC.info(_LOGGER, "hit gen cut limit $(gen_contingency_limit)")       # Update_GM
                #     break
                # end
                # if length(gen_cuts) >= contingency_limit
                #     _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")              # Update_GM
                #     break
                # end
            #info(_LOGGER, "working on ($(i)/$(gen_eval_limit)/$(gen_cont_total)): $(cont.label)")

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
                _PMSC.warn(_LOGGER, "no available active power response in cont $(cont.label), active gens $(length(alpha_gens))")  # Update_GM
                continue
            end

            alpha_total = sum(alpha_gens)
            delta = pg_lost/alpha_total
            network_lal["delta"] = delta
            #info(_LOGGER, "$(pg_lost) - $(alpha_total) - $(delta)")

            for (i,gen) in gen_active
                gen["pg"] += gen["alpha"]*delta
            end

            try
                solution =  _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
                _PM.update_data!(network_lal, solution)
                ### results_c["c$(cont.label)"] = solution  
            catch exception
                _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
                continue
            end

            vio = calc_violations(network_lal, network_lal, return_vio_data = true)            # Update_GM
            ### results_c["vio_c$(cont.label)"] = vio
            #info(_LOGGER, "$(cont.label) violations $(vio)")
            #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
            if vio.sm > sm_threshold || vio.smdc > smdc_threshold
                if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    #active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                end
                if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    #active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
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
                _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")           # Update
                push!(gen_cuts, cont)
                gen_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
            else
                gen_cut_vio = 0.0
            end
            
            cont_gen["gen_status"] = 1
            cont_gen["pg"] = pg_lost
            network_lal["delta"] = 0.0
        # end
    end
    ######################################################################################################################################################

    branch_cuts = []
    branch_cut_vio = 0.0
    for (i,cont) in enumerate(branch_contingencies)
        # if cont.label ∉ dominated_contingencies
                        # if length(branch_cuts) >= branch_contingency_limit
                        #     _PMSC.info(_LOGGER, "hit branch flow cut limit $(branch_contingency_limit)")                   # Update_GM
                        #     break
                        # end
                        # if length(gen_cuts) + length(branch_cuts) >= contingency_limit
                        #     _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                                      # Update_GM
                        #     break
                        # end

            # info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

            cont_branch = network_lal["branch"]["$(cont.idx)"]
            cont_branch["br_status"] = 0
            _PMACDC.fix_data!(network_lal)
            try
                solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
                _PM.update_data!(network_lal, solution)
                ### results_c["c$(cont.label)"] = solution
            catch exception
            _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")
            continue
            end
            
            vio = calc_violations(network_lal, network_lal, return_vio_data = true)          # Update_GM 
            ### results_c["vio_c$(cont.label)"] = vio
        
            #info(_LOGGER, "$(cont.label) violations $(vio)")
            #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
            if vio.sm > sm_threshold || vio.smdc > sm_threshold
                if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                end
                if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
                if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                        # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                        push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    else
                        # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                        push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    end
                end
                _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")                              # Update_GM
                push!(branch_cuts, cont)
                branch_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
            else
                branch_cut_vio = 0.0
            end

            cont_branch["br_status"] = 1
        # end
    end

    ######################################################################################################################################################
    
    branchdc_cuts = []       # Update_GM
    branchdc_cut_vio = 0.0
    for (i,cont) in enumerate(branchdc_contingencies)        # Update_GM
        # if cont.label ∉ dominated_contingencies
                            # if length(branchdc_cuts) >= branchdc_contingency_limit       # Update_GM
                            #     _PMSC.info(_LOGGER, "hit branchdc flow cut limit $(branchdc_contingency_limit)")                # Update_GM
                            #     break
                            # end
                            # if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) >= contingency_limit       # Update_GM
                            #     _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                  # Update_GM
                            #     break
                            # end

            #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

            cont_branchdc = network_lal["branchdc"]["$(cont.idx)"]            # Update_GM
            cont_branchdc["status"] = 0                                       # Update_GM

            try
                solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
                _PM.update_data!(network_lal, solution)
                ### results_c["c$(cont.label)"] = solution
            catch exception
                _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
                continue
            end

            vio = calc_violations(network_lal, network_lal, return_vio_data = true)          # Update_GM 
            ### results_c["vio_c$(cont.label)"] = vio
            #info(_LOGGER, "$(cont.label) violations $(vio)")
            #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
            if vio.smdc > sm_threshold || vio.smdc > sm_threshold
                if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                end
                if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
                if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                        # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                        push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    else
                        # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                        push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    end
                end
                _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")            # Update_GM
                push!(branchdc_cuts, cont)
                branchdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
            else
                branchdc_cut_vio = 0.0
            end

            cont_branchdc["status"] = 1
        # end
    end

    ######################################################################################################################################################
    convdc_cuts = []  
    convdc_cut_vio = 0.0
    for (i,cont) in enumerate(convdc_contingencies)        # Update_GM
        # if cont.label ∉ dominated_contingencies
                                # if length(convdc_cuts) >= convdc_contingency_limit       # Update_GM
                                #     _PMSC.info(_LOGGER, "hit convdc cut limit $(convdc_contingency_limit)")                # Update_GM
                                #     break
                                # end
                                # if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) + length(convdc_cuts) >= contingency_limit       # Update_GM
                                #     _PMSC.info(_LOGGER, "hit total cut limit $(contingency_limit)")                  # Update_GM
                                #     break
                                # end

            #info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

            cont_convdc = network_lal["convdc"]["$(cont.idx)"]            # Update_GM
            cont_convdc["status"] = 0                                       # Update_GM

            try
                solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
                _PM.update_data!(network_lal, solution)
                ### results_c["c$(cont.label)"] = solution
            catch exception
                _PMSC.warn(_LOGGER, "ACDCPF solve failed on $(cont.label)")     # Update_GM
                continue
            end

            vio = calc_violations(network_lal, network_lal, return_vio_data = true)          # Update_GM 
            ### results_c["vio_c$(cont.label)"] = vio
            #info(_LOGGER, "$(cont.label) violations $(vio)")
            #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold || vio.cmac > sm_threshold || vio.cmdc > sm_threshold
            if vio.sm > sm_threshold || vio.smdc > sm_threshold 
                if !isempty(vio.vio_data["branch"]) && isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                end
                if !isempty(vio.vio_data["branchdc"]) && isempty(vio.vio_data["branch"])
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                end
                if !isempty(vio.vio_data["branch"]) && !isempty(vio.vio_data["branchdc"])
                    vio.vio_data["branch"] = sort(vio.vio_data["branch"], rev=true, byvalue=true) 
                    vio.vio_data["branchdc"] = sort(vio.vio_data["branchdc"], rev=true, byvalue=true) 
                    const_akeys = collect(keys(vio.vio_data["branch"]))
                    const_dkeys = collect(keys(vio.vio_data["branchdc"]))
                    if vio.vio_data["branch"][const_akeys[1]] >= vio.vio_data["branchdc"][const_dkeys[1]]
                        # active_conts_by_branch = Dict(cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                        push!(active_conts_by_branch, cont.label => (parse(Int64, const_akeys[1]), vio.vio_data["branch"][const_akeys[1]]))
                    else
                        # active_conts_by_branchdc = Dict(cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                        push!(active_conts_by_branchdc, cont.label => (parse(Int64, const_dkeys[1]), vio.vio_data["branchdc"][const_dkeys[1]]))
                    end
                end
                _PMSC.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $([p for p in pairs(vio) if p[1]!=:vio_data])")            # Update_GM
                push!(convdc_cuts, cont)
                convdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc + vio.cmac + vio.cmdc
            else
                convdc_cut_vio = 0.0
            end

            cont_convdc["status"] = 1
        # end
    end
    ######################################################################################################################################################

    # if p_delta != 0.0
    #     _PMSC.warn(_LOGGER, "re-adjusting ac loads by $(-p_delta)")        # TO DO dc lossess
    #     for (i,load) in load_active
    #         load["pd"] -= p_delta
    #     end
    # end
    

    time_contingencies = time() - time_contingencies_start
    _PMSC.info(_LOGGER, "contingency eval time: $(time_contingencies)")            # Update_GM

    return (gen_contingencies=gen_cuts, branch_contingencies=branch_cuts, branchdc_contingencies=branchdc_cuts, convdc_contingencies=convdc_cuts, active_conts_by_branch=active_conts_by_branch, active_conts_by_branchdc=active_conts_by_branchdc) 
end

function filter_non_dominated_contingencies(gen_cuts, branch_cuts, branchdc_cuts, convdc_cuts, active_conts_by_branch, active_conts_by_branchdc)

    dominated_contingencies = []
    if !isempty(gen_cuts)
        for contn in gen_cuts
            for (i, x) in active_conts_by_branch
                if haskey(active_conts_by_branch, "$(contn.label)")
                    if active_conts_by_branch["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branch["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branch, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
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
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
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
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
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
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
                        end
                    end
                end
                if haskey(active_conts_by_branchdc, "$(contn.label)")
                    if active_conts_by_branchdc["$(contn.label)"][1] == x[1] && "$(contn.label)" !=i
                        if active_conts_by_branchdc["$(contn.label)"][2] >=x[2]
                            push!(dominated_contingencies, i)
                            delete!(active_conts_by_branchdc, i)
                            _PMSC.info(_LOGGER, "contingency $(contn.label) dominates over contingency $i")
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
                _PMSC.info(_LOGGER, "gen contingency $(contn.label) removed")
            end
        end
        deleteat!(gen_cuts, sort(gen_cuts_delete_index[1:length(gen_cuts_delete_index)]) )            
    end
    branch_cuts_delete_index =[]
    if !isempty(branch_cuts)
        for (i,contn) in enumerate(branch_cuts)            
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                push!(branch_cuts_delete_index, findfirst(isequal(contn), branch_cuts))  
                _PMSC.info(_LOGGER, "branch contingency $(contn.label) removed")
            end
        end
        deleteat!(branch_cuts, sort(branch_cuts_delete_index[1:length(branch_cuts_delete_index)]) )           
    end

    branchdc_cuts_delete_index =[]
    if !isempty(branchdc_cuts)
        for (i,contn) in enumerate(branchdc_cuts)            
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                push!(branchdc_cuts_delete_index, findfirst(isequal(contn), branchdc_cuts))  
                _PMSC.info(_LOGGER, "branchdc contingency $(contn.label) removed")
            end
        end
        deleteat!(branchdc_cuts, sort(branchdc_cuts_delete_index[1:length(branchdc_cuts_delete_index)]) )            
    end

    convdc_cuts_delete_index =[]
    if !isempty(convdc_cuts)
        for (i,contn) in enumerate(convdc_cuts)            
            if !haskey(active_conts_by_branch, "$(contn.label)") && !haskey(active_conts_by_branchdc, "$(contn.label)")
                push!(convdc_cuts_delete_index, findfirst(isequal(contn), convdc_cuts))  
                _PMSC.info(_LOGGER, "convdc contingency $(contn.label) removed")
            end
        end
        deleteat!(convdc_cuts, sort(convdc_cuts_delete_index[1:length(convdc_cuts_delete_index)]) )           
    end
 

    return (gen_contingencies=gen_cuts, branch_contingencies=branch_cuts, branchdc_contingencies=branchdc_cuts, convdc_contingencies=convdc_cuts) 
end




