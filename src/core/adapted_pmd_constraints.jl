@enum ConnConfig WYE DELTA

function constraint_mc_gen_setpoint_se(pm::_PMs.IVRPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true, bounded::Bool=true)
    generator = _PMD.ref(pm, nw, :gen, id)
    bus =  _PMD.ref(pm, nw,:bus, generator["gen_bus"])

    N = 3
    pmin = get(generator, "pmin", fill(-Inf, N))
    pmax = get(generator, "pmax", fill( Inf, N))
    qmin = get(generator, "qmin", fill(-Inf, N))
    qmax = get(generator, "qmax", fill( Inf, N))

    if get(generator, "configuration", WYE) == _PMD.WYE
        constraint_mc_gen_setpoint_wye_se(pm, nw, id, bus["index"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    else
        constraint_mc_gen_setpoint_delta_se(pm, nw, id, bus["index"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    end
end

"wye connected generator setpoint constraint for IVR formulation - SE adaptation"
function constraint_mc_gen_setpoint_wye_se(pm::_PMs.IVRPowerModel, nw::Int, id::Int, bus_id::Int, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
    vr =  _PMD.var(pm, nw, :vr, bus_id)
    vi =  _PMD.var(pm, nw, :vi, bus_id)
    crg =  _PMD.var(pm, nw, :crg, id)
    cig =  _PMD.var(pm, nw, :cig, id)
    nph = 3
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
    if report
        _PMD.sol(pm, nw, :gen, id)[:crg_bus] =  _PMD.var(pm, nw, :crg_bus, id)
        _PMD.sol(pm, nw, :gen, id)[:cig_bus] =  _PMD.var(pm, nw, :crg_bus, id)
    end
end

"delta connected generator setpoint constraint for IVR formulation - adapted for SE"
function constraint_mc_gen_setpoint_delta_se(pm::_PMs.IVRPowerModel, nw::Int, id::Int, bus_id::Int, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
    vr =  _PMD.var(pm, nw, :vr, bus_id)
    vi =  _PMD.var(pm, nw, :vi, bus_id)
    crg =  _PMD.var(pm, nw, :crg, id)
    cig =  _PMD.var(pm, nw, :cig, id)
    nph = 3
    prev = Dict(i=>(i+nph-2)%nph+1 for i in 1:nph)
    next = Dict(i=>i%nph+1 for i in 1:nph)
    vrg = JuMP.@NLexpression(pm.model, [i in 1:nph], vr[i]-vr[next[i]])
    vig = JuMP.@NLexpression(pm.model, [i in 1:nph], vi[i]-vi[next[i]])
    if bounded
        JuMP.@NLconstraint(pm.model, [i in 1:nph], pmin[i] <= vrg[i]*crg[i]+vig[i]*cig[i])
        JuMP.@NLconstraint(pm.model, [i in 1:nph], pmax[i] >= vrg[i]*crg[i]+vig[i]*cig[i])
        JuMP.@NLconstraint(pm.model, [i in 1:nph], qmin[i] <= -vrg[i]*cig[i]+vig[i]*crg[i])
        JuMP.@NLconstraint(pm.model, [i in 1:nph], qmax[i] >= -vrg[i]*cig[i]+vig[i]*crg[i])
    end
    crg_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], crg[i]-crg[prev[i]])
    cig_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], cig[i]-cig[prev[i]])
     _PMD.var(pm, nw, :crg_bus)[id] = crg_bus
     _PMD.var(pm, nw, :cig_bus)[id] = cig_bus
    if report
        _PMD.sol(pm, nw, :gen, id)[:crg_bus] = crg_bus
        _PMD.sol(pm, nw, :gen, id)[:cig_bus] = cig_bus
    end
end

function constraint_mc_load_setpoint_se(pm::_PMs.AbstractPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true)
    load = _PMD.ref(pm, nw, :load, id)
    bus = _PMD.ref(pm, nw,:bus, load["load_bus"])

    conn = haskey(load, "configuration") ? load["configuration"] : WYE

    a, alpha, b, beta = _PMD._load_expmodel_params(load, bus)

    if conn==_PMD.WYE
        constraint_mc_load_setpoint_wye_se(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    else
        constraint_mc_load_setpoint_delta_se(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    end
end

function constraint_mc_load_setpoint_wye_se(pm::_PMs.IVRPowerModel, nw::Int, id::Int, bus_id::Int, a::Vector{<:Real}, alpha::Vector{<:Real}, b::Vector{<:Real}, beta::Vector{<:Real}; report::Bool=true)
    vr = _PMD.var(pm, nw, :vr, bus_id)
    vi = _PMD.var(pm, nw, :vi, bus_id)
    crd = _PMD.var(pm, nw, :crd, id)
    cid = _PMD.var(pm, nw, :cid, id)

    nph = 3

    for c in 1:nph
        JuMP.@NLconstraint(pm.model, crd[c] ==
            a[c]*vr[c]*(vr[c]^2+vi[c]^2)^(alpha[c]/2-1)
           +b[c]*vi[c]*(vr[c]^2+vi[c]^2)^(beta[c]/2 -1)
        )
        JuMP.@NLconstraint(pm.model, cid[c] ==
            a[c]*vi[c]*(vr[c]^2+vi[c]^2)^(alpha[c]/2-1)
           -b[c]*vr[c]*(vr[c]^2+vi[c]^2)^(beta[c]/2 -1)
        )
    end

    if report
        pd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph],  vr[i]*crd[i]+vi[i]*cid[i])
        qd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], -vr[i]*cid[i]+vi[i]*crd[i])

        _PMD.sol(pm, nw, :load, id)[:pd_bus] = pd_bus
        _PMD.sol(pm, nw, :load, id)[:qd_bus] = qd_bus

        pd = JuMP.@NLexpression(pm.model, [i in 1:nph], a[i]*(vr[i]^2+vi[i]^2)^(alpha[i]/2) )
        qd = JuMP.@NLexpression(pm.model, [i in 1:nph], b[i]*(vr[i]^2+vi[i]^2)^(beta[i]/2)  )
        _PMD.sol(pm, nw, :load, id)[:pd] = pd
        _PMD.sol(pm, nw, :load, id)[:qd] = qd
    end
