

function check_acdc_contingency_branch_power(network, model_type, optimizer, setting;
        gen_flow_cut_limit=10, branch_flow_cut_limit=10, branchdc_flow_cut_limit=10, total_cut_limit=typemax(Int64),
        gen_eval_limit=typemax(Int64), branch_eval_limit=typemax(Int64), branchdc_eval_limit=typemax(Int64), 
        sm_threshold=0.01, gen_flow_cuts=[], branch_flow_cuts=[], branchdc_flow_cuts=[])     

    if _IM.ismultinetwork(network)
        Memento.error(_LOGGER, "the check_acdc_contingency_branch_power can only be used on single networks")
    end
    time_contingencies_start = time()

    gen_cuts_active = Dict()
    for gen_cut in gen_flow_cuts
        if !haskey(gen_cuts_active, gen_cut.cont_label)
            gen_cuts_active[gen_cut.cont_label] = Set{Int}()
        end
        push!(gen_cuts_active[gen_cut.cont_label], gen_cut.branch_id)
    end

    branch_cuts_active = Dict()
    for branch_cut in branch_flow_cuts
        if !haskey(branch_cuts_active, branch_cut.cont_label)
            branch_cuts_active[branch_cut.cont_label] = Set{Int}()
        end
        push!(branch_cuts_active[branch_cut.cont_label], branch_cut.branch_id)
    end

    branchdc_cuts_active = Dict()
    for branchdc_cut in branchdc_flow_cuts
        if !haskey(branchdc_cuts_active, branchdc_cut.cont_label)
            branchdc_cuts_active[branchdc_cut.cont_label] = Set{Int}()
        end
        push!(branchdc_cuts_active[branchdc_cut.cont_label], branchdc_cut.branchdc_id)
    end

    network_lal = deepcopy(network) #lal -> losses as loads
    # ref_bus_id = _PM.reference_bus(network_lal)["index"] 
    # keep one ref_bus
    ref_bus = []
    for (i, bus) in network_lal["bus"]
        if bus["bus_type"] == 3
            push!(ref_bus, bus["index"])
        end
    end
    ref_bus_id = ref_bus[1]
  
    gen_pg_init = Dict(i => gen["pg"] for (i,gen) in network_lal["gen"])
    load_active = Dict(i => load for (i,load) in network_lal["load"] if load["status"] != 0)
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
    branch_contingencies =  _PMSC.calc_c1_branch_contingency_subset(network_lal, branch_eval_limit=branch_eval_limit)
    branchdc_contingencies = calc_branchdc_contingency_subset(network_lal, branchdc_eval_limit=branchdc_eval_limit)            

    gen_cuts = []
    for (i,cont) in enumerate(gen_contingencies)
        if length(gen_cuts) >= gen_flow_cut_limit
            Memento.info(_LOGGER, "hit gen flow cut limit $(gen_flow_cut_limit)")
            break
        end
        if length(gen_cuts) >= total_cut_limit
            Memento.info(_LOGGER, "hit total cut limit $(total_cut_limit)")
            break
        end
        # Memento.info(_LOGGER, "working on ($(i)/$(gen_eval_limit)/$(gen_cont_total)): $(cont.label)")
  
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
            solution = _PMACDC.run_acdcpf(network_lal, model_type, optimizer; setting = setting)["solution"]       
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")
            continue
        end

        vio = calc_violations(network_lal, network_lal)             

        # Memento.info(_LOGGER, "$(cont.label) violations $(vio)")
        if vio.sm > sm_threshold
            branch_vios = _PMSC.branch_c1_violations_sorted(network_lal, network_lal)          
            branch_vio = branch_vios[1]

            if !haskey(gen_cuts_active, cont.label) || !(branch_vio.branch_id in gen_cuts_active[cont.label])
                Memento.info(_LOGGER, "adding flow cut due to contingency $(cont.label) on branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")

                branch = network_lal["branch"]["$(branch_vio.branch_id)"]
                
                ptdf_branch, dcdf_branch = calc_branch_ptdf_branchdc_dcdf_single(network_lal, ref_bus_id, branch)
                
                cut = (gen_cont_id=cont.idx, cont_label=cont.label, branch_id=branch_vio.branch_id, rating_level=1.0, ptdf_branch=ptdf_branch, dcdf_branch=dcdf_branch)
                push!(gen_cuts, cut)
            else
                Memento.warn(_LOGGER, "skipping flow cut due to contingency $(cont.label) on branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")
            end
        end

        cont_gen["gen_status"] = 1
        cont_gen["pg"] = pg_lost
        network_lal["delta"] = 0.0
    end

    branch_cuts = []
    for (i,cont) in enumerate(branch_contingencies)
        if length(branch_cuts) >= branch_flow_cut_limit
            Memento.info(_LOGGER, "hit branch flow cut limit $(branch_flow_cut_limit)")
            break
        end
        if length(gen_cuts) + length(branch_cuts) >= total_cut_limit
            Memento.info(_LOGGER, "hit total cut limit $(total_cut_limit)")
            break
        end

        # Memento.info(_LOGGER, "working on ($(i)/$(branch_eval_limit)/$(branch_cont_total)): $(cont.label)")

        cont_branch = network_lal["branch"]["$(cont.idx)"]
        cont_branch["br_status"] = 0

        try
            solution = _PMACDC.run_acdcpf(network_lal, model_type, optimizer; setting = setting)["solution"]          
            _PM.update_data!(network_lal, solution)
        catch exception
            Memento.warn(_LOGGER, "acdcpf solve failed on $(cont.label)")
            continue
        end

        vio = calc_violations(network_lal, network_lal)           

        # Memento.info(_LOGGER, "$(cont.label) violations $(vio)")
        if vio.sm > sm_threshold
            branch_vio = _PMSC.branch_c1_violations_sorted(network_lal, network_lal)[1]
            if !haskey(branch_cuts_active, cont.label) || !(branch_vio.branch_id in branch_cuts_active[cont.label])
                Memento.info(_LOGGER, "adding flow cut due to contingency $(cont.label) on branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")

                branch = network_lal["branch"]["$(branch_vio.branch_id)"]
                
                ptdf_branch, dcdf_branch = calc_branch_acdc_ptdf_dcdf_single(network_lal, ref_bus_id, branch)

                # ptdf_branch, dcdf_branch =  calc_branch_ptdf_branchdc_dcdf_single(network_lal, ref_bus_id, branch)
                p_dc_fr = Dict(i => branchdc["pf"] for (i, branchdc) in network_lal["branchdc"])
                p_dc_to = Dict(i => branchdc["pt"] for (i, branchdc) in network_lal["branchdc"])
                
                cut = (branch_cont_id=cont.idx, cont_label=cont.label, branch_id=branch_vio.branch_id, rating_level=1.0, ptdf_branch=ptdf_branch, dcdf_branch=dcdf_branch, p_dc_fr = p_dc_fr, p_dc_to = p_dc_to)
                push!(branch_cuts, cut)
            else
                Memento.warn(_LOGGER, "skipping flow cut due to contingency $(cont.label) on branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")
            end
        end

        cont_branch["br_status"] = 1
    end
    

    branchdc_cuts = []
    for (i,cont) in enumerate(branchdc_contingencies)
        if length(branchdc_cuts) >= branchdc_flow_cut_limit
            Memento.info(_LOGGER, "hit branchdc flow cut limit $(branchdc_flow_cut_limit)")
            break
        end
        if length(gen_cuts) + length(branch_cuts) + length(branchdc_cuts) >= total_cut_limit
            Memento.info(_LOGGER, "hit total cut limit $(total_cut_limit)")
            break
        end

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

        # Memento.info(_LOGGER, "$(cont.label) violations $(vio)")
        if vio.smdc > sm_threshold
            branchdc_vio = branchdc_violations_sorted(network_lal, network_lal)[1]
            if !haskey(branchdc_cuts_active, cont.label) || !(branchdc_vio.branchdc_id in branchdc_cuts_active[cont.label])
                Memento.info(_LOGGER, "adding flow cut due to contingency $(cont.label) on branchdc $(branchdc_vio.branchdc_id) due to constraint flow violations $(branchdc_vio.smdc_vio)")

                branchdc = network_lal["branchdc"]["$(branchdc_vio.branchdc_id)"]
                
                ptdf, idcdf_branchdc = calc_branch_acdc_ptdf_idcdf_single(network_lal, ref_bus_id, branchdc)

                cut = (branchdc_cont_id=cont.idx, cont_label=cont.label, branchdc_id=branchdc["index"], rating_level=1.0, ptdf=ptdf, idcdf_branchdc=idcdf_branchdc)
                push!(branchdc_cuts, cut)
                
            else
                Memento.warn(_LOGGER, "skipping flow cut due to contingency $(cont.label) on branchdc $(branchdc_vio.branchdc_id) due to constraint flow violations $(branchdc_vio.smdc_vio)")
            end
        end
        if vio.sm > sm_threshold
            branch_vio = _PMSC.branch_c1_violations_sorted(network_lal, network_lal)[1]
            if !haskey(branch_cuts_active, cont.label) || !(branch_vio.branch_id in branch_cuts_active[cont.label])
                Memento.info(_LOGGER, "adding flow cut due to contingency $(cont.label) on branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")

                branch = network_lal["branch"]["$(branch_vio.branch_id)"]
                
                ptdf_branch, dcdf_branch = calc_branch_acdc_ptdf_dcdf_single(network_lal, ref_bus_id, branch)

                p_dc_fr = Dict(i => branchdc["pf"] for (i, branchdc) in network_lal["branchdc"])
                p_dc_to = Dict(i => branchdc["pt"] for (i, branchdc) in network_lal["branchdc"])
                
                cut = (branch_cont_id=cont.idx, cont_label=cont.label, branch_id=branch_vio.branch_id, rating_level=1.0, ptdf_branch=ptdf_branch, dcdf_branch=dcdf_branch, p_dc_fr = p_dc_fr, p_dc_to = p_dc_to)
                push!(branch_cuts, cut)
            else
                Memento.warn(_LOGGER, "skipping flow cut due to contingency $(cont.label) on branch $(branch_vio.branch_id) due to constraint flow violations $(branch_vio.sm_vio)")
            end
        end

        cont_branchdc["status"] = 1
    end

    if model_type <: _PM.DCPPowerModel
        if p_delta != 0.0
            Memento.warn(_LOGGER, "re-adjusting loads by $(-p_delta)")
            for (i,load) in load_active
                load["pd"] -= p_delta
            end
        end
    end

    time_contingencies = time() - time_contingencies_start
    Memento.info(_LOGGER, "contingency eval time: $(time_contingencies)")

    return (gen_cuts=gen_cuts, branch_cuts=branch_cuts, branchdc_cuts=branchdc_cuts)
