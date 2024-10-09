"""
Creates auxiliary variables for line-to-line voltages.
These are currently not present by default in PowerModelsDistributionStateEstimation (v0.6.x)
"""
function variable_line_to_line_voltage_magnitude(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=_PMD.nw_id_default, bounded::Bool=true)
    
    bus_with_vll_meas = [meas["cmp_id"] for (i, meas) in _PMD.ref(pm, nw, :meas) if meas["var"] == :vll]

    terminals = Dict(i => bus["terminals"] for (i,bus) in _PMD.ref(pm, nw, :bus))
    vll = _PMD.var(pm, nw)[:vll] = Dict(i => JuMP.@variable(pm.model,
            [t in terminals[i]], base_name="$(nw)_vll_$(i)"
        ) for i in _PMD.ids(pm, nw, :bus) if i ∈ bus_with_vll_meas
    )

    if bounded
        for (i,bus) in _PMD.ref(pm, nw, :bus) 
            if i ∈ bus_with_vll_meas
                for (idx, t) in enumerate(terminals[i])
                    if haskey(bus, "vmin")
                        JuMP.set_lower_bound(vd[i][t], bus["vmin"][idx])
                    end
                    if haskey(bus, "vmax")
                        JuMP.set_upper_bound(vd[i][t], bus["vmax"][idx])
                    end
                end
            end
        end
    end
end
"""
Allows to incorporate line-to-line voltage magnitude measurements into the ACR and IVR formulations, by mapping them
to phase voltage variables
"""
function constraint_line_to_line_voltage(pm::Union{_PMD.AbstractUnbalancedACRModel, _PMD.AbstractUnbalancedIVRModel}, i::Int; nw::Int=_PMD.nw_id_default)
    
    terminals = _PMD.ref(pm, nw, :bus, i)["terminals"]
    vll = _PMD.var(pm,nw,:vll,i)
    vr = _PMD.var(pm,nw,:vr,i)
    vi = _PMD.var(pm,nw,:vi,i)

    for c in terminals
        if c == 1 
            d1 = 2
            d2 = 1
        elseif c == 2  
            d1 = 2
            d2 = 3
        else
            d1 = 1
            d2 = 3
        end
        JuMP.@constraint(pm.model,
            vll[c]^2 == vr[d1]^2+vr[d2]^2-2*vr[d2]*vr[d1]+vi[d1]^2+vi[d2]^2-2*vi[d2]*vi[d1]
        )
    end

end
"""
Replaces old namesake function
"""
function get_active_connections(pm::_PMD.AbstractUnbalancedPowerModel, nw::Int, cmp_type::Symbol, cmp_id::Int)
    if cmp_type == :bus
        if haskey(_PMD.ref(pm, nw, :bus, cmp_id), "orig_term")
           active_conn = _PMD.ref(pm, nw, :bus, cmp_id)["orig_term"]
        else
            active_conn = _PMD.ref(pm, nw, :bus, cmp_id)["terminals"]
        end
   elseif cmp_type ∈ [:gen, :load]
       active_conn = _PMD.ref(pm, nw, cmp_type, cmp_id)["connections"]
   elseif cmp_type == :branch
       active_conn = intersect(_PMD.ref(pm, nw, :branch, cmp_id)["f_connections"], _PMD.ref(pm, nw, :branch, cmp_id)["t_connections"])
   else
       error("Measurements for component of type $cmp_type are not supported")
   end
   return active_conn
end