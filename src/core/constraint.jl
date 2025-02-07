################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
"""
    constraint_mc_residual

Equality constraint that describes the residual definition, which depends on the
criterion assigned to each individual measurement in data["meas"]["m"]["crit"].
"""
function constraint_mc_residual(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=_IM.nw_id_default)

    cmp_id = get_cmp_id(pm, nw, i)
    res = _PMD.var(pm, nw, :res, i)
    var = _PMD.var(pm, nw, _PMD.ref(pm, nw, :meas, i, "var"), cmp_id)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :se_settings)["rescaler"]
    crit = _PMD.ref(pm, nw, :meas, i, "crit")
    meas_var = _PMD.ref(pm, nw, :meas, i, "var")
    conns = get_active_connections(pm, nw, _PMD.ref(pm, nw, :meas, i, "cmp"), cmp_id, meas_var)
    for (idx, c) in enumerate(setdiff(conns,[_N_IDX]))
        if (occursin("ls", crit) || occursin("lav", crit)) && isa(dst[idx], _DST.Normal)
            μ, σ = occursin("w", crit) ? (_DST.mean(dst[idx]), _DST.std(dst[idx])) : (_DST.mean(dst[idx]), 1.0)
        end
        if isa(dst[idx], Float64)
            JuMP.@constraint(pm.model, var[c] == dst[idx])
            JuMP.@constraint(pm.model, res[idx] == 0.0)         
        elseif crit ∈ ["wls", "ls"] && isa(dst[idx], _DST.Normal)
            JuMP.@constraint(pm.model,
                res[idx] * rsc^2 * σ^2 == (var[c] - μ)^2 
            )
        elseif crit == "rwls" && isa(dst[idx], _DST.Normal)
            JuMP.@constraint(pm.model,
                res[idx] * rsc^2 * σ^2 >= (var[c] - μ)^2
            )
        elseif crit ∈ ["wlav", "lav"] && isa(dst[idx], _DST.Normal)
            JuMP.@constraint(pm.model,
                res[idx] * rsc * σ == abs(var[c] - μ)
            )
        elseif crit == "rwlav" && isa(dst[idx], _DST.Normal)
            JuMP.@constraint(pm.model,
                res[idx] * rsc * σ >= (var[c] - μ) 
            )
            JuMP.@constraint(pm.model,
                res[idx] * rsc * σ >= - (var[c] - μ)
            )
        elseif crit == "mle"
            #TODO: enforce min and max in the meas dictionary and just with haskey make it optional for extendedbeta
            pkg_id = any([ dst[idx] isa d for d in [ExtendedBeta{Float64}, _Poly.Polynomial]]) ? _PMDSE : _DST
            lb = ( !isa(dst[idx], _DST.MixtureModel) && !isinf(pkg_id.minimum(dst[idx])) ) ? pkg_id.minimum(dst[idx]) : -10
            ub = ( !isa(dst[idx], _DST.MixtureModel) && !isinf(pkg_id.maximum(dst[idx])) ) ? pkg_id.maximum(dst[idx]) : 10
            if any([ dst[idx] isa d for d in [_DST.MixtureModel, _Poly.Polynomial]]) lb = _PMD.ref(pm, nw, :meas, i, "min") end
            if any([ dst[idx] isa d for d in [_DST.MixtureModel, _Poly.Polynomial]]) ub = _PMD.ref(pm, nw, :meas, i, "max") end
            
            shf = abs(Optim.optimize(x -> -pkg_id.logpdf(dst[idx],x),lb,ub).minimum)
            f = Symbol("df_",i,"_",c)

            fun(x) = rsc * ( - shf + pkg_id.logpdf(dst[idx],x) )
            grd(x) = pkg_id.gradlogpdf(dst[idx],x)
            hes(x) = heslogpdf(dst[idx],x)
            JuMP.register(pm.model, f, 1, fun, grd, hes)
            JuMP.add_nonlinear_constraint(pm.model, :($(res[idx]) == - $(f)($(var[c]))))
        else
            error("SE criterion of measurement $(i) not recognized")
        end
    end