end


function calc_branch_acdc_ptdf_dcdf_single(data::Dict{String,<:Any}, ref_bus::Int, branch::Dict{String,<:Any})
    am = _PM.calc_susceptance_matrix(data)
    
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    b = imag(inv(branch["br_r"] + im * branch["br_x"]))

    va_fr = injection_factors_va(data, am, ref_bus, f_bus)
    va_to = injection_factors_va(data, am, ref_bus, t_bus)

    # convert bus injection functions to PTDF style
    ptdf_branch = Dict(i => -b*(get(va_fr, i, 0.0) - get(va_to, i, 0.0)) for i in union(keys(va_fr), keys(va_to)))

    # add ref bus
    bus_injection = merge!(ptdf_branch, Dict(ref_bus => 0.0))

    # convert to matrix
    I = Int[]
    J = Int[]
    V = Float64[]
    for (i, v) in bus_injection
        push!(I, 1)
        push!(J, i)
        push!(V, v)
    end
    ptdf_single = _PM.sparse(I,J,V)

    # dc incidence matrix without reference bus
    inc_matrix_dc = calc_incidence_matrix_dc(data)  #[:, 1:end .!= ref_bus]

    buses = [x.second for x in data["bus"] if (x.second[_PM.pm_component_status["bus"]] != _PM.pm_component_status_inactive["bus"])]
    sort!(buses, by=x->x["index"])
    if length(ptdf_single) != length(buses)
        Memento.warn(_LOGGER, "adjusting order of PTDF matrix by 1.")
        b = _PM.sparse([0])
        ptdf_single = [ptdf_single b]
    end

    # calculate dcdf_branch 
    dcdf_single = - ptdf_single * transpose(inc_matrix_dc)

    # convert to dictionary
    dcdf_branch = Dict(1:length(dcdf_single) .=> dcdf_single[1, :])

    return ptdf_branch, dcdf_branch 
