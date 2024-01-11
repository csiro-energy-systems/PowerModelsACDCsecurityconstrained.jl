"""
This function checks a given operating point against the contingencies to look
for branch HVAC and HVDC flow violations. The ACDC Power Flow is used for flow
simulation. It returns a list of contingencies where a violation is found.

"""

function check_acdc_contingency_violations(network, model_type, optimizer, setting;
    gen_contingency_limit=1000, branch_contingency_limit=5000, branchdc_contingency_limit=1000,
    convdc_contingency_limit=1000, contingency_limit=typemax(Int64),gen_eval_limit=typemax(Int64),
    branch_eval_limit=typemax(Int64), branchdc_eval_limit=typemax(Int64), convdc_eval_limit=typemax(Int64),
    sm_threshold=0.01, pg_threshold=0.01, qg_threshold=0.01,vm_threshold=0.01)  

    if _IM.ismultinetwork(network)
        Memento.error(_LOGGER, "check_acdc_contingency_violations can only be used on single networks")
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

    gen_contingencies = _PMSC.calc_c1_gen_contingency_subset(network_lal, gen_eval_limit=gen_eval_limit)
    branch_contingencies = _PMSC.calc_c1_branch_contingency_subset(network_lal, branch_eval_limit=branch_eval_limit)
    branchdc_contingencies = calc_branchdc_contingency_subset(network_lal, branchdc_eval_limit=branchdc_eval_limit)   
    convdc_contingencies = calc_convdc_contingency_subset(network_lal, convdc_eval_limit=convdc_eval_limit)

   total_cuts_pre_filter = []
    gen_cuts = []
    gen_cut_vio = 0.0
    for (i,cont) in enumerate(gen_contingencies)
        if length(gen_cuts) >= gen_contingency_limit
            Memento.info(_LOGGER, "hit gen cut limit $(gen_contingency_limit)")       # Update_GM
            break
        end
        if length(gen_cuts) >= contingency_limit
            Memento.info(_LOGGER, "hit total cut limit $(contingency_limit)")              # Update_GM
            break
        end
        #Memento.info(_LOGGER, "working on ($(i)/$(gen_eval_limit)/$(gen_cont_total)): $(cont.label)")

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
        #Memento.info(_LOGGER, "$(pg_lost) - $(alpha_total) - $(delta)")

        for (i,gen) in gen_active
            gen["pg"] += gen["alpha"]*delta
        end


        for (i,gen) in network_lal["gen"]
            if isnan(gen["pg"]) || isnan(gen["qg"])
                println("gen $i")
            end
        end
        for (i,branch) in network_lal["branch"]
            if isnan(branch["br_r"]) || isnan(branch["br_x"])
                println("branch $i")
            end
        end

        try
            solution =  _PMACDC.run_acdcpf( network_lal, model_type, optimizer, setting = setting)["solution"]
            _PM.update_data!(network_lal, solution) 
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")    
            continue
        end

        vio = calc_violations(network_lal, network_lal)            
        
        # Memento.info(_LOGGER, "$(cont.label) violations $(vio)")
        # if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > sm_threshold
            Memento.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $(vio)")           
            push!(gen_cuts, cont)
            gen_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc
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
        if length(branch_cuts) >= branch_contingency_limit
            Memento.info(_LOGGER, "hit branch flow cut limit $(branch_contingency_limit)")                   
            break
        end
        if length(gen_cuts) + length(branch_cuts) >= contingency_limit
            Memento.info(_LOGGER, "hit total cut limit $(contingency_limit)")                                    
            break
        end

        #Memento.info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

        cont_branch = network_lal["branch"]["$(cont.idx)"]
        cont_branch["br_status"] = 0
        _PMACDC.fix_data!(network_lal)
        try
            solution = _PMACDC.run_acdcpf(network_lal, model_type, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")
           continue
        end
        
        vio = calc_violations(network_lal, network_lal)          
    
        #Memento.info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > sm_threshold
            Memento.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $(vio)")                       
            push!(branch_cuts, cont)
            branch_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc
        else
            branch_cut_vio = 0.0
        end

        cont_branch["br_status"] = 1
        
    end

   
    branchdc_cuts = []       
    branchdc_cut_vio = 0.0
    for (i,cont) in enumerate(branchdc_contingencies)        
        if length(branchdc_cuts) >= branchdc_contingency_limit       
            Memento.info(_LOGGER, "hit branchdc flow cut limit $(branchdc_contingency_limit)")                
            break
        end
        if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) >= contingency_limit      
            Memento.info(_LOGGER, "hit total cut limit $(contingency_limit)")                  
            break
        end

        #Memento.info(_LOGGER, "working on ($(i)/$(branchdc_eval_limit)/$(branchdc_cont_total)): $(cont.label)")

        cont_branchdc = network_lal["branchdc"]["$(cont.idx)"]           
        cont_branchdc["status"] = 0                                       

        try
            solution = _PMACDC.run_acdcpf(network_lal, model_type, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")     
            continue
        end

        vio = calc_violations(network_lal, network_lal)         
        
        #Memento.info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold
        if vio.smdc > sm_threshold || vio.sm > sm_threshold
            Memento.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $(vio)")         
            push!(branchdc_cuts, cont)
            branchdc_cut_vio = vio.pg + vio.qg + vio.sm + vio.smdc
        else
            branchdc_cut_vio = 0.0
        end

        cont_branchdc["status"] = 1
    end

    convdc_cuts = []  
    convdc_cut_vio = 0.0
    for (i,cont) in enumerate(convdc_contingencies)        
        if length(convdc_cuts) >= convdc_contingency_limit       
            Memento.info(_LOGGER, "hit convdc cut limit $(convdc_contingency_limit)")               
            break
        end
        if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) + length(convdc_cuts) >= contingency_limit       
            Memento.info(_LOGGER, "hit total cut limit $(contingency_limit)")                 
            break
        end

        #Memento.info(_LOGGER, "working on ($(i)/$(convdc_eval_limit)/$(convdc_cont_total)): $(cont.label)")

        cont_convdc = network_lal["convdc"]["$(cont.idx)"]            
        cont_convdc["status"] = 0                                       

        try
            solution = _PMACDC.run_acdcpf( network_lal, model_type, optimizer; setting = setting)["solution"]
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")     
            continue
        end

        vio = calc_violations(network_lal, network_lal)          
      
        #info(_LOGGER, "$(cont.label) violations $(vio)")
        #if vio.vm > vm_threshold || vio.pg > pg_threshold || vio.qg > qg_threshold || vio.sm > sm_threshold || vio.smdc > sm_threshold || vio.cmac > sm_threshold || vio.cmdc > sm_threshold
        if vio.sm > sm_threshold || vio.smdc > sm_threshold 
            Memento.info(_LOGGER, "adding contingency $(cont.label) due to constraint violations $(vio)")            
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

    return (gen_contingencies=gen_cuts, branch_contingencies=branch_cuts, branchdc_contingencies=branchdc_cuts, convdc_contingencies=convdc_cuts)
