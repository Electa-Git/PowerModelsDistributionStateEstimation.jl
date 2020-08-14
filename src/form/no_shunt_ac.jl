mutable struct ReducedACPPowerModel <: _PMs.AbstractACPModel _PMs.@pm_fields end
mutable struct ReducedACRPowerModel <: _PMs.AbstractACRModel _PMs.@pm_fields end

AbstractReducedModel = Union{ReducedACRPowerModel, ReducedACPPowerModel}

"Shunt elements are removed in the reduced model"
function constraint_mc_load_power_balance(pm::AbstractReducedModel, i::Int; nw::Int=pm.cnw)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = _PMD.ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = _PMD.ref(pm, nw, :bus_gens, i)
    bus_storage = _PMD.ref(pm, nw, :bus_storage, i)
    bus_loads = _PMD.ref(pm, nw, :bus_loads, i)
    bus_shunts = _PMD.ref(pm, nw, :bus_shunts, i)

    constraint_mc_load_power_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)
end

function constraint_mc_load_power_balance(pm::ReducedACPPowerModel, nw::Int, i::Int, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)

    p    = get(_PMD.var(pm, nw),   :p, Dict()); _PMs._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(_PMD.var(pm, nw),   :q, Dict()); _PMs._check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(_PMD.var(pm, nw),  :pg_bus, Dict()); _PMs._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(_PMD.var(pm, nw),  :qg_bus, Dict()); _PMs._check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(_PMD.var(pm, nw),  :ps, Dict()); _PMs._check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(_PMD.var(pm, nw),  :qs, Dict()); _PMs._check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(_PMD.var(pm, nw), :psw, Dict()); _PMs._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(_PMD.var(pm, nw), :qsw, Dict()); _PMs._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    pt   = get(_PMD.var(pm, nw),  :pt, Dict()); _PMs._check_var_keys(pt, bus_arcs_trans, "active power", "transformer")
    qt   = get(_PMD.var(pm, nw),  :qt, Dict()); _PMs._check_var_keys(qt, bus_arcs_trans, "reactive power", "transformer")
    pd   = get(_PMD.var(pm, nw),  :pd_bus, Dict()); _PMs._check_var_keys(pd, bus_loads, "active power", "load")
    qd   = get(_PMD.var(pm, nw),  :qd_bus, Dict()); _PMs._check_var_keys(pd, bus_loads, "reactive power", "load")

    cstr_p = []
    cstr_q = []

    for c in _PMs.conductor_ids(pm; nw=nw)
        cp = JuMP.@constraint(pm.model, #NB: <-- removing the shunt makes this @constraint instead of @NLconstraint
            sum(p[a][c] for a in bus_arcs)
            + sum(psw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(pt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(pg[g][c] for g in bus_gens)
            - sum(ps[s][c] for s in bus_storage)
            - sum(pd[l][c] for l in bus_loads)
            )
        push!(cstr_p, cp)

        cq = JuMP.@constraint(pm.model, #NB: <-- removing the shunt makes this @constraint instead of @NLconstraint
            sum(q[a][c] for a in bus_arcs)
            + sum(qsw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(qt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(qg[g][c] for g in bus_gens)
            - sum(qs[s][c] for s in bus_storage)
            - sum(qd[l][c] for l in bus_loads)
            )
        push!(cstr_q, cq)
    end

    if InfrastructureModels.report_duals(pm)
        _PMD.sol(pm, nw, :bus, i)[:lam_kcl_r] = cstr_p
        _PMD.sol(pm, nw, :bus, i)[:lam_kcl_i] = cstr_q
    end
end

function constraint_mc_load_power_balance(pm::ReducedACRPowerModel, nw::Int, i::Int, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)

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
    pd   = get(_PMD.var(pm, nw),  :pd_bus, Dict()); _PMs._check_var_keys(pd, bus_loads, "active power", "load")
    qd   = get(_PMD.var(pm, nw),  :qd_bus, Dict()); _PMs._check_var_keys(pd, bus_loads, "reactive power", "load")

    cstr_p = []
    cstr_q = []

    # pd/qd can be NLexpressions, so cannot be vectorized
    for c in _PMs.conductor_ids(pm; nw=nw)
        cp = JuMP.@constraint(pm.model,
            sum(p[a][c] for a in bus_arcs)
            + sum(psw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(pt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(pg[g][c] for g in bus_gens)
            - sum(ps[s][c] for s in bus_storage)
            - sum(pd[l][c] for l in bus_loads)
        )
        push!(cstr_p, cp)

        cq = JuMP.@constraint(pm.model,
            sum(q[a][c] for a in bus_arcs)
            + sum(qsw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(qt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(qg[g][c] for g in bus_gens)
            - sum(qs[s][c] for s in bus_storage)
            - sum(qd[l][c] for l in bus_loads)
        )
        push!(cstr_q, cq)
    end

    if InfrastructureModels.report_duals(pm)
        _PMD.sol(pm, nw, :bus, i)[:lam_kcl_r] = cstr_p
        _PMD.sol(pm, nw, :bus, i)[:lam_kcl_i] = cstr_q
    end
end