end


function calc_branch_acdc_ptdf_idcdf_single(data::Dict{String,<:Any}, ref_bus::Int, branchdc::Dict{String,<:Any})
    am = _PM.calc_susceptance_matrix(data)
    num_bus = length(data["bus"])
    num_branch = length(data["branch"])
    ptdf_matrix = zeros(num_branch, num_bus)
    for (b, branch) in data["branch"]
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        b = imag(inv(branch["br_r"] + im * branch["br_x"]))
        va_fr = injection_factors_va(data, am, ref_bus, f_bus)
        va_to = injection_factors_va(data, am, ref_bus, t_bus)
        # convert bus injection functions to PTDF style
        ptdf_branch = Dict(i => -b*(get(va_fr, i, 0.0) - get(va_to, i, 0.0)) for i in union(keys(va_fr), keys(va_to)))
        # add ref bus
        bus_injection = merge!(ptdf_branch, Dict(ref_bus => 0.0))
        # convert to matrix
        if length(bus_injection) != num_bus
            bus_injection[(length(bus_injection)+1)] = 0.0
        end
        for n in 1:num_bus
            ptdf_matrix[branch["index"], n] = bus_injection[n]
        end
    end
    # dc incidence matrix without reference bus
    inc_matrix_dc = calc_incidence_matrix_dc(data) 
    # calculate dcdf_branch 
    dcdf = - ptdf_matrix * transpose(inc_matrix_dc)
    # inverse of dcdf matrix
    idcdf_matrix = _LA.pinv(dcdf)
    # generate idcdf dictionary for the given branchdc
    idcdf_branchdc = Dict(1:length(idcdf_matrix[branchdc["index"], :]) .=> idcdf_matrix[branchdc["index"], :]) 
    # generate ptdf matrix dictionary
    ptdf_wr = Dict(i => Dict(1:length(ptdf_matrix[branch["index"], :]) .=> - ptdf_matrix[branch["index"], :]) for (i, branch) in data["branch"])
    # removing reference bus entries
    ptdf = Dict(i => Dict(k => v for (k, v) in ptdf_d if k != ref_bus) for (i, ptdf_d) in ptdf_wr)

    return ptdf, idcdf_branchdc