end




"ranks branchdc contingencies and down selects based on evaluation limits"
function calc_branchdc_contingency_subset(network::Dict{String,<:Any}; branchdc_eval_limit=length(network["branchdc_contingencies"]))        
    line_imp_mag = Dict(branchdc["index"] => branchdc["rateA"]*(branchdc["r"]) for (i,branchdc) in network["branchdc"])                       
    branchdc_contingencies =sort(network["branchdc_contingencies"], rev=true, by=x -> line_imp_mag[x.idx])                                     

    branchdc_cont_limit = min(branchdc_eval_limit, length(network["branchdc_contingencies"]))                                                    
    branchdc_contingencies = branchdc_contingencies[1:branchdc_cont_limit]                                            

    return branchdc_contingencies                                                     
end




"ranks converter contingencies and down selects based on evaluation limits"
function calc_convdc_contingency_subset(network::Dict{String,<:Any}; convdc_eval_limit=length(network["convdc_contingencies"]))
    convdc_cap = Dict(convdc["index"] => sqrt(max(abs(convdc["Pacmin"]), abs(convdc["Pacmax"]))^2 + max(abs(convdc["Qacmin"]), abs(convdc["Qacmax"]))^2) for (i,convdc) in network["convdc"])
    convdc_contingencies = sort(network["convdc_contingencies"], rev=true, by=x -> convdc_cap[x.idx])

    convdc_cont_limit = min(convdc_eval_limit, length(network["convdc_contingencies"]))
    convdc_contingencies = convdc_contingencies[1:convdc_cont_limit]

    return convdc_contingencies
