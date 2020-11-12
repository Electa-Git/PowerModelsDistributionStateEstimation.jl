################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                                             #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

@enum ConnConfig WYE DELTA

function constraint_mc_gen_setpoint_se(pm::_PMs.AbstractIVRModel, id::Int; nw::Int=pm.cnw, report::Bool=true, bounded::Bool=true)
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
function constraint_mc_gen_setpoint_wye_se(pm::_PMs.AbstractIVRModel, nw::Int, id::Int, bus_id::Int, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
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
end

"delta connected generator setpoint constraint for IVR formulation - adapted for SE"
function constraint_mc_gen_setpoint_delta_se(pm::_PMs.AbstractIVRModel, nw::Int, id::Int, bus_id::Int, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
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
#
# "KCL including transformer arcs and load variables."
function constraint_mc_load_power_balance_se(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
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

    p    = get(_PMD.var(pm, nw),    :p, Dict()); _PMs._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(_PMD.var(pm, nw),    :q, Dict()); _PMs._check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(_PMD.var(pm, nw),   :pg_bus, Dict()); _PMs._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(_PMD.var(pm, nw),   :qg_bus, Dict()); _PMs._check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(_PMD.var(pm, nw),   :ps, Dict()); _PMs._check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(_PMD.var(pm, nw),   :qs, Dict()); _PMs._check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(_PMD.var(pm, nw),  :psw, Dict()); _PMs._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(_PMD.var(pm, nw),  :qsw, Dict()); _PMs._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    pt   = get(_PMD.var(pm, nw),   :pt, Dict()); _PMs._check_var_keys(pt, bus_arcs_trans, "active power", "transformer")
    qt   = get(_PMD.var(pm, nw),   :qt, Dict()); _PMs._check_var_keys(qt, bus_arcs_trans, "reactive power", "transformer")
    pd   = get(_PMD.var(pm, nw),  :pd, Dict()); _PMs._check_var_keys(pd, bus_loads, "active power", "load")
    qd   = get(_PMD.var(pm, nw),  :qd, Dict()); _PMs._check_var_keys(pd, bus_loads, "reactive power", "load")

    Gt = isempty(bus_gs) ? fill(0.0, length(_PMD.conductor_ids(pm; nw=nw)), length(_PMD.conductor_ids(pm; nw=nw))) : sum(values(bus_gs))
    Bt = isempty(bus_bs) ? fill(0.0, length(_PMD.conductor_ids(pm; nw=nw)),length(_PMD.conductor_ids(pm; nw=nw))) : sum(values(bus_bs))

    constraint_mc_load_power_balance_se(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs, p, q, pg, qg, ps, qs, psw, qsw, pt, qt, pd, qd, Gt, Bt)
end

function constraint_mc_load_power_balance_se(pm::_PMs.AbstractACRModel, nw::Int, i::Int, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs, p, q, pg, qg, ps, qs, psw, qsw, pt, qt, pd, qd, Gt, Bt)
    #NB only diffeerence is in pd and qd we refer to :qd, :pd instead of :pd_bus, :qd_bus
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    cstr_p = []
    cstr_q = []

    cnds = _PMD.conductor_ids(pm; nw=nw)
    # pd/qd can be NLexpressions, so cannot be vectorized
    for c in _PMD.conductor_ids(pm; nw=nw)
        cp = JuMP.@NLconstraint(pm.model,
            sum(p[a][c] for a in bus_arcs)
            + sum(psw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(pt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(pg[g][c] for g in bus_gens)
            - sum(ps[s][c] for s in bus_storage)
            - sum(pd[l][c] for l in bus_loads)
            - sum( # shunt
                   vr[c] * ( Gt[c,d]*vr[d] - Bt[c,d]*vi[d])
                  -vi[c] * (-Bt[c,d]*vr[d] - Gt[c,d]*vi[d])
              for d in cnds)
        )
        push!(cstr_p, cp)

        cq = JuMP.@NLconstraint(pm.model,
            sum(q[a][c] for a in bus_arcs)
            + sum(qsw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(qt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(qg[g][c] for g in bus_gens)
            - sum(qs[s][c] for s in bus_storage)
            - sum(qd[l][c] for l in bus_loads)
            - sum( # shunt
                  -vr[c] * (Bt[c,d]*vr[d] + Gt[c,d]*vi[d])
                  +vi[c] * (Gt[c,d]*vr[d] - Bt[c,d]*vi[d])
              for d in cnds)
        )
        push!(cstr_q, cq)
    end
end

function constraint_mc_load_power_balance_se(pm::_PMs.AbstractACPModel, nw::Int, i::Int, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs, p, q, pg, qg, ps, qs, psw, qsw, pt, qt, pd, qd, Gt, Bt)
    vm   = _PMD.var(pm, nw, :vm, i)
    va   = _PMD.var(pm, nw, :va, i)

    cstr_p = []
    cstr_q = []

    cnds = _PMD.conductor_ids(pm; nw=nw)

    for c in _PMD.conductor_ids(pm; nw=nw)
        cp = JuMP.@NLconstraint(pm.model,
            sum(p[a][c] for a in bus_arcs)
            + sum(psw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(pt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(pg[g][c] for g in bus_gens)
            - sum(ps[s][c] for s in bus_storage)
            - sum(pd[l][c] for l in bus_loads)
            - ( # shunt
                Gt[c,c] * vm[c]^2
                +sum( Gt[c,d] * vm[c]*vm[d] * cos(va[c]-va[d])
                     +Bt[c,d] * vm[c]*vm[d] * sin(va[c]-va[d])
                     for d in cnds if d != c)
            )
        )
        push!(cstr_p, cp)

        cq = JuMP.@NLconstraint(pm.model,
            sum(q[a][c] for a in bus_arcs)
            + sum(qsw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(qt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(qg[g][c] for g in bus_gens)
            - sum(qs[s][c] for s in bus_storage)
            - sum(qd[l][c] for l in bus_loads)
            - ( # shunt
                -Bt[c,c] * vm[c]^2
                -sum( Bt[c,d] * vm[c]*vm[d] * cos(va[c]-va[d])
                     -Gt[c,d] * vm[c]*vm[d] * sin(va[c]-va[d])
                     for d in cnds if d != c)
            )
        )
        push!(cstr_q, cq)
    end
end

function constraint_mc_load_power_balance_se(pm::_PMD.SDPUBFPowerModel, i::Int; nw::Int=pm.cnw)
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

    constraint_mc_load_power_balance_se(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
end


function constraint_mc_load_power_balance_se(pm::_PMD.SDPUBFPowerModel, nw::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
    Wr = _PMD.var(pm, nw, :Wr, i)
    Wi = _PMD.var(pm, nw, :Wi, i)
    P = get(_PMD.var(pm, nw), :P, Dict()); _PMs._check_var_keys(P, bus_arcs, "active power", "branch")
    Q = get(_PMD.var(pm, nw), :Q, Dict()); _PMs._check_var_keys(Q, bus_arcs, "reactive power", "branch")
    Psw  = get(_PMD.var(pm, nw),  :Psw, Dict()); _PMs._check_var_keys(Psw, bus_arcs_sw, "active power", "switch")
    Qsw  = get(_PMD.var(pm, nw),  :Qsw, Dict()); _PMs._check_var_keys(Qsw, bus_arcs_sw, "reactive power", "switch")
    Pt   = get(_PMD.var(pm, nw),   :Pt, Dict()); _PMs._check_var_keys(Pt, bus_arcs_trans, "active power", "transformer")
    Qt   = get(_PMD.var(pm, nw),   :Qt, Dict()); _PMs._check_var_keys(Qt, bus_arcs_trans, "reactive power", "transformer")

    pd = get(_PMD.var(pm, nw), :pd, Dict()); _PMs._check_var_keys(pd, bus_loads, "active power", "load")
    qd = get(_PMD.var(pm, nw), :qd, Dict()); _PMs._check_var_keys(qd, bus_loads, "reactive power", "load")
    pg = get(_PMD.var(pm, nw), :pg, Dict()); _PMs._check_var_keys(pg, bus_gens, "active power", "generator")
    qg = get(_PMD.var(pm, nw), :qg, Dict()); _PMs._check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(_PMD.var(pm, nw),   :ps, Dict()); _PMs._check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(_PMD.var(pm, nw),   :qs, Dict()); _PMs._check_var_keys(qs, bus_storage, "reactive power", "storage")

    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    Gt = isempty(bus_gs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_gs))
    Bt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_bs))

    cstr_p = JuMP.@constraint(pm.model,
        sum(diag(P[a]) for a in bus_arcs)
        + sum(diag(Psw[a_sw]) for a_sw in bus_arcs_sw)
        + sum(diag(Pt[a_trans]) for a_trans in bus_arcs_trans)
        .==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd[d] for d in bus_loads)
        - diag(Wr*Gt'+Wi*Bt')
    )

    cstr_q = JuMP.@constraint(pm.model,
        sum(diag(Q[a]) for a in bus_arcs)
        + sum(diag(Qsw[a_sw]) for a_sw in bus_arcs_sw)
        + sum(diag(Qt[a_trans]) for a_trans in bus_arcs_trans)
        .==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd[d] for d in bus_loads)
        - diag(-Wr*Bt'+Wi*Gt')
    )

end
