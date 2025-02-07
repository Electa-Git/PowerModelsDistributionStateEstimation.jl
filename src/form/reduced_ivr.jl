################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModelsDistribution.jl for Static Power System   #
# State Estimation.                                                            #
################################################################################
mutable struct ReducedIVRUPowerModel <: _PMD.AbstractUnbalancedIVRModel _PMD.@pmd_fields end

"only total current variables defined over the bus_arcs in PMD are considered: with no shunt admittance, these are
equivalent to the series current defined over the branches."
function variable_mc_branch_current(pm::ReducedIVRUPowerModel; nw::Int=_IM.nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

"if the formulation is not reduced, it is delegated back to PMD"
function variable_mc_branch_current(pm::_PMD.IVRUPowerModel; nw::Int=_IM.nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

"constraint_mc_generator_power is re-defined here because in PMD the same function only accepts pm::_PMD.IVRUPowerModel.
The content of the function is otherwise identical"
function constraint_mc_generator_power(pm::ReducedIVRUPowerModel, id::Int; nw::Int=_IM.nw_id_default, report::Bool=true, bounded::Bool=true)

    generator = _PMD.ref(pm, nw, :gen, id)
    bus = _PMD.ref(pm, nw,:bus, generator["gen_bus"])

    N = length(generator["connections"])
    pmin = get(generator, "pmin", fill(-Inf, N))
    pmax = get(generator, "pmax", fill( Inf, N))
    qmin = get(generator, "qmin", fill(-Inf, N))
    qmax = get(generator, "qmax", fill( Inf, N))

    if get(generator, "configuration", _PMD.WYE) == _PMD.WYE
        _PMDSE.constraint_mc_generator_power_wye(pm, nw, id, bus["index"], generator["connections"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    else
        _PMDSE.constraint_mc_generator_power_delta(pm, nw, id, bus["index"], generator["connections"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    end
end

"constraint_mc_generator_power_wye is re-defined here because in PMD the same function only accepts pm::_PMD.IVRUPowerModel.
The content of the function is otherwise identical"
function constraint_mc_generator_power_wye(pm::ReducedIVRUPowerModel, nw::Int, id::Int, bus_id::Int, connections::Vector{Int}, pmin::Vector{<:Real}, pmax::Vector{<:Real}, qmin::Vector{<:Real}, qmax::Vector{<:Real}; report::Bool=true, bounded::Bool=true)

    vr = _PMD.var(pm, nw, :vr, bus_id)
    vi = _PMD.var(pm, nw, :vi, bus_id)
    crg = _PMD.var(pm, nw, :crg, id)
    cig = _PMD.var(pm, nw, :cig, id)

    pg = JuMP.NonlinearExpr[]
    qg = JuMP.NonlinearExpr[]

    for (idx, c) in enumerate(connections)
        push!(pg, JuMP.@expression(pm.model,  vr[c]*crg[c]+vi[c]*cig[c]))
        push!(qg, JuMP.@expression(pm.model, -vr[c]*cig[c]+vi[c]*crg[c]))
    end

    if bounded
        for (idx,c) in enumerate(connections)
            if pmin[idx]>-Inf
                JuMP.@constraint(pm.model, pmin[idx] .<= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if pmax[idx]< Inf
                JuMP.@constraint(pm.model, pmax[idx] .>= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if qmin[idx]>-Inf
                JuMP.@constraint(pm.model, qmin[idx] .<= vi[c]*crg[c]  - vr[c]*cig[c])
            end
            if qmax[idx]< Inf
                JuMP.@constraint(pm.model, qmax[idx] .>= vi[c]*crg[c]  - vr[c]*cig[c])
            end
        end
    end

   _PMD.var(pm, nw, :pg)[id] = JuMP.Containers.DenseAxisArray(pg, connections)
   _PMD.var(pm, nw, :qg)[id] = JuMP.Containers.DenseAxisArray(qg, connections)

end
"constraint_mc_generator_power_delta is re-defined here because in PMD the same function only accepts pm::_PMD.IVRUPowerModel.
The content of the function is otherwise identical"
function constraint_mc_generator_power_delta(pm::ReducedIVRUPowerModel, nw::Int, id::Int, bus_id::Int, connections::Vector{Int}, pmin::Vector{<:Real}, pmax::Vector{<:Real}, qmin::Vector{<:Real}, qmax::Vector{<:Real}; report::Bool=true, bounded::Bool=true)
    vr = _PMD.var(pm, nw, :vr, bus_id)
    vi = _PMD.var(pm, nw, :vi, bus_id)
    crg = _PMD.var(pm, nw, :crg, id)
    cig = _PMD.var(pm, nw, :cig, id)

    nph = length(pmin)

    prev = Dict(c=>connections[(idx+nph-2)%nph+1] for (idx,c) in enumerate(connections))
    next = Dict(c=>connections[idx%nph+1] for (idx,c) in enumerate(connections))

    vrg = Dict()
    vig = Dict()
    for c in connections
        vrg[c] = JuMP.@expression(pm.model, vr[c]-vr[next[c]])
        vig[c] = JuMP.@expression(pm.model, vi[c]-vi[next[c]])
    end

    pg = JuMP.NonlinearExpr[]
    qg = JuMP.NonlinearExpr[]
    for c in connections
        push!(pg, JuMP.@expression(pm.model,  vrg[c]*crg[c]+vig[c]*cig[c]))
        push!(qg, JuMP.@expression(pm.model, -vrg[c]*cig[c]+vig[c]*crg[c]))
    end

    if bounded
        JuMP.@constraint(pm.model, [i in 1:nph], pmin[i] <= pg[i])
        JuMP.@constraint(pm.model, [i in 1:nph], pmax[i] >= pg[i])
        JuMP.@constraint(pm.model, [i in 1:nph], qmin[i] <= qg[i])
        JuMP.@constraint(pm.model, [i in 1:nph], qmax[i] >= qg[i])
    end

    crg_bus = JuMP.NonlinearExpr[]
    cig_bus = JuMP.NonlinearExpr[]
    for c in connections
        push!(crg_bus, JuMP.@expression(pm.model, crg[c]-crg[prev[c]]))
        push!(cig_bus, JuMP.@expression(pm.model, cig[c]-cig[prev[c]]))
    end

   _PMD.var(pm, nw, :crg_bus)[id] = JuMP.Containers.DenseAxisArray(crg_bus, connections)
   _PMD.var(pm, nw, :cig_bus)[id] = JuMP.Containers.DenseAxisArray(cig_bus, connections)
   _PMD.var(pm, nw, :pg)[id] = JuMP.Containers.DenseAxisArray(pg, connections)
   _PMD.var(pm, nw, :qg)[id] = JuMP.Containers.DenseAxisArray(qg, connections)

    if report
       _PMD.sol(pm, nw, :gen, id)[:crg_bus] = JuMP.Containers.DenseAxisArray(crg_bus, connections)
       _PMD.sol(pm, nw, :gen, id)[:cig_bus] = JuMP.Containers.DenseAxisArray(cig_bus, connections)
       _PMD.sol(pm, nw, :gen, id)[:pg] = JuMP.Containers.DenseAxisArray(pg, connections)
       _PMD.sol(pm, nw, :gen, id)[:qg] = JuMP.Containers.DenseAxisArray(qg, connections)
    end
end

"Simplified version of constraint_mc_current_balance_se, to perform state
estimation with the reduced IVR formulation: no shunts, no storage elements, no active switches"
function constraint_mc_current_balance_se(pm::_PMDSE.ReducedIVRUPowerModel, i::Int; nw::Int=_IM.nw_id_default)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs_conns_branch, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_conns_transformer, i)
    bus_gens = _PMD.ref(pm, nw, :bus_conns_gen, i)
    bus_loads = _PMD.ref(pm, nw, :bus_conns_load, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMD._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMD._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, nw),   :crd, Dict()); _PMD._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, nw),   :cid, Dict()); _PMD._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, nw),   :crg, Dict()); _PMD._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig, Dict()); _PMD._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMD._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMD._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    terminals = bus["terminals"]
    grounded =  bus["grounded"]
    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx, t) in ungrounded_terminals
        JuMP.@constraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(crd[d][t]         for (d, conns) in bus_loads if t in conns)
                                    )

        JuMP.@constraint(pm.model, sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(cid[d][t]         for (d, conns) in bus_loads if t in conns)
                                    )
    end
