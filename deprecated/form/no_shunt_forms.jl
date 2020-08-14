mutable struct ReducedACPModel <: _PMs.AbstractACPModel _PMs.@pm_fields end
mutable struct ReducedACRModel <: _PMs.AbstractACRModel _PMs.@pm_fields end
mutable struct ReducedIVRModel <: _PMs.AbstractIVRModel _PMs.@pm_fields end

AbstractReducedModel = Union{ReducedACRModel, ReducedACPModel}

# function variable_mc_bus_voltage(pm::ReducedACRModel; nw=pm.cnw, bounded::Bool=true, kwargs...)
#     _PMD.variable_mc_bus_voltage(_PMs.ACRModel; nw=nw, bounded=bounded)
# end

# "If model is not reduced, it's delegated back to PMD"
# function constraint_mc_load_power_balance(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
#     _PMD.constraint_mc_load_power_balance(pm, i; nw=nw)
# end

"Shunt elements are removed in the reduced model"
function constraint_mc_load_power_balance(pm::AbstractReducedModel, i::Int; nw::Int=pm.cnw)

    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_storage = ref(pm, nw, :bus_storage, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    if !haskey(con(pm, nw), :lam_kcl_r)
        con(pm, nw)[:lam_kcl_r] = Dict{Int,Array{JuMP.ConstraintRef}}()
    end

    if !haskey(con(pm, nw), :lam_kcl_i)
        con(pm, nw)[:lam_kcl_i] = Dict{Int,Array{JuMP.ConstraintRef}}()
    end

    constraint_mc_load_power_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)
end

function constraint_mc_load_power_balance(pm::ReducedACPModel, nw::Int, i::Int, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)
    p    = get(var(pm, nw),   :p, Dict()); _PMs._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, nw),   :q, Dict()); _PMs._check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, nw),  :pg_bus, Dict()); _PMs._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, nw),  :qg_bus, Dict()); _PMs._check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, nw),  :ps, Dict()); _PMs._check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, nw),  :qs, Dict()); _PMs._check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, nw), :psw, Dict()); _PMs._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, nw), :qsw, Dict()); _PMs._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    pt   = get(var(pm, nw),  :pt, Dict()); _PMs._check_var_keys(pt, bus_arcs_trans, "active power", "transformer")
    qt   = get(var(pm, nw),  :qt, Dict()); _PMs._check_var_keys(qt, bus_arcs_trans, "reactive power", "transformer")
    pd   = get(var(pm, nw),  :pd_bus, Dict()); _PMs._check_var_keys(pd, bus_loads, "active power", "load")
    qd   = get(var(pm, nw),  :qd_bus, Dict()); _PMs._check_var_keys(pd, bus_loads, "reactive power", "load")

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

    con(pm, nw, :lam_kcl_r)[i] = isa(cstr_p, Array) ? cstr_p : [cstr_p]
    con(pm, nw, :lam_kcl_i)[i] = isa(cstr_q, Array) ? cstr_q : [cstr_q]

    if InfrastructureModels.report_duals(pm)
        _PMD.sol(pm, nw, :bus, i)[:lam_kcl_r] = cstr_p
        _PMD.sol(pm, nw, :bus, i)[:lam_kcl_i] = cstr_q
    end
end

function constraint_mc_load_power_balance(pm::ReducedACRModel, nw::Int, i::Int, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)

    p    = get(var(pm, nw),    :p, Dict()); _PMs._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, nw),    :q, Dict()); _PMs._check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, nw),   :pg_bus, Dict()); _PMs._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, nw),   :qg_bus, Dict()); _PMs._check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, nw),   :ps, Dict()); _PMs._check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, nw),   :qs, Dict()); _PMs._check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, nw),  :psw, Dict()); _PMs._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, nw),  :qsw, Dict()); _PMs._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    pt   = get(var(pm, nw),   :pt, Dict()); _PMs._check_var_keys(pt, bus_arcs_trans, "active power", "transformer")
    qt   = get(var(pm, nw),   :qt, Dict()); _PMs._check_var_keys(qt, bus_arcs_trans, "reactive power", "transformer")
    pd   = get(var(pm, nw),  :pd_bus, Dict()); _PMs._check_var_keys(pd, bus_loads, "active power", "load")
    qd   = get(var(pm, nw),  :qd_bus, Dict()); _PMs._check_var_keys(pd, bus_loads, "reactive power", "load")

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

    con(pm, nw, :lam_kcl_r)[i] = isa(cstr_p, Array) ? cstr_p : [cstr_p]
    con(pm, nw, :lam_kcl_i)[i] = isa(cstr_q, Array) ? cstr_q : [cstr_q]

    if InfrastructureModels.report_duals(pm)
        _PMD.sol(pm, nw, :bus, i)[:lam_kcl_r] = cstr_p
        _PMD.sol(pm, nw, :bus, i)[:lam_kcl_i] = cstr_q
    end
end

"If model is not reduced, it's delegated back to PMD: both series and total current vars are defined"
function variable_mc_branch_current(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    _PMD.variable_mc_branch_current(pm, i; nw=nw, bounded=bounded, report=report)
end

"No series current vars defined"
function variable_mc_branch_current(pm::ReducedIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

function constraint_mc_load_current_balance_se(pm::ReducedIVRModel, i::Int; nw::Int=pm.cnw)
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

function constraint_mc_load_current_balance_se(pm::ReducedIVRModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads)

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

function constraint_mc_current_from(pm::_PMs.AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    _PMD.constraint_mc_current_from(pm, i; nw=nw)
end

function constraint_mc_current_from(pm::ReducedIVRModel, i::Int; nw::Int=pm.cnw)
    #NB do nothing?
end

function constraint_mc_current_to(pm::_PMs.AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    _PMD.constraint_mc_current_to(pm, i; nw=nw)
end

function constraint_mc_current_to(pm::ReducedIVRModel, i::Int; nw::Int=pm.cnw)
    #NB do nothing?
end

function constraint_mc_bus_voltage_drop(pm::_PMs.AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    _PMD.constraint_mc_bus_voltage_drop(pm, i; nw=nw)
end

function constraint_mc_bus_voltage_drop(pm::ReducedIVRModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    tr, ti = _PM.calc_branch_t(branch)
    r = branch["br_r"]
    x = branch["br_x"]
    tm = branch["tap"]

    constraint_mc_bus_voltage_drop(pm, nw, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)
end

function constraint_mc_bus_voltage_drop(pm::ReducedIVRModel, n::Int, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)
    vr_fr = var(pm, n, :vr, f_bus)
    vi_fr = var(pm, n, :vi, f_bus)

    vr_to = var(pm, n, :vr, t_bus)
    vi_to = var(pm, n, :vi, t_bus)

    cr_fr =  var(pm, n, :cr, f_idx[1])
    ci_fr =  var(pm, n, :ci, f_idx[1])

    r = r
    x = x

    JuMP.@constraint(pm.model, vr_to .== (vr_fr.*tr + vi_fr.*ti)./tm.^2 - r*cr_fr + x*ci_fr)
    JuMP.@constraint(pm.model, vi_to .== (vi_fr.*tr - vr_fr.*ti)./tm.^2 - r*ci_fr - x*cr_fr)
end
