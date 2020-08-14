mutable struct ReducedIVRPowerModel <: _PMs.AbstractIVRModel _PMs.@pm_fields end

import PowerModelsDistribution.constraint_mc_gen_setpoint, PowerModelsDistribution.constraint_mc_gen_setpoint_wye, PowerModelsDistribution.constraint_mc_gen_setpoint_delta
import PowerModelsDistribution.constraint_mc_load_current_balance, PowerModelsDistribution.constraint_mc_load_setpoint_delta, PowerModelsDistribution.constraint_mc_load_setpoint_wye
import PowerModelsDistribution.constraint_mc_load_setpoint, PowerModelsDistribution.variable_mc_branch_current_real, PowerModelsDistribution.variable_mc_branch_current_imaginary

"No series current vars defined"
function variable_mc_branch_current(pm::ReducedIVRPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)

    PowerModelsDSSE.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    PowerModelsDSSE.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    p = Dict()
    q = Dict()

    for (l,i,j) in _PMD.ref(pm, nw, :arcs_from)
        vr_fr = _PMD.var(pm, nw, :vr, i)
        vi_fr = _PMD.var(pm, nw, :vi, i)
        cr_fr = _PMD.var(pm, nw, :cr, (l,i,j))
        ci_fr = _PMD.var(pm, nw, :ci, (l,i,j))
        vr_to = _PMD.var(pm, nw, :vr, j)
        vi_to = _PMD.var(pm, nw, :vi, j)
        cr_to = _PMD.var(pm, nw, :cr, (l,j,i))
        ci_to = _PMD.var(pm, nw, :ci, (l,j,i))
        p[(l,i,j)] = vr_fr.*cr_fr  + vi_fr.*ci_fr
        q[(l,i,j)] = vi_fr.*cr_fr  - vr_fr.*ci_fr
        p[(l,j,i)] = vr_to.*cr_to  + vi_to.*ci_to
        q[(l,j,i)] = vi_to.*cr_to  - vr_to.*ci_to
    end

    _PMD.var(pm, nw)[:p] = p
    _PMD.var(pm, nw)[:q] = q
    report && _IM.sol_component_value_edge(pm, nw, :branch, :pf, :pt, _PMD.ref(pm, nw, :arcs_from), _PMD.ref(pm, nw, :arcs_to), p)
    report && _IM.sol_component_value_edge(pm, nw, :branch, :qf, :qt, _PMD.ref(pm, nw, :arcs_from), _PMD.ref(pm, nw, :arcs_to), q)
end

function variable_mc_branch_current_real(pm::ReducedIVRPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)

    branch = _PMD.ref(pm, nw, :branch)
    bus = _PMD.ref(pm, nw, :bus)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = _PMD.length(cnds)

    cr = _PMD.var(pm, nw)[:cr] = Dict((l,i,j) => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_cr_$((l,i,j))",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :branch, l), "cr_start", c, 0.0)
        ) for (l,i,j) in _PMD.ref(pm, nw, :arcs)
    )

    if bounded
        for (l,i,j) in ref(pm, nw, :arcs)
            cmax = _calc_branch_current_max(ref(pm, nw, :branch, l), ref(pm, nw, :bus, i))
            set_upper_bound.(cr[(l,i,j)],  cmax)
            set_lower_bound.(cr[(l,i,j)], -cmax)
        end
    end

    report && _IM.sol_component_value_edge(pm, nw, :branch, :cr_fr, :cr_to, _PMD.ref(pm, nw, :arcs_from), _PMD.ref(pm, nw, :arcs_to), cr)
end

