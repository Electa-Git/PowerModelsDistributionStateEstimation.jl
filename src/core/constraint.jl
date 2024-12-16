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

# ACP
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


""
function variable_mc_bus_voltage_magnitude_only(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=_PMD.nw_id_default, bounded::Bool=true, report::Bool=true)
    terminals = Dict(i => bus["terminals"] for (i,bus) in _PMD.ref(pm, nw, :bus))
    vm = _PMD.var(pm, nw)[:vm] = Dict(i => JuMP.@variable(pm.model,
            [t in terminals[i]], base_name="$(nw)_vm_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :bus, i), ["vm_start", "vm"], t, 1.0)
        ) for i in _PMD.ids(pm, nw, :bus)
    )

    if bounded
        for (i,bus) in _PMD.ref(pm, nw, :bus)
            for (idx, t) in enumerate(terminals[i])
                if haskey(bus, "vmin")
                    _PMD.set_lower_bound(vm[i][t], bus["vmin"][idx])
                end
                if haskey(bus, "vmax")
                    _PMD.set_upper_bound(vm[i][t], bus["vmax"][idx])
                end
            end
        end
        @warn " vm bounds defined "
    end

    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :bus, :vm, _PMD.ids(pm, nw, :bus), vm)
end



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
            constraint_mc_voltage_magnitude_bounds(pm, i; nw=nw)
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

    # if bounded
    #     for (i,bus) in _PMD.ref(pm, nw, :bus)
    #         if haskey(bus, "vmax")
    #             for (idx,t) in enumerate(terminals[i])
    #                 set_lower_bound(vr[i][t], -bus["vmax"][idx])
    #                 set_upper_bound(vr[i][t],  bus["vmax"][idx])
    #             end
    #         end
    #         if haskey(bus, "vamax") && haskey(bus, "vamin")
    #             for (idx,t) in enumerate(terminals[i])
    #                 va_max = bus["vamax"][idx]
    #                 va_min = bus["vamin"][idx]
    #                 vm = sqrt(vr[i][t]^2 + _PMD.var(pm, nw, :vi, i)[t]^2)
    #                 JuMP.@constraint(pm.model, cos(va_min) <= vr[i][t] / vm)
    #                 JuMP.@constraint(pm.model, vr[i][t] / vm <= cos(va_max))
    #                 @warn " vr bounds defined based on va bounds "
    #             end
    #         end
    #     end
    # end

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
    
    # if bounded
    #     for (i,bus) in _PMD.ref(pm, nw, :bus)
    #         if haskey(bus, "vmax")
    #             for (idx,t) in enumerate(terminals[i])
    #                 set_lower_bound(vi[i][t], -bus["vmax"][idx])
    #                 set_upper_bound(vi[i][t],  bus["vmax"][idx])
    #             end
    #         end
    #         if haskey(bus, "vamax") && haskey(bus, "vamin")
    #             for (idx,t) in enumerate(terminals[i])
    #                 va_max = bus["vamax"][idx]
    #                 va_min = bus["vamin"][idx]
    #                 vm = sqrt(_PMD.var(pm, nw, :vr, i)[t]^2 + vi[i][t]^2)
    #                 JuMP.@constraint(pm.model, sin(va_min) <= vi[i][t] / vm)
    #                 JuMP.@constraint(pm.model, vi[i][t] / vm <= sin(va_max))
    #                 @warn " vi bounds defined based on va bounds "
    #             end
    #         end
    #     end
    # end

    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :bus, :vi, _PMD.ids(pm, nw, :bus), vi)
end

function constraint_mc_voltage_magnitude_bounds(pm::_PMD.AbstractUnbalancedACRModel, i::Int; nw::Int=_PMD.nw_id_default)::Nothing
    bus = _PMD.ref(pm, nw, :bus, i)
    vmin = _PMD.get(bus, "vmin", fill(0.0, length(bus["terminals"])))
    vmax = _PMD.get(bus, "vmax", fill(Inf, length(bus["terminals"])))
    constraint_mc_voltage_magnitude_bounds(pm, nw, i, vmin, vmax)
    nothing
end

"`vmin <= vm[i] <= vmax`"
function constraint_mc_voltage_magnitude_bounds(pm::_PMD.AbstractUnbalancedACRModel, nw::Int, i::Int, vmin::Vector{<:Real}, vmax::Vector{<:Real})
    @assert all(vmin .<= vmax)
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)
    
    for (idx,t) in enumerate(_PMD.ref(pm, nw, :bus, i)["terminals"])
        JuMP.@constraint(pm.model, vmin[idx]^2 <= vr[t]^2 + vi[t]^2)
        if vmax[idx] < Inf
            JuMP.@constraint(pm.model, vmax[idx]^2 >= vr[t]^2 + vi[t]^2)
        end
    end
end


# Angular reference for ACR/IVR  with the `atan()` function
# function constraint_mc_voltage_angle_bounds(pm::_PMD.AbstractUnbalancedACRModel, i::Int; nw::Int=_PMD.nw_id_default)::Nothing
#     bus = _PMD.ref(pm, nw, :bus, i)
#     if haskey(bus, "vamin") && haskey(bus, "vamax")    
#         vamin = _PMD.get(bus, "vamin", fill(0.0, length(bus["terminals"])))
#         vamax = _PMD.get(bus, "vamax", fill(Inf, length(bus["terminals"])))
#         constraint_mc_voltage_angle_bounds(pm, nw, i, vamin, vamax)
#     end
#     nothing
# end

