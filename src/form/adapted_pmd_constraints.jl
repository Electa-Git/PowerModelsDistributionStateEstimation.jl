################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModelsDistribution.jl for Static Power System   #
# State Estimation.                                                            #
################################################################################

@enum ConnConfig WYE DELTA

function constraint_mc_generator_power_se(pm::_PMD.AbstractUnbalancedIVRModel, id::Int; nw::Int=_IM.nw_id_default, report::Bool=true, bounded::Bool=true)
    generator = _PMD.ref(pm, nw, :gen, id)
    bus =  _PMD.ref(pm, nw,:bus, generator["gen_bus"])

    N = length(generator["connections"])
    pmin = get(generator, "pmin", fill(-Inf, N))
    pmax = get(generator, "pmax", fill( Inf, N))
    qmin = get(generator, "qmin", fill(-Inf, N))
    qmax = get(generator, "qmax", fill( Inf, N))

    if get(generator, "configuration", WYE) == _PMD.WYE
        constraint_mc_generator_power_wye_se(pm, nw, id, bus["index"], generator["connections"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    else
        constraint_mc_generator_power_delta_se(pm, nw, id, bus["index"], generator["connections"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    end
end

"wye connected generator setpoint constraint for IVR formulation - SE adaptation"
function constraint_mc_generator_power_wye_se(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, id::Int, bus_id::Int, connections::Vector{Int}, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
    vr =  _PMD.var(pm, nw, :vr, bus_id)
    vi =  _PMD.var(pm, nw, :vi, bus_id)
    crg =  _PMD.var(pm, nw, :crg, id)
    cig =  _PMD.var(pm, nw, :cig, id)

    if bounded
        for (idx, c) in enumerate(connections)
            if pmin[c]>-Inf
                JuMP.@constraint(pm.model, pmin[idx] .<= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if pmax[c]< Inf
                JuMP.@constraint(pm.model, pmax[idx] .>= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if qmin[c]>-Inf
                JuMP.@constraint(pm.model, qmin[idx] .<= vi[c]*crg[c]  - vr[c]*cig[c])
            end
            if qmax[c]< Inf
                JuMP.@constraint(pm.model, qmax[idx] .>= vi[c]*crg[c]  - vr[c]*cig[c])
            end
        end
    end
end

"delta connected generator setpoint constraint for IVR formulation - adapted for SE"
function constraint_mc_generator_power_delta_se(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, id::Int, bus_id::Int, connections::Vector{Int}, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
    vr =  _PMD.var(pm, nw, :vr, bus_id)
    vi =  _PMD.var(pm, nw, :vi, bus_id)
    crg =  _PMD.var(pm, nw, :crg, id)
    cig =  _PMD.var(pm, nw, :cig, id)

    nph = length(pmin)

    prev = Dict(c=>connections[(idx+nph-2)%nph+1] for (idx,c) in enumerate(connections))
    next = Dict(c=>connections[idx%nph+1] for (idx,c) in enumerate(connections))

    vrg = Dict()
    vig = Dict()
    for c in connections
        vrg[c] = JuMP.@expression(pm.model, vr[c]-vr[next[c]])
        vig[c] = JuMP.@expression(pm.model, vi[c]-vi[next[c]])
    end

    if bounded
        JuMP.@constraint(pm.model, [i in 1:nph], pmin[i] <= vrg[i]*crg[i]+vig[i]*cig[i])
        JuMP.@constraint(pm.model, [i in 1:nph], pmax[i] >= vrg[i]*crg[i]+vig[i]*cig[i])
        JuMP.@constraint(pm.model, [i in 1:nph], qmin[i] <= -vrg[i]*cig[i]+vig[i]*crg[i])
        JuMP.@constraint(pm.model, [i in 1:nph], qmax[i] >= -vrg[i]*cig[i]+vig[i]*crg[i])
    end
end

function constraint_mc_current_balance_se(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=_IM.nw_id_default)
    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs_conns_branch, i)
    bus_arcs_sw = _PMD.ref(pm, nw, :bus_arcs_conns_switch, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_conns_transformer, i)
    bus_gens = _PMD.ref(pm, nw, :bus_conns_gen, i)
    bus_storage = _PMD.ref(pm, nw, :bus_conns_storage, i)
    bus_loads = _PMD.ref(pm, nw, :bus_conns_load, i)
    bus_shunts = _PMD.ref(pm, nw, :bus_conns_shunt, i)

    constraint_mc_current_balance_se(pm, nw, i, bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_shunts)
end

function constraint_mc_current_balance_se(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_loads::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    #NB only difference with pmd is crd_bus replaced by crd, and same with cid
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMD._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMD._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, nw),   :crd, Dict()); _PMD._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, nw),   :cid, Dict()); _PMD._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, nw),   :crg, Dict()); _PMD._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig, Dict()); _PMD._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(_PMD.var(pm, nw),   :crs, Dict()); _PMD._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(_PMD.var(pm, nw),   :cis, Dict()); _PMD._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(_PMD.var(pm, nw),  :crsw, Dict()); _PMD._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMD.var(pm, nw),  :cisw, Dict()); _PMD._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMD._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMD._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    Gs, Bs = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx, t) in ungrounded_terminals
        JuMP.@constraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(crsw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(crs[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum(crd[d][t]         for (d, conns) in bus_loads if t in conns)
                                    - sum( Gs[idx,jdx]*vr[u] -Bs[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    )
        JuMP.@constraint(pm.model, sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(cisw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(cis[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum(cid[d][t]         for (d, conns) in bus_loads if t in conns)
                                    - sum( Gs[idx,jdx]*vi[u] +Bs[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    )
    end
end
#####
# "KCL including transformer arcs and load variables."
function constraint_mc_power_balance_se(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=_IM.nw_id_default)
    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs_conns_branch, i)
    bus_arcs_sw = _PMD.ref(pm, nw, :bus_arcs_conns_switch, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_conns_transformer, i)
    bus_gens = _PMD.ref(pm, nw, :bus_conns_gen, i)
    bus_storage = _PMD.ref(pm, nw, :bus_conns_storage, i)
    bus_loads = _PMD.ref(pm, nw, :bus_conns_load, i)
    bus_shunts = _PMD.ref(pm, nw, :bus_conns_shunt, i)

    constraint_mc_power_balance_se(pm, nw, i, bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_shunts)
end

function constraint_mc_power_balance_se(pm::_PMD.AbstractUnbalancedACRModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_loads::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    #NB only diffeerence is in pd and qd we refer to :qd, :pd instead of :pd_bus, :qd_bus
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    p    = get(_PMD.var(pm, nw), :p,      Dict()); _PMD._check_var_keys(p,   bus_arcs,       "active power",   "branch")
    q    = get(_PMD.var(pm, nw), :q,      Dict()); _PMD._check_var_keys(q,   bus_arcs,       "reactive power", "branch")
    pg   = get(_PMD.var(pm, nw), :pg, Dict()); _PMD._check_var_keys(pg,  bus_gens,       "active power",   "generator")
    qg   = get(_PMD.var(pm, nw), :qg, Dict()); _PMD._check_var_keys(qg,  bus_gens,       "reactive power", "generator")
    ps   = get(_PMD.var(pm, nw), :ps,     Dict()); _PMD._check_var_keys(ps,  bus_storage,    "active power",   "storage")
    qs   = get(_PMD.var(pm, nw), :qs,     Dict()); _PMD._check_var_keys(qs,  bus_storage,    "reactive power", "storage")
    psw  = get(_PMD.var(pm, nw), :psw,    Dict()); _PMD._check_var_keys(psw, bus_arcs_sw,    "active power",   "switch")
    qsw  = get(_PMD.var(pm, nw), :qsw,    Dict()); _PMD._check_var_keys(qsw, bus_arcs_sw,    "reactive power", "switch")
    pt   = get(_PMD.var(pm, nw), :pt,     Dict()); _PMD._check_var_keys(pt,  bus_arcs_trans, "active power",   "transformer")
    qt   = get(_PMD.var(pm, nw), :qt,     Dict()); _PMD._check_var_keys(qt,  bus_arcs_trans, "reactive power", "transformer")
    pd   = get(_PMD.var(pm, nw), :pd, Dict()); _PMD._check_var_keys(pd,  bus_loads,      "active power",   "load")
    qd   = get(_PMD.var(pm, nw), :qd, Dict()); _PMD._check_var_keys(pd,  bus_loads,      "reactive power", "load")

    Gs, Bs = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    cstr_p = []
    cstr_q = []

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    # pd/qd can be NLexpressions, so cannot be vectorized
    for (idx, t) in ungrounded_terminals
        cp = JuMP.@constraint(pm.model, [p, q, pg, qg, ps, qs, psw, qsw, pt, qt, pd, qd, vr, vi],
              sum(  p[arc][t] for (arc, conns) in bus_arcs if t in conns)
            + sum(psw[arc][t] for (arc, conns) in bus_arcs_sw if t in conns)
            + sum( pt[arc][t] for (arc, conns) in bus_arcs_trans if t in conns)
            ==
              sum(pg[gen][t] for (gen, conns) in bus_gens if t in conns)
            - sum(ps[strg][t] for (strg, conns) in bus_storage if t in conns)
            - sum(pd[load][t] for (load, conns) in bus_loads if t in conns)
            + ( -vr[t] * sum(Gs[idx,jdx]*vr[u]-Bs[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals)
                -vi[t] * sum(Gs[idx,jdx]*vi[u]+Bs[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals)
            )
        )
        push!(cstr_p, cp)

        cq = JuMP.@constraint(pm.model, [p, q, pg, qg, ps, qs, psw, qsw, pt, qt, pd, qd, vr, vi],
              sum(  q[arc][t] for (arc, conns) in bus_arcs if t in conns)
            + sum(qsw[arc][t] for (arc, conns) in bus_arcs_sw if t in conns)
            + sum( qt[arc][t] for (arc, conns) in bus_arcs_trans if t in conns)
            ==
              sum(qg[gen][t] for (gen, conns) in bus_gens if t in conns)
            - sum(qd[load][t] for (load, conns) in bus_loads if t in conns)
            - sum(qs[strg][t] for (strg, conns) in bus_storage if t in conns)
            + ( vr[t] * sum(Gs[idx,jdx]*vi[u]+Bs[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals)
               -vi[t] * sum(Gs[idx,jdx]*vr[u]-Bs[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals)
            )
        )
        push!(cstr_q, cq)
    end
end

function constraint_mc_power_balance_se(pm::_PMD.AbstractUnbalancedACPModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_loads::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    vm   = _PMD.var(pm, nw, :vm, i)
    va   = _PMD.var(pm, nw, :va, i)

    p    = get(_PMD.var(pm, nw), :p,      Dict()); _PMD._check_var_keys(p,   bus_arcs,       "active power",   "branch")
    q    = get(_PMD.var(pm, nw), :q,      Dict()); _PMD._check_var_keys(q,   bus_arcs,       "reactive power", "branch")
    pg   = get(_PMD.var(pm, nw), :pg, Dict()); _PMD._check_var_keys(pg,  bus_gens,       "active power",   "generator")
    qg   = get(_PMD.var(pm, nw), :qg, Dict()); _PMD._check_var_keys(qg,  bus_gens,       "reactive power", "generator")
    ps   = get(_PMD.var(pm, nw), :ps,     Dict()); _PMD._check_var_keys(ps,  bus_storage,    "active power",   "storage")
    qs   = get(_PMD.var(pm, nw), :qs,     Dict()); _PMD._check_var_keys(qs,  bus_storage,    "reactive power", "storage")
    psw  = get(_PMD.var(pm, nw), :psw,    Dict()); _PMD._check_var_keys(psw, bus_arcs_sw,    "active power",   "switch")
    qsw  = get(_PMD.var(pm, nw), :qsw,    Dict()); _PMD._check_var_keys(qsw, bus_arcs_sw,    "reactive power", "switch")
    pt   = get(_PMD.var(pm, nw), :pt,     Dict()); _PMD._check_var_keys(pt,  bus_arcs_trans, "active power",   "transformer")
    qt   = get(_PMD.var(pm, nw), :qt,     Dict()); _PMD._check_var_keys(qt,  bus_arcs_trans, "reactive power", "transformer")
    pd   = get(_PMD.var(pm, nw), :pd, Dict()); _PMD._check_var_keys(pd,  bus_loads,      "active power",   "load")
    qd   = get(_PMD.var(pm, nw), :qd, Dict()); _PMD._check_var_keys(pd,  bus_loads,      "reactive power", "load")

    Gs, Bs = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    cstr_p = []
    cstr_q = []

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx,t) in ungrounded_terminals
        if any(Bs[idx,jdx] != 0 for (jdx, u) in ungrounded_terminals if idx != jdx) || any(Gs[idx,jdx] != 0 for (jdx, u) in ungrounded_terminals if idx != jdx)
            cp = JuMP.@constraint(pm.model,
                  sum(  p[a][t] for (a, conns) in bus_arcs if t in conns)
                + sum(psw[a][t] for (a, conns) in bus_arcs_sw if t in conns)
                + sum( pt[a][t] for (a, conns) in bus_arcs_trans if t in conns)
                - sum( pg[g][t] for (g, conns) in bus_gens if t in conns)
                + sum( ps[s][t] for (s, conns) in bus_storage if t in conns)
                + sum( pd[l][t] for (l, conns) in bus_loads if t in conns)
                + ( # shunt
                    +Gs[idx,idx] * vm[t]^2
                    +sum( Gs[idx,jdx] * vm[t]*vm[u] * cos(va[t]-va[u])
                         +Bs[idx,jdx] * vm[t]*vm[u] * sin(va[t]-va[u])
                        for (jdx,u) in ungrounded_terminals if idx != jdx)
                )
                ==
                0.0
            )
            push!(cstr_p, cp)

            cq = JuMP.@constraint(pm.model,
                  sum(  q[a][t] for (a, conns) in bus_arcs if t in conns)
                + sum(qsw[a][t] for (a, conns) in bus_arcs_sw if t in conns)
                + sum( qt[a][t] for (a, conns) in bus_arcs_trans if t in conns)
                - sum( qg[g][t] for (g, conns) in bus_gens if t in conns)
                + sum( qs[s][t] for (s, conns) in bus_storage if t in conns)
                + sum( qd[l][t] for (l, conns) in bus_loads if t in conns)
                + ( # shunt
                    -Bs[idx,idx] * vm[t]^2
                    -sum( Bs[idx,jdx] * vm[t]*vm[u] * cos(va[t]-va[u])
                         -Gs[idx,jdx] * vm[t]*vm[u] * sin(va[t]-va[u])
                         for (jdx,u) in ungrounded_terminals if idx != jdx)
                )
                ==
                0.0
            )
            push!(cstr_q, cq)
        else
            cp = JuMP.@constraint(pm.model, [p, pg, ps, psw, pt, pd, vm],
                  sum(  p[a][t] for (a, conns) in bus_arcs if t in conns)
                + sum(psw[a][t] for (a, conns) in bus_arcs_sw if t in conns)
                + sum( pt[a][t] for (a, conns) in bus_arcs_trans if t in conns)
                - sum( pg[g][t] for (g, conns) in bus_gens if t in conns)
                + sum( ps[s][t] for (s, conns) in bus_storage if t in conns)
                + sum( pd[l][t] for (l, conns) in bus_loads if t in conns)
                + Gs[idx,idx] * vm[t]^2
                ==
                0.0
            )
            push!(cstr_p, cp)

            cq = JuMP.@constraint(pm.model, [q, qg, qs, qsw, qt, qd, vm],
                  sum(  q[a][t] for (a, conns) in bus_arcs if t in conns)
                + sum(qsw[a][t] for (a, conns) in bus_arcs_sw if t in conns)
                + sum( qt[a][t] for (a, conns) in bus_arcs_trans if t in conns)
                - sum( qg[g][t] for (g, conns) in bus_gens if t in conns)
                + sum( qs[s][t] for (s, conns) in bus_storage if t in conns)
                + sum( qd[l][t] for (l, conns) in bus_loads if t in conns)
                - Bs[idx,idx] * vm[t]^2
                ==
                0.0
            )
            push!(cstr_q, cq)
        end
    end
end

function constraint_mc_power_balance_se(pm::_PMD.SDPUBFPowerModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_loads::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    Wr = _PMD.var(pm, nw, :Wr, i)
    Wi = _PMD.var(pm, nw, :Wi, i)
    P = get(_PMD.var(pm, nw), :P, Dict()); _PMD._check_var_keys(P, bus_arcs, "active power", "branch")
    Q = get(_PMD.var(pm, nw), :Q, Dict()); _PMD._check_var_keys(Q, bus_arcs, "reactive power", "branch")
    Psw  = get(_PMD.var(pm, nw),  :Psw, Dict()); _PMD._check_var_keys(Psw, bus_arcs_sw, "active power", "switch")
    Qsw  = get(_PMD.var(pm, nw),  :Qsw, Dict()); _PMD._check_var_keys(Qsw, bus_arcs_sw, "reactive power", "switch")
    Pt   = get(_PMD.var(pm, nw),   :Pt, Dict()); _PMD._check_var_keys(Pt, bus_arcs_trans, "active power", "transformer")
    Qt   = get(_PMD.var(pm, nw),   :Qt, Dict()); _PMD._check_var_keys(Qt, bus_arcs_trans, "reactive power", "transformer")

    pd = get(_PMD.var(pm, nw), :pd, Dict()); _PMD._check_var_keys(pd, bus_loads, "active power", "load")
    qd = get(_PMD.var(pm, nw), :qd, Dict()); _PMD._check_var_keys(qd, bus_loads, "reactive power", "load")
    pg = get(_PMD.var(pm, nw), :pg, Dict()); _PMD._check_var_keys(pg, bus_gens, "active power", "generator")
    qg = get(_PMD.var(pm, nw), :qg, Dict()); _PMD._check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(_PMD.var(pm, nw),   :ps, Dict()); _PMD._check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(_PMD.var(pm, nw),   :qs, Dict()); _PMD._check_var_keys(qs, bus_storage, "reactive power", "storage")

    Gs, Bs = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    cstr_p = []
    cstr_q = []

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx,t) in ungrounded_terminals
        cp = JuMP.@constraint(pm.model,
            sum(diag(P[a])[findfirst(isequal(t), conns)] for (a, conns) in bus_arcs if t in conns)
            + sum(diag(Psw[a_sw])[findfirst(isequal(t), conns)] for (a_sw, conns) in bus_arcs_sw if t in conns)
            + sum(diag(Pt[a_trans])[findfirst(isequal(t), conns)] for (a_trans, conns) in bus_arcs_trans if t in conns)
            ==
            sum(pg[g][t] for (g, conns) in bus_gens if t in conns)
            - sum(ps[s][t] for (s, conns) in bus_storage if t in conns)
            - sum(pd[d][t] for (d, conns) in bus_loads if t in conns)
            - diag(Wr*Gs'+Wi*Bs')[idx]
        )
        push!(cstr_p, cp)

        cq = JuMP.@constraint(pm.model,
            sum(diag(Q[a])[findfirst(isequal(t), conns)] for (a, conns) in bus_arcs if t in conns)
            + sum(diag(Qsw[a_sw])[findfirst(isequal(t), conns)] for (a_sw, conns) in bus_arcs_sw if t in conns)
            + sum(diag(Qt[a_trans])[findfirst(isequal(t), conns)] for (a_trans, conns) in bus_arcs_trans if t in conns)
            ==
            sum(qg[g][t] for (g, conns) in bus_gens if t in conns)
            - sum(qs[s][t] for (s, conns) in bus_storage if t in conns)
            - sum(qd[d][t] for (d, conns) in bus_loads if t in conns)
            - diag(-Wr*Bs'+Wi*Gs')[idx]
        )
        push!(cstr_q, cq)
    end
end

function constraint_mc_power_balance_se(pm::_PMD.LPUBFDiagModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_loads::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    w = _PMD.var(pm, nw, :w, i)
    p   = get(_PMD.var(pm, nw),      :p,   Dict()); _PMD._check_var_keys(p,   bus_arcs, "active power", "branch")
    q   = get(_PMD.var(pm, nw),      :q,   Dict()); _PMD._check_var_keys(q,   bus_arcs, "reactive power", "branch")
    psw = get(_PMD.var(pm, nw),    :psw, Dict()); _PMD._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw = get(_PMD.var(pm, nw),    :qsw, Dict()); _PMD._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    pt  = get(_PMD.var(pm, nw),     :pt,  Dict()); _PMD._check_var_keys(pt,  bus_arcs_trans, "active power", "transformer")
    qt  = get(_PMD.var(pm, nw),     :qt,  Dict()); _PMD._check_var_keys(qt,  bus_arcs_trans, "reactive power", "transformer")
    pg  = get(_PMD.var(pm, nw),     :pg,  Dict()); _PMD._check_var_keys(pg,  bus_gens, "active power", "generator")
    qg  = get(_PMD.var(pm, nw),     :qg,  Dict()); _PMD._check_var_keys(qg,  bus_gens, "reactive power", "generator")
    ps  = get(_PMD.var(pm, nw),     :ps,  Dict()); _PMD._check_var_keys(ps,  bus_storage, "active power", "storage")
    qs  = get(_PMD.var(pm, nw),     :qs,  Dict()); _PMD._check_var_keys(qs,  bus_storage, "reactive power", "storage")
    pd  = get(_PMD.var(pm, nw),     :pd,  Dict()); _PMD._check_var_keys(pd,  bus_loads, "active power", "load")
    qd  = get(_PMD.var(pm, nw),     :qd,  Dict()); _PMD._check_var_keys(qd,  bus_loads, "reactive power", "load")

    cstr_p = []
    cstr_q = []

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx,t) in ungrounded_terminals
        cp = JuMP.@constraint(pm.model,
              sum(  p[a][t] for (a, conns) in bus_arcs if t in conns)
            + sum(psw[a][t] for (a, conns) in bus_arcs_sw if t in conns)
            + sum( pt[a][t] for (a, conns) in bus_arcs_trans if t in conns)
            - sum( pg[g][t] for (g, conns) in bus_gens if t in conns)
            + sum( ps[s][t] for (s, conns) in bus_storage if t in conns)
            + sum( pd[d][t] for (d, conns) in bus_loads if t in conns)
            + sum(diag(ref(pm, nw, :shunt, sh, "gs"))[findfirst(isequal(t), conns)]*w[t] for (sh, conns) in bus_shunts if t in conns)
            ==
            0.0
        )
        push!(cstr_p, cp)

        cq = JuMP.@constraint(pm.model,
              sum(  q[a][t] for (a, conns) in bus_arcs if t in conns)
            + sum(qsw[a][t] for (a, conns) in bus_arcs_sw if t in conns)
            + sum( qt[a][t] for (a, conns) in bus_arcs_trans if t in conns)
            - sum( qg[g][t] for (g, conns) in bus_gens if t in conns)
            + sum( qs[s][t] for (s, conns) in bus_storage if t in conns)
            + sum( qd[d][t] for (d, conns) in bus_loads if t in conns)
            - sum(diag(_PMD.ref(pm, nw, :shunt, sh, "bs"))[findfirst(isequal(t), conns)]*w[t] for (sh, conns) in bus_shunts if t in conns)
            ==
            0.0
        )
        push!(cstr_q, cq)
   end
end