function variable_mc_branch_current_imaginary(pm::ReducedIVRPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    branch = _PMD.ref(pm, nw, :branch)
    bus = _PMD.ref(pm, nw, :bus)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    ci = _PMD.var(pm, nw)[:ci] = Dict((l,i,j) => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_ci_$((l,i,j))",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :branch, l), "ci_start", c, 0.0)
        ) for (l,i,j) in _PMD.ref(pm, nw, :arcs)
    )

    if bounded
        for (l,i,j) in _PMD.ref(pm, nw, :arcs)
            cmax = _PMD._calc_branch_current_max(ref(pm, nw, :branch, l), ref(pm, nw, :bus, i))
            set_upper_bound.(ci[(l,i,j)],  cmax)
            set_lower_bound.(ci[(l,i,j)], -cmax)
        end
    end

    report && _IM.sol_component_value_edge(pm, nw, :branch, :ci_fr, :ci_to, _PMD.ref(pm, nw, :arcs_from), _PMD.ref(pm, nw, :arcs_to), ci)
end

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

    _PMD.var(pm, nw, :crg_bus)[id] = crg
    _PMD.var(pm, nw, :cig_bus)[id] = cig
    _PMD.var(pm, nw, :qg)[id] = qg
    _PMD.var(pm, nw, :pg)[id] = pg

    if report
        _PMD.sol(pm, nw, :gen, id)[:crg_bus] = _PMD.var(pm, nw, :crg_bus, id)
        _PMD.sol(pm, nw, :gen, id)[:cig_bus] = _PMD.var(pm, nw, :cig_bus, id)

        _PMD.sol(pm, nw, :gen, id)[:qg] = qg
        _PMD.sol(pm, nw, :gen, id)[:pg] = pg
    end
end


"delta connected generator setpoint constraint for IVR formulation"
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

function constraint_mc_load_current_balance_se(pm::ReducedIVRPowerModel, i::Int; nw::Int=pm.cnw)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = _PMD.ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = _PMD.ref(pm, nw, :bus_gens, i)
    bus_storage = _PMD.ref(pm, nw, :bus_storage, i)
    bus_loads = _PMD.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PMD.ref(pm, nw, :bus_shunts, i)

    constraint_mc_load_current_balance_se(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)
end

