""
function constraint_mc_power_balance_se(pm::_PMs.AbstractACPModel, nw::Int, i::Int, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gs, bus_bs)
    vm   = _PMs.var(pm, nw, :vm, i)
    pi   = _PMs.var(pm, nw, :pi, i)
    qi   = _PMs.var(pm, nw, :qi, i)
    p    = get(_PMs.var(pm, nw),   :p, Dict()); _PMs._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(_PMs.var(pm, nw),   :q, Dict()); _PMs._check_var_keys(q, bus_arcs, "reactive power", "branch")
    psw  = get(_PMs.var(pm, nw), :psw, Dict()); _PMs._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(_PMs.var(pm, nw), :qsw, Dict()); _PMs._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    pt   = get(_PMs.var(pm, nw),  :pt, Dict()); _PMs._check_var_keys(pt, bus_arcs_trans, "active power", "transformer")
    qt   = get(_PMs.var(pm, nw),  :qt, Dict()); _PMs._check_var_keys(qt, bus_arcs_trans, "reactive power", "transformer")

    cstr_p = []
    cstr_q = []

    for c in _PMs.conductor_ids(pm; nw=nw)
        cp = JuMP.@constraint(pm.model,
            sum(p[a][c] for a in bus_arcs)
            + sum(psw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(pt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            pi[c]
            - sum(gs[c] for gs in values(bus_gs))*vm[c]^2
        )
        push!(cstr_p, cp)

        cq = JuMP.@constraint(pm.model,
            sum(q[a][c] for a in bus_arcs)
            + sum(qsw[a_sw][c] for a_sw in bus_arcs_sw)
            + sum(qt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            qi[c]
            + sum(bs[c] for bs in values(bus_bs))*vm[c]^2
        )
        push!(cstr_q, cq)
    end

    if _PMs.report_duals(pm)
        _PMs.sol(pm, nw, :bus, i)[:lam_kcl_r] = cstr_p
        _PMs.sol(pm, nw, :bus, i)[:lam_kcl_i] = cstr_q
    end
end


""
function constraint_mc_residual(pm::_PMs.AbstractACPModel, nw:: Int, i::Int)
    bus_loads = _PMs.ref(pm, nw, :bus_loads, i)
    bus_gens  = _PMs.ref(pm, nw, :bus_gens, i)

    bus_pd = Dict(k => _PMs.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => _PMs.ref(pm, nw, :load, k, "qd") for k in bus_loads)
    bus_pg = Dict(k => _PMs.ref(pm, nw, :gen, k, "pg") for k in bus_gens)
    bus_qg = Dict(k => _PMs.ref(pm, nw, :gen, k, "qg") for k in bus_gens)

    constraint_mc_residual_overall(pm, nw, i)
    constraint_mc_residual_active_power(pm, nw, i, bus_pd, bus_pg)
    constraint_mc_residual_reactive_power(pm, nw, i, bus_qd, bus_qg)
    constraint_mc_residual_voltage_magnitude(pm, nw, i)
end


""
function constraint_mc_residual_overall(pm::_PMs.AbstractACPModel, nw::Int, i::Int)
    r   = _PMs.var(pm, nw, :res, i)
    rp  = _PMs.var(pm, nw, :res_p, i)
    rq  = _PMs.var(pm, nw, :res_q, i)
    rv  = _PMs.var(pm, nw, :res_vm, i)

    cstr_r = []

    for c in _PMs.conductor_ids(pm; nw=nw)
        cr = JuMP.constraint(pm.model,
            r[c] == rp[c] + rq[c] + rv[c]
        )
        push!(cstr_r,cr)
    end
end


""
function constraint_mc_residual_active_power(pm::_PMs.AbstractACPModel, nw::Int, i::Int, bus_pd, bus_pg)
    pi   = _PMs.var(pm, nw, :pi, i)
    rp   = _PMs.var(pm, nw, :res_p, i)

    cstr_p = []
    cstr_r = []

    for c in _PMs.conductor_ids(pm; nw=nw)
        if typeof(dst_p[c]) == Nothing
            cp = JuMP.constraint(pm.model,
                pi[c] == sum(pg[c] for pg in values(bus_pg))
                       - sum(pd[c] for pd in values(bus_pd))
            )
            push!(cstr_p,cp)
            cr = JuMP.constraint(pm.model,
                rp == 0.0
            )
            push!(cstr_r,cr)
        elseif typeof(dst_p[c]) == Normal{Float64}
                cr = JuMP.constraint(pm.model,
                    rp == (pi[c]-_DST.mean(dst_p[c]))^2/_DST.var(dst_p[c])
                )
            push!(cstr_r,cr)
        else
            @warn "Currently, only Gaussian distributions are supported."
        end
    end
end


""
function constraint_mc_residual_reacive_power(pm::_PMs.AbstractACPModel, nw::Int, i::Int, bus_qd, bus_qg)
    qi   = _PMs.var(pm, nw, :qi, i)
    rq   = _PMs.var(pm, nw, :res_q, i)

    cstr_q = []
    cstr_r = []

    for c in _PMs.conductor_ids(pm; nw=nw)
        if typeof(dst_q[c]) == Nothing
            cq = JuMP.constraint(pm.model,
                qi[c] == sum(qg[c] for qg in values(bus_qg))
                       - sum(qd[c] for qd in values(bus_qd))
            )
            push!(cstr_q,cq)
            cr = JuMP.constraint(pm.model,
                rq[c] == 0.0
            )
            push!(cstr_r,cr)
        elseif typeof(dst_q[c]) == Normal{Float64}
            cr = JuMP.constraint(pm.model,
                rq[c] == (qi[c]-_DST.mean(dst_q[c]))^2/_DST.var(dst_q[c])
            )
            push!(cstr_r,cr)
        else
            @warn "Currently, only Gaussian distributions are supported."
        end
    end
end


""
function constraint_mc_residual_voltage_magnitude(pm::_PMs.AbstractACPModel, nw::Int, i::Int)
    vm   = _PMs.var(pm, nw, :vm, i)
    rv   = _PMs.var(pm, nw, :res_vm, i)

    cstr_r = []

    for c in _PMs.conductor_ids(pm; nw=nw)
        if typeof(dst_vm[c]) == Nothing
            cr = JuMP.constraint(pm.model,
                rv[c] == 0.0
            )
            push!(cstr_r,cr)
        elseif typeof(dst_vm[c]) == Normal{Float64}
            cr = JuMP.constraint(pm.model,
                rv[c] == (vm[c]-_DST.mean(dst_vm[c]))^2/_DST.var(dst_vm[c])
            )
            push!(cstr_r,cr)
        else
            @warn "Currently, only Gaussian distributions are supported."
        end
    end
end
