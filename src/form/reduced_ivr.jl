mutable struct ReducedIVRPowerModel <: _PMs.AbstractIVRModel _PMs.@pm_fields end

"only total current variables defined over the bus_arcs in PMD are considered: with no shunt admittance, these are
equivalent to the series current defined over the branches."
function variable_mc_branch_current(pm::ReducedIVRPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

"if the formulation is not reduced, it is delegated back to PMD"
function variable_mc_branch_current(pm::_PMs.IVRPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

"constraint_mc_gen_setpoint is re-defined here because in PMD the same function only accepts pm::_PMs.IVRPowerModel.
The content of the function is otherwise identical"
function constraint_mc_gen_setpoint(pm::ReducedIVRPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true, bounded::Bool=true)

    generator = _PMD.ref(pm, nw, :gen, id)
    bus = _PMD.ref(pm, nw,:bus, generator["gen_bus"])

    N = 3
    pmin = get(generator, "pmin", fill(-Inf, N))
    pmax = get(generator, "pmax", fill( Inf, N))
    qmin = get(generator, "qmin", fill(-Inf, N))
    qmax = get(generator, "qmax", fill( Inf, N))

    if get(generator, "configuration", _PMD.WYE) == _PMD.WYE
        PowerModelsDSSE.constraint_mc_gen_setpoint_wye(pm, nw, id, bus["index"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    else
        PowerModelsDSSE.constraint_mc_gen_setpoint_delta(pm, nw, id, bus["index"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    end
end

"constraint_mc_gen_setpoint_wye is re-defined here because in PMD the same function only accepts pm::_PMs.IVRPowerModel.
The content of the function is otherwise identical"
function constraint_mc_gen_setpoint_wye(pm::ReducedIVRPowerModel, nw::Int, id::Int, bus_id::Int, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)

    vr = _PMD.var(pm, nw, :vr, bus_id)
    vi = _PMD.var(pm, nw, :vi, bus_id)
    crg = _PMD.var(pm, nw, :crg, id)
    cig = _PMD.var(pm, nw, :cig, id)

    nph = 3

    pg = JuMP.@NLexpression(pm.model, [i in 1:nph],  vr[i]*crg[i]+vi[i]*cig[i])
    qg = JuMP.@NLexpression(pm.model, [i in 1:nph], -vr[i]*cig[i]+vi[i]*crg[i])

    if bounded
        for c in 1:nph
            if pmin[c]>-Inf
                JuMP.@constraint(pm.model, pmin[c] .<= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if pmax[c]< Inf
                JuMP.@constraint(pm.model, pmax[c] .>= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if qmin[c]>-Inf
                JuMP.@constraint(pm.model, qmin[c] .<= vi[c]*crg[c]  - vr[c]*cig[c])
            end
            if qmax[c]< Inf
                JuMP.@constraint(pm.model, qmax[c] .>= vi[c]*crg[c]  - vr[c]*cig[c])
            end
        end
    end
end


"constraint_mc_gen_setpoint_delta is re-defined here because in PMD the same function only accepts pm::_PMs.IVRPowerModel.
The content of the function is otherwise identical"
function constraint_mc_gen_setpoint_delta(pm::ReducedIVRPowerModel, nw::Int, id::Int, bus_id::Int, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
    vr = _PMD.var(pm, nw, :vr, bus_id)
    vi = _PMD.var(pm, nw, :vi, bus_id)
    crg = _PMD.var(pm, nw, :crg, id)
    cig = _PMD.var(pm, nw, :cig, id)

    nph = 3
    prev = Dict(i=>(i+nph-2)%nph+1 for i in 1:nph)
    next = Dict(i=>i%nph+1 for i in 1:nph)

    vrg = JuMP.@NLexpression(pm.model, [i in 1:nph], vr[i]-vr[next[i]])
    vig = JuMP.@NLexpression(pm.model, [i in 1:nph], vi[i]-vi[next[i]])

    pg = JuMP.@NLexpression(pm.model, [i in 1:nph],  vrg[i]*crg[i]+vig[i]*cig[i])
    qg = JuMP.@NLexpression(pm.model, [i in 1:nph], -vrg[i]*cig[i]+vig[i]*crg[i])

    if bounded
        JuMP.@NLconstraint(pm.model, [i in 1:nph], pmin[i] <= pg[i])
        JuMP.@NLconstraint(pm.model, [i in 1:nph], pmax[i] >= pg[i])
        JuMP.@NLconstraint(pm.model, [i in 1:nph], qmin[i] <= qg[i])
        JuMP.@NLconstraint(pm.model, [i in 1:nph], qmax[i] >= qg[i])
    end

    crg_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], crg[i]-crg[prev[i]])
    cig_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], cig[i]-cig[prev[i]])

    _PMD.var(pm, nw, :crg_bus)[id] = crg_bus
    _PMD.var(pm, nw, :cig_bus)[id] = cig_bus
    _PMD.var(pm, nw, :pg)[id] = pg
    _PMD.var(pm, nw, :qg)[id] = qg

    if report
        _PMD.sol(pm, nw, :gen, id)[:crg_bus] = crg_bus
        _PMD.sol(pm, nw, :gen, id)[:cig_bus] = cig_bus
        _PMD.sol(pm, nw, :gen, id)[:pg] = pg
        _PMD.sol(pm, nw, :gen, id)[:qg] = qg
    end
end

"Simplified version of constraint_mc_load_current_balance_se, to perform state
estimation with the reduced IVR formulation: no shunts, no storage elements, no active switches"
function constraint_mc_load_current_balance_se(pm::PowerModelsDSSE.ReducedIVRPowerModel, i::Int; nw::Int=pm.cnw)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = _PMD.ref(pm, nw, :bus_gens, i)
    bus_loads = _PMD.ref(pm, nw, :bus_loads, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMs._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMs._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, nw),   :crd, Dict()); _PMs._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, nw),   :cid, Dict()); _PMs._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, nw),   :crg, Dict()); _PMs._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig, Dict()); _PMs._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMs._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMs._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    for c in _PMs.conductor_ids(pm; nw=nw)
        JuMP.@constraint(pm.model,  sum(cr[a][c] for a in bus_arcs)
                                    + sum(crt[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(crg[g][c]         for g in bus_gens)
                                    - sum(crd[d][c]         for d in bus_loads)
                                    )
        JuMP.@constraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(cig[g][c]         for g in bus_gens)
                                    - sum(cid[d][c]         for d in bus_loads)
                                    )
    end
end

"Simplified version of constraint_mc_load_current_balance, to perform power flow
calculations with the reduced IVR formulation: no shunts, no storage elements, no active switches"
function constraint_mc_load_current_balance(pm::PowerModelsDSSE.ReducedIVRPowerModel, i::Int; nw::Int=pm.cnw)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = _PMD.ref(pm, nw, :bus_gens, i)
    bus_loads = _PMD.ref(pm, nw, :bus_loads, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMs._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMs._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, nw),   :crd_bus, Dict()); _PMs._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, nw),   :cid_bus, Dict()); _PMs._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, nw),   :crg, Dict()); _PMs._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig, Dict()); _PMs._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMs._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMs._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    for c in _PMs.conductor_ids(pm; nw=nw)
        JuMP.@NLconstraint(pm.model,  sum(cr[a][c] for a in bus_arcs)
                                    + sum(crt[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(crg[g][c]         for g in bus_gens)
                                    - sum(crd[d][c]         for d in bus_loads)
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(cig[g][c]         for g in bus_gens)
                                    - sum(cid[d][c]         for d in bus_loads)
                                    )
    end
end

"Constraint that defines the voltage drop along a branch for the ReducedIVRPowerModel.
Conceptually similar to the same function in PowerModelsDistribution, but written in
function of the total current instead of the series current.
This is because in the ReducedIVRPowerModel series current is not defined as it is identical to
the total current due to the absence of shunt admittance."
function constraint_mc_bus_voltage_drop(pm::ReducedIVRPowerModel, i::Int; nw::Int=pm.cnw)

    branch = _PMD.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    tr, ti = _PMs.calc_branch_t(branch)

    r = branch["br_r"]
    x = branch["br_x"]

    vr_fr = _PMD.var(pm, nw, :vr, f_bus)
    vi_fr = _PMD.var(pm, nw, :vi, f_bus)

    vr_to = _PMD.var(pm, nw, :vr, t_bus)
    vi_to = _PMD.var(pm, nw, :vi, t_bus)

    cr_fr =  _PMD.var(pm, nw, :cr, f_idx)
    ci_fr =  _PMD.var(pm, nw, :ci, f_idx)

    JuMP.@constraint(pm.model, vr_to .== (vr_fr.*tr + vi_fr.*ti) - r*cr_fr + x*ci_fr)
    JuMP.@constraint(pm.model, vi_to .== (vi_fr.*tr - vr_fr.*ti) - r*ci_fr - x*cr_fr)
end

"This constraint makes sure that the current entering and exiting a branch are equivalent.
It is used for state estimation and power flow calculations with the ReducedIVRPowerModel."
function constraint_current_to_from(pm::ReducedIVRPowerModel, i::Int; nw::Int=pm.cnw)

    branch = _PMD.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_arc = (i, t_bus, f_bus)
    f_arc = (i, f_bus, t_bus)

    cr_fr = _PMD.var(pm, nw, :cr)[f_arc]
    ci_fr = _PMD.var(pm, nw, :ci)[f_arc]

    cr_to = _PMD.var(pm, nw, :cr)[t_arc]
    ci_to = _PMD.var(pm, nw, :ci)[t_arc]

    JuMP.@constraint(pm.model, cr_fr .== -cr_to)
    JuMP.@constraint(pm.model, ci_fr .== -ci_to)

end