end

# Constraints related to the ANGULAR REFERENCE MODELS
########################################################
## ACP
function variable_mc_bus_voltage(pm::_PMD.AbstractUnbalancedPowerModel; bounded = true)
    _PMD.variable_mc_bus_voltage_magnitude_only(pm; bounded = true)
    _PMDSE.variable_mc_bus_voltage_angle(pm; bounded = true)
end


"""
    variable_mc_bus_voltage_angle(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=_PMD.nw_id_default, bounded::Bool=true, report::Bool=true)

Defines the bus voltage angle variables for a multi-conductor unbalanced power model.

# Arguments
- `pm::AbstractUnbalancedPowerModel`: The power model instance.
- `nw::Int`: The network identifier (default is `_PMD.nw_id_default`).
- `bounded::Bool`: If `true`, applies bounds to the voltage angle variables based on the bus data (default is `true`).
- `report::Bool`: If `true`, reports the solution component values (default is `true`).

# Description
This function initializes the bus voltage angle variables for each bus in the power model. It sets the starting values for the voltage angles based on default values or specified start values in the bus data. If `bounded` is `true`, it applies lower and upper bounds to the voltage angle variables based on the `vamin` and `vamax` fields in the bus data. If `report` is `true`, it reports the solution component values for the voltage angles.

# Notes
- The starting values for the voltage angles are converted from degrees to radians.
"""
function variable_mc_bus_voltage_angle(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=_PMD.nw_id_default, bounded::Bool=true, report::Bool=true)
    terminals = Dict(i => bus["terminals"] for (i,bus) in _PMD.ref(pm, nw, :bus))
    va_start_defaults = Dict(i => deg2rad.([0.0, -120.0, 120.0, fill(0.0, length(terms))...][terms]) for (i, terms) in terminals)
    va = _PMD.var(pm, nw)[:va] = Dict(i => JuMP.@variable(pm.model,
            [t in terminals[i]], base_name="$(nw)_va_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :bus, i), ["va_start", "va"], t, va_start_defaults[i][findfirst(isequal(t), terminals[i])]),
            
        ) for i in _PMD.ids(pm, nw, :bus)
    )

    if bounded
        for (i,bus) in _PMD.ref(pm, nw, :bus)
            for (idx, t) in enumerate(terminals[i])
                if haskey(bus, "vamin")
                    _PMD.set_lower_bound(va[i][t], bus["vamin"][idx])
                    @warn " va min bounds defined "
                end
                if haskey(bus, "vamax")
                    _PMD.set_upper_bound(va[i][t], bus["vamax"][idx])
                    @warn " va max bounds defined "
                end
            end
        end
    end

    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :bus, :va, _PMD.ids(pm, nw, :bus), va)
end

## ACR

