function calc_violations(network::Dict{String,<:Any}, solution::Dict{String,<:Any}; vm_digits=3, rate_key="rate_c", rate_keydc="rateC")
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
            #    info(_LOGGER, "$(i): $(bus["vmin"]) - $(sol_val) - $(bus["vmax"])")
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

                # note true model is rate_c
                #vio_flag = false
                rating = branch[rate_key]

                if s_fr > rating
                    sm_vio += s_fr - rating
                    #vio_flag = true
                end
                if s_to > rating
                    sm_vio += s_to - rating
                    #vio_flag = true
                end
                #if vio_flag
                #    info(_LOGGER, "$(i), $(branch["f_bus"]), $(branch["t_bus"]): $(s_fr) / $(s_to) <= $(branch["rate_c"])")
                #end
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

                # note true model is rateC
                #vio_flag = false
                rating = branchdc[rate_keydc]

                if s_fr > rating
                    smdc_vio += s_fr - rating
                    #vio_flag = true
                end
                if s_to > rating
                    smdc_vio += s_to - rating
                    #vio_flag = true
                end
                #if vio_flag
                #    info(_LOGGER, "$(i), $(branchdc["f_bus"]), $(branchdc["t_bus"]): $(s_fr) / $(s_to) <= $(branchdc["rateC"])")
                #end
            end
        end
    end


    return (vm=vm_vio, pg=pg_vio, qg=qg_vio, sm=sm_vio, smdc=smdc_vio)
end