end


function injection_factors_va(data, am::_PM.AdmittanceMatrix{T}, ref_bus::Int, bus_id::Int)::Dict{Int,T} where T
    # !haskey(am.bus_to_idx, bus_id) occurs when the bus is inactive
    if ref_bus == bus_id || !haskey(am.bus_to_idx, bus_id)
        return Dict{Int,T}()
    end

    ref_idx = am.bus_to_idx[ref_bus]
    bus_idx = am.bus_to_idx[bus_id]

    # need to remap the indexes to omit the ref_bus id
    # a reverse lookup is also required
    idx2_to_idx1 = Int[]
    for i in 1:length(am.idx_to_bus)
        if i != ref_idx
            push!(idx2_to_idx1, i)
        end
    end
    idx1_to_idx2 = Dict(v => i for (i,v) in enumerate(idx2_to_idx1))

    # rebuild the sparse version of the AdmittanceMatrix without the reference bus
    I = Int[]
    J = Int[]
    V = Float64[]

    I_src, J_src, V_src = _PM.findnz(am.matrix)
    for k in 1:length(V_src)
        if I_src[k] != ref_idx && J_src[k] != ref_idx
            push!(I, idx1_to_idx2[I_src[k]])
            push!(J, idx1_to_idx2[J_src[k]])
            push!(V, V_src[k])
        end
    end
    
    M = _PM.sparse(I,J,V)

    # a vector to select which bus injection factors to compute
    va_vect = zeros(Float64, length(idx2_to_idx1))
    va_vect[idx1_to_idx2[bus_idx]] = 1.0

    # if_vect = M \ va_vect
    
    # if_vect = _LA.pinv(Matrix(M)) * va_vect   
    
    if_vect = _IS.cg(M, va_vect)  # iterative solver

    # map injection factors back to original bus ids
    injection_factors = Dict(am.idx_to_bus[idx2_to_idx1[i]] => v for (i,v) in enumerate(if_vect) if !isapprox(v, 0.0))

    return injection_factors