""
function variable_mc_bus_voltage(pm::_PMD.AbstractUnbalancedACRModel; nw::Int=_PMD.nw_id_default, bounded::Bool=true, report::Bool=true)
    variable_mc_bus_voltage_real(pm; nw=nw, bounded=bounded, report=report)
    variable_mc_bus_voltage_imaginary(pm; nw=nw, bounded=bounded, report=report)

    # local infeasbility issues without proper initialization;
    # convergence issues start when the equivalent angles of the starting point
    # are further away than 90 degrees from the solution (as given by ACP)
    # this is the default behaviour of _PM, initialize all phases as (1,0)
    # the magnitude seems to have little effect on the convergence (>0.05)
    # updating the starting point to a balanced phasor does the job
    for id in _PMD.ids(pm, nw, :bus)
        busref = _PMD.ref(pm, nw, :bus, id)
        terminals = busref["terminals"]
        grounded = busref["grounded"]

        ncnd = length(terminals)

        if haskey(busref, "vr_start") && haskey(busref, "vi_start")
            vr = busref["vr_start"]
            vi = busref["vi_start"]
        else
            vm_start = fill(1.0, 3)
            for t in 1:3
                if t in terminals
                    vmax = busref["vmax"][findfirst(isequal(t), terminals)]
                    vm_start[t] = min(vm_start[t], vmax)

                    vmin = busref["vmin"][findfirst(isequal(t), terminals)]
                    vm_start[t] = max(vm_start[t], vmin)
                end
            end

            vm = haskey(busref, "vm_start") ? busref["vm_start"] : haskey(busref, "vm") ? busref["vm"] : [vm_start..., fill(0.0, ncnd)...][terminals]
            va = haskey(busref, "va_start") ? busref["va_start"] : haskey(busref, "va") ? busref["va"] : [deg2rad.([0, -120, 120])..., zeros(length(terminals))...][terminals]

            vr = vm .* cos.(va)
            vi = vm .* sin.(va)
        end

        for (idx,t) in enumerate(terminals)
            JuMP.set_start_value(_PMD.var(pm, nw, :vr, id)[t], vr[idx])
            JuMP.set_start_value(_PMD.var(pm, nw, :vi, id)[t], vi[idx])
        end
    end

    # apply bounds if bounded
    if bounded
        for i in _PMD.ids(pm, nw, :bus)
            _PMD.constraint_mc_voltage_magnitude_bounds(pm, i; nw=nw)
            constraint_mc_voltage_angle_bounds(pm, i; nw=nw)
        end
    end
end


""
function variable_mc_bus_voltage_real(pm::_PMD.AbstractUnbalancedACRModel; nw::Int=_PMD.nw_id_default, bounded::Bool=true, report::Bool=true)
    terminals = Dict(i => bus["terminals"] for (i, bus) in _PMD.ref(pm, nw, :bus))

    vr = _PMD.var(pm, nw)[:vr] = Dict(i => JuMP.@variable(pm.model,
            [t in terminals[i]], base_name="$(nw)_vr_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :bus, i), "vr_start", t, 1.0)
        ) for i in _PMD.ids(pm, nw, :bus)
    )
    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :bus, :vr, _PMD.ids(pm, nw, :bus), vr)
end


""
function variable_mc_bus_voltage_imaginary(pm::_PMD.AbstractUnbalancedACRModel; nw::Int=_PMD.nw_id_default, bounded::Bool=true, report::Bool=true)
    terminals = Dict(i => bus["terminals"] for (i,bus) in _PMD.ref(pm, nw, :bus))
    vi = _PMD.var(pm, nw)[:vi] = Dict(i => JuMP.@variable(pm.model,
    [t in terminals[i]], base_name="$(nw)_vi_$(i)",
    start = _PMD.comp_start_value(_PMD.ref(pm, nw, :bus, i), "vi_start", t, 0.0)
    ) for i in _PMD.ids(pm, nw, :bus)
    )
    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :bus, :vi, _PMD.ids(pm, nw, :bus), vi)
end

function constraint_mc_voltage_angle_bounds(pm::_PMD.AbstractUnbalancedACRModel, i::Int; nw::Int=_PMD.nw_id_default)::Nothing
    bus = _PMD.ref(pm, nw, :bus, i)
    terminals = length(bus["terminals"])
    if haskey(bus, "vamin") && haskey(bus, "vamax")    
        va = haskey(bus, "va_start") ? bus["va_start"] : haskey(bus, "va") ? bus["va"] : [deg2rad.([0, -120, 120])..., zeros(length(terminals))...][terminals]
        vamin = _PMD.get(bus, "vamin", fill(0.0, length(bus["terminals"])))
        vamax = _PMD.get(bus, "vamax", fill(Inf, length(bus["terminals"])))
        constraint_mc_voltage_angle_bounds(pm, nw, i, vamin, vamax)
    end
    nothing
end