end

"Simplified version of constraint_mc_current_balance, to perform power flow
calculations with the reduced IVR formulation: no shunts, no storage elements, no active switches"
function constraint_mc_current_balance(pm::_PMDSE.ReducedIVRUPowerModel, i::Int; nw::Int=_IM.nw_id_default)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs_conns_branch, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_conns_transformer, i)
    bus_gens = _PMD.ref(pm, nw, :bus_conns_gen, i)
    bus_loads = _PMD.ref(pm, nw, :bus_conns_load, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMD._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMD._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, nw),   :crd, Dict()); _PMD._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, nw),   :cid, Dict()); _PMD._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, nw),   :crg, Dict()); _PMD._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig, Dict()); _PMD._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMD._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMD._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    terminals = bus["terminals"]
    grounded =  bus["grounded"]
    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx, t) in ungrounded_terminals
        JuMP.@constraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(crd[d][t]         for (d, conns) in bus_loads if t in conns)
                                    )

        JuMP.@constraint(pm.model, sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(cid[d][t]         for (d, conns) in bus_loads if t in conns)
                                    )
    end
end

"Constraint that defines the voltage drop along a branch for the ReducedIVRUPowerModel.
Conceptually similar to the same function in PowerModelsDistribution, but written in
function of the total current instead of the series current.
This is because in the ReducedIVRUPowerModel series current is not defined as it is identical to
the total current due to the absence of shunt admittance."
function constraint_mc_bus_voltage_drop(pm::ReducedIVRUPowerModel, i::Int; nw::Int=_IM.nw_id_default)

    branch = _PMD.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    r = branch["br_r"]
    x = branch["br_x"]

    vr_fr = [_PMD.var(pm, nw, :vr, f_bus)[c] for c in branch["f_connections"]]
    vi_fr = [_PMD.var(pm, nw, :vi, f_bus)[c] for c in branch["f_connections"]]

    vr_to = [_PMD.var(pm, nw, :vr, t_bus)[c] for c in branch["t_connections"]]
    vi_to = [_PMD.var(pm, nw, :vi, t_bus)[c] for c in branch["t_connections"]]

    cr_fr = [_PMD.var(pm, nw, :cr, f_idx)[c] for c in branch["f_connections"]]
    ci_fr = [_PMD.var(pm, nw, :ci, f_idx)[c] for c in branch["f_connections"]]

    JuMP.@constraint(pm.model, vr_to .== vr_fr - r*cr_fr + x*ci_fr)
    JuMP.@constraint(pm.model, vi_to .== vi_fr - r*ci_fr - x*cr_fr)
end

"This constraint makes sure that the current entering and exiting a branch are equivalent.
It is used for state estimation and power flow calculations with the ReducedIVRUPowerModel."
function constraint_current_to_from(pm::ReducedIVRUPowerModel, i::Int; nw::Int=_IM.nw_id_default)

    branch = _PMD.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_arc = (i, t_bus, f_bus)
    f_arc = (i, f_bus, t_bus)

    cr_fr = [_PMD.var(pm, nw, :cr, f_arc)[c] for c in branch["f_connections"]]
    ci_fr = [_PMD.var(pm, nw, :ci, f_arc)[c] for c in branch["f_connections"]]

    cr_to = [_PMD.var(pm, nw, :cr, t_arc)[c] for c in branch["t_connections"]]
    ci_to = [_PMD.var(pm, nw, :ci, t_arc)[c] for c in branch["t_connections"]]

    JuMP.@constraint(pm.model, cr_fr .== -cr_to)
    JuMP.@constraint(pm.model, ci_fr .== -ci_to)

end
