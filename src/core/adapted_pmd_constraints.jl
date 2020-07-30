@enum ConnConfig WYE DELTA

function constraint_mc_gen_setpoint_se(pm::_PMs.IVRPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true, bounded::Bool=true)
    generator = _PMD.ref(pm, nw, :gen, id)
    bus =  _PMD.ref(pm, nw,:bus, generator["gen_bus"])

    N = 3
    pmin = get(generator, "pmin", fill(-Inf, N))
    pmax = get(generator, "pmax", fill( Inf, N))
    qmin = get(generator, "qmin", fill(-Inf, N))
    qmax = get(generator, "qmax", fill( Inf, N))
    #NB: we are now defaulting to wye!!


    #if String(get(generator, "configuration", WYE)) == "WYE"
    #    display("generator is wye")
        constraint_mc_gen_setpoint_wye_se(pm, nw, id, bus["index"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    #else
    #    display("generator is delta")
    #    constraint_mc_gen_setpoint_delta_se(pm, nw, id, bus["index"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    #end
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
    # if bounded
    #     JuMP.@NLconstraint(pm.model, [i in 1:nph], pmin[i] <= pg[i])
    #     JuMP.@NLconstraint(pm.model, [i in 1:nph], pmax[i] >= pg[i])
    #     JuMP.@NLconstraint(pm.model, [i in 1:nph], qmin[i] <= qg[i])
    #     JuMP.@NLconstraint(pm.model, [i in 1:nph], qmax[i] >= qg[i])
    # end
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

    #if conn==WYE
        constraint_mc_load_setpoint_wye_se(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    #else
#        constraint_mc_load_setpoint_delta_se(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
#    end
end

function constraint_mc_load_setpoint_wye_se(pm::_PMs.IVRPowerModel, nw::Int, id::Int, bus_id::Int, a::Vector{<:Real}, alpha::Vector{<:Real}, b::Vector{<:Real}, beta::Vector{<:Real}; report::Bool=true)
    vr = _PMD.var(pm, nw, :vr, bus_id)
    vi = _PMD.var(pm, nw, :vi, bus_id)
    crd = _PMD.var(pm, nw, :crd_bus, id)
    cid = _PMD.var(pm, nw, :cid_bus, id)

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
    # vr = _PMD.var(pm, nw, :vr, bus_id)
    # vi = _PMD.var(pm, nw, :vi, bus_id)
    #
    # nph = 3
    # prev = Dict(i=>(i+nph-2)%nph+1 for i in 1:nph)
    # next = Dict(i=>i%nph+1 for i in 1:nph)
    #
    # vrd = JuMP.@NLexpression(pm.model, [i in 1:nph], vr[i]-vr[next[i]])
    # vid = JuMP.@NLexpression(pm.model, [i in 1:nph], vi[i]-vi[next[i]])
    #
    # crd = JuMP.@NLexpression(pm.model, [i in 1:nph],
    #     a[i]*vrd[i]*(vrd[i]^2+vid[i]^2)^(alpha[i]/2-1)
    #    +b[i]*vid[i]*(vrd[i]^2+vid[i]^2)^(beta[i]/2 -1)
    # )
    # cid = JuMP.@NLexpression(pm.model, [i in 1:nph],
    #     a[i]*vid[i]*(vrd[i]^2+vid[i]^2)^(alpha[i]/2-1)
    #    -b[i]*vrd[i]*(vrd[i]^2+vid[i]^2)^(beta[i]/2 -1)
    # )
    #
    # crd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], crd[i]-crd[prev[i]])
    # cid_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], cid[i]-cid[prev[i]])
    #
    # _PMD.var(pm, nw, :crd_bus)[id] = crd_bus
    # _PMD.var(pm, nw, :cid_bus)[id] = cid_bus
    #
    # if report
    #     pd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph],  vr[i]*crd_bus[i]+vi[i]*cid_bus[i])
    #     qd_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], -vr[i]*cid_bus[i]+vi[i]*crd_bus[i])
    #
    #     sol(pm, nw, :load, id)[:pd_bus] = pd_bus
    #     sol(pm, nw, :load, id)[:qd_bus] = qd_bus
    #
    #     pd = JuMP.@NLexpression(pm.model, [i in 1:nph], a[i]*(vrd[i]^2+vid[i]^2)^(alpha[i]/2) )
    #     qd = JuMP.@NLexpression(pm.model, [i in 1:nph], b[i]*(vrd[i]^2+vid[i]^2)^(beta[i]/2)  )
    #     sol(pm, nw, :load, id)[:pd] = pd
    #     sol(pm, nw, :load, id)[:qd] = qd
    # end
end