end

function calc_incidence_matrix_dc(data::Dict{String,<:Any})

    I = Int[]
    J = Int[]   
    V = Int[]

    b = [branchdc for (i,branchdc) in data["branchdc"]]
    branchdc_ordered = sort(b, by=(x) -> x["index"])
    for (i,branchdc) in enumerate(branchdc_ordered)
        fbusdc_conv = [convdc["busac_i"] for (j,convdc) in data["convdc"] if convdc["busdc_i"] == branchdc["fbusdc"]]
        tbusdc_conv = [convdc["busac_i"] for (j,convdc) in data["convdc"] if convdc["busdc_i"] == branchdc["tbusdc"]]
        
        if branchdc["status"] !== 0
            push!(I, i); push!(J, fbusdc_conv[1]); push!(V,  1)
            push!(I, i); push!(J, tbusdc_conv[1]); push!(V, -1)
        
        elseif branchdc["status"] == 0
            push!(I, i); push!(J, fbusdc_conv[1]); push!(V, 0)
            push!(I, i); push!(J, tbusdc_conv[1]); push!(V, 0)
        end

        for k in length(J):length(data["bus"])
            push!(I, i); push!(J, k); push!(V, 0)
        end

    end

    return _PM.sparse(I,J,V)
end


function calc_branch_ptdf_branchdc_dcdf_single(data::Dict{String,<:Any}, ref_bus::Int, branch::Dict{String,<:Any})
    
    ptdf_matrix = calc_ptdf_matrix(data)
    inc_matrix_dc = PowerModelsACDCsecurityconstrained.calc_incidence_matrix_dc(data)   
    dcdf_matrix = - ptdf_matrix * transpose(inc_matrix_dc)

    ptdf_branch_wr = Dict(1:length(ptdf_matrix[branch["index"], :]) .=>  ptdf_matrix[branch["index"], :])
    dcdf_branch = Dict(1:length(dcdf_matrix[branch["index"], :]) .=> dcdf_matrix[branch["index"], :])                       ## remove - dcdf
    ptdf_branch = Dict(k => v for (k, v) in ptdf_branch_wr if k != ref_bus)          # remove reference
    
    # single branch PTDF and DCDF matrix 
    return ptdf_branch, dcdf_branch
end


function calc_ptdf_matrix(data::Dict{String,<:Any})

    num_bus = length(data["bus"])
    num_branch = length(data["branch"])

    b_inv = calc_susceptance_matrix_inv(data).matrix

    ptdf = zeros(num_branch, num_bus)
    for (i,branch) in data["branch"]
        branch_idx = branch["index"]
        bus_fr = branch["f_bus"]
        bus_to = branch["t_bus"]
        g,b =  _PM.calc_branch_y(branch)
        for n in 1:num_bus
            ptdf[branch_idx, n] = b*(b_inv[bus_fr, n] - b_inv[bus_to, n])
        end
    end

    return ptdf
