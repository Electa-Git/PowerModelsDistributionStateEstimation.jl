""
function variable_mc_residual(  pm::_PMs.AbstractPowerModel;
                                nw::Int=pm.cnw, report::Bool=true)
    variable_mc_residual_bus(pm; kwargs...)
    variable_mc_residual_gen(pm; kwargs...)
    variable_mc_residual_load(pm; kwargs...)
    # further extensions should be added here, e.g., variable_mc_residual_branch(pm; kwargs...)
end


""
function variable_mc_residual_bus(  pm::_PMs.AbstractPowerModel;
                                    nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds) ## Might be better to look at the active conductors, i.e., when dst[nm] != nothing

    for m in metrics(pm, nw, :bus)
        sym = Symbol("res_$(m)")
        res = _PMs.var(pm, nw)[sym] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = $"$(nw)_res_$(m)_$(i)"
            ) for i in _PMs.ids(pm, nw, :bus)
        )

        report && _PMs.sol_component_value(pm, nw, :bus, sym, _PMs.ids(pm, nw, :bus), res)
    end
end


""
function variable_mc_residual_gen(  pm::_PMs.AbstractPowerModel;
                                    nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    for m in metrics(pm, nw, :gen)
        sym = Symbol("res_$(nm)")
        res = _PMs.var(pm, nw)[sym] = Dict(g => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = $"$(nw)_res_$(m)_$(g)"
            ) for g in _PMs.ids(pm, nw, :gen)
        )

        report && _PMs.sol_component_value(pm, nw, :gen, sym, _PMs.ids(pm, nw, :gen), res)
    end
end


""
function variable_mc_residual_load( pm::_PMs.AbstractPowerModel;
                                    nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    for m in metrics(pm, nw, :load)
        sym = Symbol("res_$(nm)")
        res = _PMs.var(pm, nw)[sym] = Dict(l => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = $"$(nw)_res_$(m)_$(l)"
            ) for l in _PMs.ids(pm, nw, :load)
        )

        report && _PMs.sol_component_value(pm, nw, :load, sym, _PMs.ids(pm, nw, :load), res)
    end
end