"`vamin <= va[i] <= vamax`"
function constraint_mc_voltage_angle_bounds(pm::_PMD.AbstractUnbalancedACRModel, nw::Int, i::Int, vamin::Vector{<:Real}, vamax::Vector{<:Real})
    @assert all(vamin .<= vamax)
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    for (idx,t) in enumerate(_PMD.ref(pm, nw, :bus, i)["terminals"])
        if vamin[idx] > -Inf
            JuMP.@constraint(pm.model, tan(vamin[idx]) <= vi[t]/vr[t])
            @warn "consrtained minimum angle vamin at $(vamin[idx]) for bus $i to be less than $(atan(vi[t],vr[t]))" 
        end

        if vamax[idx] < Inf
            JuMP.@constraint(pm.model, tan(vamax[idx]) >= vi[t]/vr[t])
            @warn "consrtained maximum angle vamax at $(vamax[idx]) for bus $i to be greater than $(atan(vi[t],vr[t]))"
        end

    end
end

# Explicit Neutral related Constraints
########################################################

function constraint_mc_generator_power_se(pm::_PMD.IVRENPowerModel, id::Int; nw::Int=_IM.nw_id_default, report::Bool=true, bounded::Bool=true)
    generator = _PMD.ref(pm, nw, :gen, id)
    bus =  _PMD.ref(pm, nw,:bus, generator["gen_bus"])

    N = length(generator["connections"])
    pmin = get(generator, "pmin", fill(-Inf, N))
    pmax = get(generator, "pmax", fill( Inf, N))
    qmin = get(generator, "qmin", fill(-Inf, N))
    qmax = get(generator, "qmax", fill( Inf, N))

    if get(generator, "configuration", WYE) == _PMD.WYE
        constraint_mc_generator_power_wye_se(pm, nw, id, bus["index"], generator["connections"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    else
        constraint_mc_generator_power_delta_se(pm, nw, id, bus["index"], generator["connections"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    end
end

"wye connected generator setpoint constraint for IVR formulation - SE adaptation"
function constraint_mc_generator_power_wye_se(pm::_PMD.IVRENPowerModel, nw::Int, id::Int, bus_id::Int, connections::Vector{Int}, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
    vr =  _PMD.var(pm, nw, :vr, bus_id)
    vi =  _PMD.var(pm, nw, :vi, bus_id)
    crg =  _PMD.var(pm, nw, :crg, id)
    cig =  _PMD.var(pm, nw, :cig, id)

    if bounded
        for (idx, c) in enumerate(connections[1:end-1])
            if pmin[c]> -Inf
                JuMP.@constraint(pm.model, pmin[idx] .<= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if pmax[c]< Inf
                JuMP.@constraint(pm.model, pmax[idx] .>= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if qmin[c]>-Inf
                JuMP.@constraint(pm.model, qmin[idx] .<= vi[c]*crg[c]  - vr[c]*cig[c])
            end
            if qmax[c]< Inf
                JuMP.@constraint(pm.model, qmax[idx] .>= vi[c]*crg[c]  - vr[c]*cig[c])
            end
        end
    end
end

function constraint_mc_current_balance_se(pm::_PMD.IVRENPowerModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_loads::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    #NB only difference with pmd is crd_bus replaced by crd, and same with cid
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMD._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMD._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, nw),   :crd, Dict()); _PMD._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, nw),   :cid, Dict()); _PMD._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, nw),   :crg, Dict()); _PMD._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig, Dict()); _PMD._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(_PMD.var(pm, nw),   :crs, Dict()); _PMD._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(_PMD.var(pm, nw),   :cis, Dict()); _PMD._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(_PMD.var(pm, nw),  :crsw, Dict()); _PMD._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMD.var(pm, nw),  :cisw, Dict()); _PMD._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMD._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMD._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    Gs, Bs = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]
    
    for (idx, t) in ungrounded_terminals      
        JuMP.@constraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(crsw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(crs[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum(crd[d][t]         for (d, conns) in bus_loads if t in conns)
                                    - sum( Gs[idx,jdx]*vr[u] -Bs[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    )
        JuMP.@constraint(pm.model, sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(cisw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(cis[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum(cid[d][t]         for (d, conns) in bus_loads if t in conns)
                                    - sum( Gs[idx,jdx]*vi[u] +Bs[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    )
    end
end
