function constraint_mc_load_setpoint_se(pm::_PMs.AbstractPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true)

    load = _PMD.ref(pm, nw, :load, id)
    bus = _PMD.ref(pm, nw,:bus, load["load_bus"])

    conn = haskey(load, "configuration") ? load["configuration"] : _PMD.WYE

    a, alpha, b, beta = _PMD._load_expmodel_params(load, bus)

    if conn==_PMD.WYE
        constraint_mc_load_setpoint_wye_se(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    else
        constraint_mc_load_setpoint_delta_se(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    end
end

function constraint_mc_load_setpoint_wye_se(pm::_PMs.AbstractIVRModel, nw::Int, id::Int, bus_id::Int, a::Vector{<:Real}, alpha::Vector{<:Real}, b::Vector{<:Real}, beta::Vector{<:Real}; report::Bool=true)
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
end


function constraint_mc_load_setpoint_delta_se(pm::_PMs.AbstractIVRModel, nw::Int, id::Int, bus_id::Int, a::Vector{<:Real}, alpha::Vector{<:Real}, b::Vector{<:Real}, beta::Vector{<:Real}; report::Bool=true)
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

        _PMD.sol(pm, nw, :load, id)[:pd_bus] = pd_bus
        _PMD.sol(pm, nw, :load, id)[:qd_bus] = qd_bus

        pd = JuMP.@NLexpression(pm.model, [i in 1:nph], a[i]*(vrd[i]^2+vid[i]^2)^(alpha[i]/2) )
        qd = JuMP.@NLexpression(pm.model, [i in 1:nph], b[i]*(vrd[i]^2+vid[i]^2)^(beta[i]/2)  )
        _PMD.sol(pm, nw, :load, id)[:pd] = pd
        _PMD.sol(pm, nw, :load, id)[:qd] = qd
    end
end