function constraint_mc_load_current_balance_se(pm::ReducedIVRPowerModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)

    cr    = get(_PMD.var(pm, n),    :cr, Dict()); _PMs._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, n),    :ci, Dict()); _PMs._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, n),   :crd, Dict()); _PMs._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, n),   :cid, Dict()); _PMs._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, n),   :crg, Dict()); _PMs._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, n),   :cig, Dict()); _PMs._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(_PMD.var(pm, n),   :crs, Dict()); _PMs._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(_PMD.var(pm, n),   :cis, Dict()); _PMs._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(_PMD.var(pm, n),  :crsw, Dict()); _PMs._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMD.var(pm, n),  :cisw, Dict()); _PMs._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMD.var(pm, n),   :crt, Dict()); _PMs._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, n),   :cit, Dict()); _PMs._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    for c in _PMs.conductor_ids(pm; nw=n)
        JuMP.@NLconstraint(pm.model,  sum(cr[a][c] for a in bus_arcs)
                                    + sum(crsw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(crt[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(crg[g][c]         for g in bus_gens)
                                    - sum(crs[s][c]         for s in bus_storage)
                                    - sum(crd[d][c]         for d in bus_loads)
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cisw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(cig[g][c]         for g in bus_gens)
                                    - sum(cis[s][c]         for s in bus_storage)
                                    - sum(cid[d][c]         for d in bus_loads)
                                    )
    end
end

function constraint_mc_load_current_balance(pm::ReducedIVRPowerModel, i::Int; nw::Int=pm.cnw)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = _PMD.ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = _PMD.ref(pm, nw, :bus_gens, i)
    bus_storage = _PMD.ref(pm, nw, :bus_storage, i)
    bus_loads = _PMD.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PMD.ref(pm, nw, :bus_shunts, i)

    PowerModelsDSSE.constraint_mc_load_current_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)
end

function constraint_mc_load_current_balance(pm::ReducedIVRPowerModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)

    cr    = get(_PMD.var(pm, n),    :cr, Dict()); _PMs._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, n),    :ci, Dict()); _PMs._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, n),   :crd_bus, Dict()); _PMs._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, n),   :cid_bus, Dict()); _PMs._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, n),   :crg, Dict()); _PMs._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, n),   :cig, Dict()); _PMs._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(_PMD.var(pm, n),   :crs, Dict()); _PMs._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(_PMD.var(pm, n),   :cis, Dict()); _PMs._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(_PMD.var(pm, n),  :crsw, Dict()); _PMs._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMD.var(pm, n),  :cisw, Dict()); _PMs._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMD.var(pm, n),   :crt, Dict()); _PMs._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, n),   :cit, Dict()); _PMs._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    for c in _PMs.conductor_ids(pm; nw=n)
        JuMP.@NLconstraint(pm.model,  sum(cr[a][c] for a in bus_arcs)
                                    + sum(crsw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(crt[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(crg[g][c]         for g in bus_gens)
                                    - sum(crs[s][c]         for s in bus_storage)
                                    - sum(crd[d][c]         for d in bus_loads)
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cisw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(cig[g][c]         for g in bus_gens)
                                    - sum(cis[s][c]         for s in bus_storage)
                                    - sum(cid[d][c]         for d in bus_loads)
                                    )
    end
end

function constraint_mc_bus_voltage_drop(pm::ReducedIVRPowerModel, i::Int; nw::Int=pm.cnw)

    branch = _PMD.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    tr, ti = _PMs.calc_branch_t(branch)
    r = branch["br_r"]
    x = branch["br_x"]
    tm = branch["tap"]

    constraint_mc_bus_voltage_drop(pm, nw, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)
end

function constraint_mc_bus_voltage_drop(pm::ReducedIVRPowerModel, n::Int, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)

    vr_fr = _PMD.var(pm, n, :vr, f_bus)
    vi_fr = _PMD.var(pm, n, :vi, f_bus)

    vr_to = _PMD.var(pm, n, :vr, t_bus)
    vi_to = _PMD.var(pm, n, :vi, t_bus)

    cr_fr =  _PMD.var(pm, n, :cr, f_idx)
    ci_fr =  _PMD.var(pm, n, :ci, f_idx)

    r = r
    x = x

    JuMP.@constraint(pm.model, vr_to .== (vr_fr.*tr + vi_fr.*ti)./tm.^2 - r*cr_fr + x*ci_fr)
    JuMP.@constraint(pm.model, vi_to .== (vi_fr.*tr - vr_fr.*ti)./tm.^2 - r*ci_fr - x*cr_fr)
end

function constraint_mc_load_setpoint_wye(pm::PowerModelsDSSE.ReducedIVRPowerModel, nw::Int, id::Int, bus_id::Int, a::Vector{<:Real}, alpha::Vector{<:Real}, b::Vector{<:Real}, beta::Vector{<:Real}; report::Bool=true)

    vr = _PMD.var(pm, nw, :vr, bus_id)
    vi = _PMD.var(pm, nw, :vi, bus_id)

    nph = 3

    crd = JuMP.@NLexpression(pm.model, [i in 1:nph],
        a[i]*vr[i]*(vr[i]^2+vi[i]^2)^(alpha[i]/2-1)
       +b[i]*vi[i]*(vr[i]^2+vi[i]^2)^(beta[i]/2 -1)
    )
    cid = JuMP.@NLexpression(pm.model, [i in 1:nph],
        a[i]*vi[i]*(vr[i]^2+vi[i]^2)^(alpha[i]/2-1)
       -b[i]*vr[i]*(vr[i]^2+vi[i]^2)^(beta[i]/2 -1)
    )

    _PMD.var(pm, nw, :crd_bus)[id] = crd
    _PMD.var(pm, nw, :cid_bus)[id] = cid

    if report
        pd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph],  vr[i]*crd[i]+vi[i]*cid[i])
        qd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], -vr[i]*cid[i]+vi[i]*crd[i])

        _PMD.sol(pm, nw, :load, id)[:qd_bus] = qd_bus
        _PMD.sol(pm, nw, :load, id)[:pd_bus] = pd_bus

        _PMD.sol(pm, nw, :load, id)[:crd_bus] = crd
        _PMD.sol(pm, nw, :load, id)[:cid_bus] = cid

        pd = JuMP.@NLexpression(pm.model, [i in 1:nph], a[i]*(vr[i]^2+vi[i]^2)^(alpha[i]/2) )
        qd = JuMP.@NLexpression(pm.model, [i in 1:nph], b[i]*(vr[i]^2+vi[i]^2)^(beta[i]/2)  )
        _PMD.sol(pm, nw, :load, id)[:pd] = pd
        _PMD.sol(pm, nw, :load, id)[:qd] = qd
    end