end




function calc_violations(network::Dict{String,<:Any}, solution::Dict{String,<:Any}; return_vio_data::Bool=false, vm_digits=3, rate_key="rate_c", rate_keydc="rateC")
    
    vio_data = Dict()
    vio_data["genp"] = Dict()
    vio_data["genq"] = Dict()
    vio_data["branch"] = Dict()
    vio_data["branchdc"] = Dict()

    vm_vio = 0.0
    for (i,bus) in network["bus"]
        if bus["bus_type"] != 4
            bus_sol = solution["bus"][i]

            # helps to account for minor errors in equality constraints
            sol_val = round(bus_sol["vm"], digits=vm_digits)

            #vio_flag = false
            if sol_val < bus["vmin"]
                vm_vio += bus["vmin"] - sol_val
                #vio_flag = true
            end
            if sol_val > bus["vmax"]
                vm_vio += sol_val - bus["vmax"]
                #vio_flag = true
            end
            #if vio_flag
            #    Memento.info(_LOGGER, "$(i): $(bus["vmin"]) - $(sol_val) - $(bus["vmax"])")
            #end
        end
    end

    pg_vio = 0.0
    qg_vio = 0.0
    for (i,gen) in network["gen"]
        if gen["gen_status"] != 0
            gen_sol = solution["gen"][i]

            if gen_sol["pg"] < gen["pmin"]
                pg_vio += gen["pmin"] - gen_sol["pg"]
            end
            if gen_sol["pg"] > gen["pmax"]
                pg_vio += gen_sol["pg"] - gen["pmax"]
            end

            if gen_sol["qg"] < gen["qmin"]
                qg_vio += gen["qmin"] - gen_sol["qg"]
            end
            if gen_sol["qg"] > gen["qmax"]
                qg_vio += gen_sol["qg"] - gen["qmax"]
            end
            # if pg_vio !==0.0 || qg_vio !==0.0
            #     push!(vio_data["genp"], (i, pg_vio))
            #     push!(vio_data["genq"], (i, qg_vio))
            # end 
        end
    end

    sm_vio = NaN
    if haskey(solution, "branch")
        sm_vio = 0.0
        for (i,branch) in network["branch"]
            if branch["br_status"] != 0
                branch_sol = solution["branch"][i]

                s_fr = abs(branch_sol["pf"])
                s_to = abs(branch_sol["pt"])

                if !isnan(branch_sol["qf"]) && !isnan(branch_sol["qt"])
                    s_fr = sqrt(branch_sol["pf"]^2 + branch_sol["qf"]^2)
                    s_to = sqrt(branch_sol["pt"]^2 + branch_sol["qt"]^2)
                end

                #vio_flag = false
                rating = branch[rate_key]          

                if s_fr > rating || s_to > (rating)
                    if (s_fr - rating) >= (s_to - rating)
                    sm_vio += s_fr - rating
                    #vio_data["branch"] = Dict(i => s_fr - rating)
                    push!(vio_data["branch"], i => s_fr - rating)
                    elseif (s_to - rating) >= (s_fr - rating)
                        sm_vio += s_to - rating
                        # vio_data["branch"] = Dict(i => s_to - rating)
                        push!(vio_data["branch"], i => s_to - rating)
                    end
                    #vio_flag = true
                    #push!(vio_data["branch"], (i, s_fr - rating))
                end
                # if s_to > rating
                #     #vio_flag = true
                #     vio_data["branch"] = Dict(i => s_to - rating)
                #     #push!(vio_data["branch"], (i, s_to - rating))
                # end
                #if vio_flag
                #    Memento.info(_LOGGER, "$(i), $(branch["f_bus"]), $(branch["t_bus"]): $(s_fr) / $(s_to) <= $(branch["rate_c"])")
                #end
                # if sm_vio !==0.0 
                #     push!(vio_data["branchv"], (i, sm_vio))
                # end
            end
        end
    end

    smdc_vio = NaN                                                                        
    if haskey(solution, "branchdc")                                                            
        smdc_vio = 0.0
        for (i,branchdc) in network["branchdc"]                                                
            if branchdc["status"] != 0                                                  
                branchdc_sol = solution["branchdc"][i]

                s_fr = abs(branchdc_sol["pf"])                                                
                s_to = abs(branchdc_sol["pt"])

                #vio_flag = false
                rating = branchdc[rate_keydc]

                if s_fr > rating || s_to > (rating)
                    if (s_fr - rating) >= (s_to - rating)
                        smdc_vio += s_fr - rating
                        # vio_data["branchdc"] = Dict(i => s_fr - rating)
                        push!(vio_data["branchdc"], i => s_fr - rating)
                        #vio_flag = true
                    elseif (s_to - rating) >= (s_fr - rating)
                        smdc_vio += s_to - rating
                        #vio_data["branchdc"] = Dict(i => s_to - rating)
                        push!(vio_data["branchdc"], i => s_to - rating)
                    end
                end
                # if s_to > rating
                #     smdc_vio += s_to - rating
                #     #vio_flag = true
                #     vio_data["branchdc"] = Dict(i => s_to - rating)
                #     #push!(vio_data["branchdc"], (i, s_to - rating))
                # end
                #if vio_flag
                #    Memento.info(_LOGGER, "$(i), $(branchdc["f_bus"]), $(branchdc["t_bus"]): $(s_fr) / $(s_to) <= $(branchdc["rateC"])")
                #end
                # if smdc_vio !==0.0 
                #     push!(vio_data["branchdcv"], (i, smdc_vio))
                # end
            end
        end
    end

    convdc_smdc_vio = NaN
    convdc_sm_vio = NaN                                                                         
    if haskey(solution, "convdc")                                                            
        convdc_smdc_vio = 0.0
        convdc_sm_vio = 0.0
        for (i,convdc) in network["convdc"]                                                
            if convdc["status"] != 0                                                  
                convdc_sol = solution["convdc"][i]  

                s_ac = abs(convdc_sol["pconv"])
                
                if !isnan(convdc_sol["qconv"])
                    s_ac = sqrt(convdc_sol["pconv"]^2 + convdc_sol["qconv"]^2)
                end

                #vio_ac_flag = false
                rating_ac = sqrt(convdc["Pacrated"]^2 + convdc["Qacrated"]^2)

                if s_ac > rating_ac
                    convdc_sm_vio += s_ac - rating_ac
                    #vio_ac_flag = true
                end
              
                #if vio_ac_flag
                #    Memento.info(_LOGGER, "$(i), $(convdc["busac_i"]): $(s_ac) <= $(rating_ac)")
                #end

                #vio_dc_flag = false
                s_dc = abs(convdc_sol["pdc"])

                rating_dc = convdc["Pacrated"] * 1.2
                
                if s_dc > rating_dc
                    convdc_smdc_vio += s_dc - rating_dc
                    #vio_dc_flag = true
                end
                #if vio_dc_flag
                #    Memento.info(_LOGGER, "$(i), $(convdc["busdc_i"]): $(s_dc) <= $(convdc["Pdcrated"])")
                #end
            end
        end
    end

    if return_vio_data
        return (vm=vm_vio, pg=pg_vio, qg=qg_vio, sm=sm_vio, smdc=smdc_vio, cmac=convdc_sm_vio, cmdc=convdc_smdc_vio, vio_data)
    else
        return (vm=vm_vio, pg=pg_vio, qg=qg_vio, sm=sm_vio, smdc=smdc_vio, cmac=convdc_sm_vio, cmdc=convdc_smdc_vio)
    end
end