end

function calc_susceptance_matrix_inv(data::Dict{String,<:Any})
    ref_buses = []
    sm = calc_susceptance_matrix(data)

        for (i,bus) in data["bus"]
            if bus["bus_type"] == 3  
            push!(ref_buses, bus)
            end
        end
        ref_bus = ref_buses[1]
    
    sm_inv = calc_admittance_matrix_inv(sm, sm.bus_to_idx[ref_bus["index"]])

    return sm_inv
end

function calc_susceptance_matrix(data::Dict{String,<:Any})
    if length(data["dcline"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with dclines")
    end
    if length(data["switch"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with switches")
    end

    buses = [x.second for x in data["bus"] if (x.second[_PM.pm_component_status["bus"]] != _PM.pm_component_status_inactive["bus"])]
    sort!(buses, by=x->x["index"])

    idx_to_bus = [x["index"] for x in buses]
    bus_type = [x["bus_type"] for x in buses]
    bus_to_idx = Dict(x["index"] => i for (i,x) in enumerate(buses))

    I = Int[]
    J = Int[]
    V = Float64[]
        
    for (i,branch) in data["branch"]
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        if branch[_PM.pm_component_status["branch"]] != _PM.pm_component_status_inactive["branch"] && haskey(bus_to_idx, f_bus) && haskey(bus_to_idx, t_bus)
            f_bus = bus_to_idx[f_bus]
            t_bus = bus_to_idx[t_bus]
            b_val = imag(inv(branch["br_r"] + branch["br_x"]im))
            push!(I, f_bus); push!(J, t_bus); push!(V, -b_val)
            push!(I, t_bus); push!(J, f_bus); push!(V, -b_val)
            push!(I, f_bus); push!(J, f_bus); push!(V,  b_val)
            push!(I, t_bus); push!(J, t_bus); push!(V,  b_val)
        end
    end

    M = _PM.sparse(I,J,V)

    return _PM.AdmittanceMatrix(idx_to_bus, bus_to_idx, M)
end


function calc_admittance_matrix_inv(am::_PM.AdmittanceMatrix, ref_idx::Int)
    num_buses = length(am.idx_to_bus)

    if !(ref_idx > 0 && ref_idx <= num_buses)
        Memento.error(_LOGGER, "invalid ref_idx in calc_admittance_matrix_inv")
    end

    M = Matrix(am.matrix)

    nonref_buses = Int[i for i in 1:num_buses if i != ref_idx]
    am_inv = zeros(Float64, num_buses, num_buses)
    am_inv[nonref_buses, nonref_buses] = _LA.pinv(M[nonref_buses, nonref_buses])

    return _PM.AdmittanceMatrixInverse(am.idx_to_bus, am.bus_to_idx, ref_idx, am_inv)
end


function branchdc_violations_sorted(network::Dict{String,<:Any}, solution::Dict{String,<:Any}; rate_key="rateC")
    branchdc_violations = []

    if haskey(solution, "branchdc")
        for (i,branchdc) in network["branchdc"]
            if branchdc["status"] != 0
                branchdc_sol = solution["branchdc"][i]

                sdc_fr = abs(branchdc_sol["pf"])
                sdc_to = abs(branchdc_sol["pt"])

                smdc_vio = 0.0

                rating = branchdc[rate_key]
                if sdc_fr > rating
                    smdc_vio = sdc_fr - rating
                end
                if sdc_to > rating && sdc_to - rating > smdc_vio
                    smdc_vio = sdc_to - rating
                end

                if smdc_vio > 0.0
                    push!(branchdc_violations, (branchdc_id=branchdc["index"], smdc_vio=smdc_vio))
                end
            end
        end
    end

    sort!(branchdc_violations, by=(x) -> -x.smdc_vio)

    return branchdc_violations
end