# "`vamin <= va[i] <= vamax`"
# function constraint_mc_voltage_angle_bounds(pm::_PMD.AbstractUnbalancedACRModel, nw::Int, i::Int, vamin::Vector{<:Real}, vamax::Vector{<:Real})
#     @assert all(vamin .<= vamax)
#     vr = _PMD.var(pm, nw, :vr, i)
#     vi = _PMD.var(pm, nw, :vi, i)

#     for (idx,t) in enumerate(_PMD.ref(pm, nw, :bus, i)["terminals"])

#         if vamin[idx] > -Inf
#             JuMP.@NLconstraint(pm.model, vamin[idx] <= atan(vi[t],vr[t]))
#             @warn "consrtained minimum angle vamin at $(vamin[idx]) for bus $i to be less than $(atan(vi[t],vr[t]))" 
#         end

#         if vamax[idx] < Inf
#             JuMP.@NLconstraint(pm.model, vamax[idx] >= atan(vi[t],vr[t]))
#             @warn "consrtained maximum angle vamax at $(vamax[idx]) for bus $i to be greater than $(atan(vi[t],vr[t]))"
#         end

#     end
# end


# Angular reference for ACR/IVR  without `atan()` function - by taking tan both sides
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

    # example values   
    # va = [0, -120, 120]
    # vamin = [0, -120.55, 119.0]
    # vamax = [0, -119, 121]
    # va = [0, -120, 120]
    # vamin = [0, -Inf, -Inf]
    # vamax = [0, Inf, Inf]

    # then to relate the vamin and vamax to the va to calculate the theta around which they can deactivated
    


    # θₘᵢₙ = va - vamin  
    # θₘₐₓ = vamax - va

    for (idx,t) in enumerate(_PMD.ref(pm, nw, :bus, i)["terminals"])
        if vamin[idx] > -Inf
            JuMP.@NLconstraint(pm.model, tan(vamin[idx]) <= vi[t]/vr[t])
            @warn "consrtained minimum angle vamin at $(vamin[idx]) for bus $i to be less than $(atan(vi[t],vr[t]))" 
        end

        if vamax[idx] < Inf
            JuMP.@NLconstraint(pm.model, tan(vamax[idx]) >= vi[t]/vr[t])
            @warn "consrtained maximum angle vamax at $(vamax[idx]) for bus $i to be greater than $(atan(vi[t],vr[t]))"
        end

    end
end


# Angular reference for ACR/IVR  without `atan()` function - by constraining the difference between the angles instead of bounding individual angles

# function constraint_mc_voltage_angle_bounds(pm::_PMD.AbstractUnbalancedACRModel, i::Int; nw::Int=_PMD.nw_id_default)::Nothing
#     bus = _PMD.ref(pm, nw, :bus, i)
#     terminals = length(bus["terminals"])
#     if haskey(bus, "vamin") && haskey(bus, "vamax")    
#         va = haskey(bus, "va_start") ? bus["va_start"] : haskey(bus, "va") ? bus["va"] : [deg2rad.([0, -120, 120])..., zeros(length(terminals))...][terminals]
#         vamin = _PMD.get(bus, "vamin", fill(0.0, length(bus["terminals"])))
#         vamax = _PMD.get(bus, "vamax", fill(Inf, length(bus["terminals"])))
#         constraint_mc_voltage_angle_bounds(pm, nw, i, va, vamin, vamax)
#     end
#     nothing
# end

# "`vamin <= va[i] <= vamax`"
# function constraint_mc_voltage_angle_bounds(pm::_PMD.AbstractUnbalancedACRModel, nw::Int, i::Int, va::Vector{<:Real}, vamin::Vector{<:Real}, vamax::Vector{<:Real})
#     @assert all(vamin .<= vamax)
#     vr = _PMD.var(pm, nw, :vr, i)
#     vi = _PMD.var(pm, nw, :vi, i)

#     # example values   
#     # va = [0, -120, 120]
#     # vamin = [0, -120.55, 119.0]
#     # vamax = [0, -119, 121]
#     # va = [0, -120, 120]
#     # vamin = [0, -Inf, -Inf]
#     # vamax = [0, Inf, Inf]

#     # then to relate the vamin and vamax to the va to calculate the theta around which they can deactivated
    


#     # θₘᵢₙ = va - vamin  
#     # θₘₐₓ = vamax - va

#     for (idx,t) in enumerate(_PMD.ref(pm, nw, :bus, i)["terminals"])
#         if vamin[idx] > -Inf
#             JuMP.@NLconstraint(pm.model, tan(vamin[idx]) <= vi[t]/vr[t])
#             @warn "consrtained minimum angle vamin at $(vamin[idx]) for bus $i to be less than $(atan(vi[t],vr[t]))" 
#         end

#         if vamax[idx] < Inf
#             JuMP.@NLconstraint(pm.model, tan(vamax[idx]) >= vi[t]/vr[t])
#             @warn "consrtained maximum angle vamax at $(vamax[idx]) for bus $i to be greater than $(atan(vi[t],vr[t]))"
#         end

#     end
# end
