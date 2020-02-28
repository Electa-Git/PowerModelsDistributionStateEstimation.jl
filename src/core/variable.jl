"""
    variable_mc_residual
"""
function variable_mc_residual(  pm::_PMs.AbstractPowerModel;
                                nw::Int=pm.cnw, bounded::Bool=true,
                                report::Bool=true)
    cnds = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    res = _PMs.var(pm, nw)[:res] = Dict(i => JuMP.@variable(pm.model,
        [c in 1:ncnds], base_name = "$(nw)_res_$(i)"
        ) for i in _PMs.ids(pm, nw, :meas)
    )

    if bounded
        for i in _PMs.ids(pm, nw, :meas), c in _PMs.conductor_ids(pm; nw=nw)
            JuMP.set_lower_bound(res[i][c], 0.0)
        end
    end

    report && _PMs.sol_component_value(pm, nw, :meas, :res, _PMs.ids(pm, nw, :meas), res)
end

""
function variable_mc_load(pm::_PMs.AbstractPowerModel; kwargs...)
    variable_mc_load_active(pm; kwargs...)
    variable_mc_load_reactive(pm; kwargs...)
end


function variable_mc_load_active(pm::_PMs.AbstractPowerModel;
                                 nw::Int=pm.cnw, report::Bool=true)
    cnds = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    pd = _PMs.var(pm, nw)[:pd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_pd_$(i)",
            start = _PMD.comp_start_value(_PMs.ref(pm, nw, :load, i), "pd_start", c, 0.0)
        ) for i in _PMs.ids(pm, nw, :load)
    )

    _PMs.var(pm, nw)[:pd_bus] = Dict{Int, Any}()

    report && _PMs.sol_component_value(pm, nw, :load, :pd, _PMs.ids(pm, nw, :load), pd)
end


function variable_mc_load_reactive(pm::_PMs.AbstractPowerModel;
                                   nw::Int=pm.cnw, report::Bool=true)
    cnds = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    qd = _PMs.var(pm, nw)[:qd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_qd_$(i)",
            start = _PMD.comp_start_value(_PMs.ref(pm, nw, :load, i), "qd_start", c, 0.0)
        ) for i in _PMs.ids(pm, nw, :load)
    )

    _PMs.var(pm, nw)[:qd_bus] = Dict{Int, Any}()

    report && _PMs.sol_component_value(pm, nw, :load, :qd, _PMs.ids(pm, nw, :load), qd)
end