end


function constraint_mc_load_setpoint_delta_se(pm::_PMs.IVRPowerModel, nw::Int, id::Int, bus_id::Int, a::Vector{<:Real}, alpha::Vector{<:Real}, b::Vector{<:Real}, beta::Vector{<:Real}; report::Bool=true)
    vr = _PMD.var(pm, nw, :vr, bus_id)
    vi = _PMD.var(pm, nw, :vi, bus_id)

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

        sol(pm, nw, :load, id)[:pd_bus] = pd_bus
        sol(pm, nw, :load, id)[:qd_bus] = qd_bus

        pd = JuMP.@NLexpression(pm.model, [i in 1:nph], a[i]*(vrd[i]^2+vid[i]^2)^(alpha[i]/2) )
        qd = JuMP.@NLexpression(pm.model, [i in 1:nph], b[i]*(vrd[i]^2+vid[i]^2)^(beta[i]/2)  )
        sol(pm, nw, :load, id)[:pd] = pd
        sol(pm, nw, :load, id)[:qd] = qd
    end
end

function constraint_mc_load_current_balance_se(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = _PMD.ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = _PMD.ref(pm, nw, :bus_gens, i)
    bus_storage = _PMD.ref(pm, nw, :bus_storage, i)
    bus_loads = _PMD.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PMD.ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => _PMD.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PMD.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_mc_load_current_balance_se(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
end


function constraint_mc_load_current_balance_se(pm::_PMs.AbstractIVRModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
    #NB only difference with pmd is crd_bus replaced by crd, and same with cid
    vr = _PMD.var(pm, n, :vr, i)
    vi = _PMD.var(pm, n, :vi, i)

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

    cnds = _PMs.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    Gt = isempty(bus_gs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_gs))
    Bt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_bs))

    for c in cnds
        JuMP.@NLconstraint(pm.model,  sum(cr[a][c] for a in bus_arcs)
                                    + sum(crsw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(crt[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(crg[g][c]         for g in bus_gens)
                                    - sum(crs[s][c]         for s in bus_storage)
                                    - sum(crd[d][c]         for d in bus_loads)
                                    - sum( Gt[c,d]*vr[d] -Bt[c,d]*vi[d] for d in cnds) # shunts
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cisw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                      sum(cig[g][c]         for g in bus_gens)
                                    - sum(cis[s][c]         for s in bus_storage)
                                    - sum(cid[d][c]         for d in bus_loads)
                                    - sum( Gt[c,d]*vi[d] +Bt[c,d]*vr[d] for d in cnds) # shunts
                                    )
    end
end