end


"delta connected load setpoint constraint for IVR formulation"
function constraint_mc_load_setpoint_delta(pm::PowerModelsDSSE.ReducedIVRPowerModel, nw::Int, id::Int, bus_id::Int, a::Vector{<:Real}, alpha::Vector{<:Real}, b::Vector{<:Real}, beta::Vector{<:Real}; report::Bool=true)
    vi = _PMD.var(pm, nw, :vi, bus_id)
    vr = _PMD.var(pm, nw, :vr, bus_id)

    nph = 3
    prev = Dict(i=>(i+nph-2)%nph+1 for i in 1:nph)
    next = Dict(i=>i%nph+1 for i in 1:nph)

    vrd = JuMP.@NLexpression(pm.model, [i in 1:nph], vr[i]-vr[next[i]])
    vid = JuMP.@NLexpression(pm.model, [i in 1:nph], vi[i]-vi[next[i]])

    crd = JuMP.@NLexpression(pm.model, [i in 1:nph],
        a[i]*vrd[i]*(vrd[i]^2+vid[i]^2)^(alpha[i]/2-1)
       +b[i]*vid[i]*(vrd[i]^2+vid[i]^2)^(beta[i]/2 -1)
    )
    cid = JuMP.@NLexpression(pm.model, [i in 1:nph],
        a[i]*vid[i]*(vrd[i]^2+vid[i]^2)^(alpha[i]/2-1)
       -b[i]*vrd[i]*(vrd[i]^2+vid[i]^2)^(beta[i]/2 -1)
    )

    crd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], crd[i]-crd[prev[i]])
    cid_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], cid[i]-cid[prev[i]])

    _PMD.var(pm, nw, :crd_bus)[id] = crd_bus
    _PMD.var(pm, nw, :cid_bus)[id] = cid_bus

    if report
        pd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph],  vr[i]*crd_bus[i]+vi[i]*cid_bus[i])
        qd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], -vr[i]*cid_bus[i]+vi[i]*crd_bus[i])

        _PMD.sol(pm, nw, :load, id)[:pd_bus] = pd_bus
        _PMD.sol(pm, nw, :load, id)[:qd_bus] = qd_bus

        pd = JuMP.@NLexpression(pm.model, [i in 1:nph], a[i]*(vrd[i]^2+vid[i]^2)^(alpha[i]/2) )
        qd = JuMP.@NLexpression(pm.model, [i in 1:nph], b[i]*(vrd[i]^2+vid[i]^2)^(beta[i]/2)  )
        _PMD.sol(pm, nw, :load, id)[:pd] = pd
        _PMD.sol(pm, nw, :load, id)[:qd] = qd
    end
end

function constraint_mc_load_setpoint(pm::PowerModelsDSSE.ReducedIVRPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true)

    load = _PMD.ref(pm, nw, :load, id)
    bus = _PMD.ref(pm, nw,:bus, load["load_bus"])

    conn = haskey(load, "configuration") ? load["configuration"] : _PMD.WYE

    a, alpha, b, beta = _PMD._load_expmodel_params(load, bus)

    if conn==_PMD.WYE
        PowerModelsDSSE.constraint_mc_load_setpoint_wye(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    else
        PowerModelsDSSE.constraint_mc_load_setpoint_delta(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    end
end
