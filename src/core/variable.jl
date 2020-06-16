"""
    variable_mc_residual
"""
function variable_mc_residual(  pm::_PMs.AbstractPowerModel;
                                nw::Int=pm.cnw, bounded::Bool=true,
                                report::Bool=true)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    res = _PMD.var(pm, nw)[:res] = Dict(i => JuMP.@variable(pm.model,
        [c in 1:ncnds], base_name = "$(nw)_res_$(i)"
        ) for i in _PMD.ids(pm, nw, :meas)
    )

    if bounded
        for i in _PMs.ids(pm, nw, :meas), c in _PMD.conductor_ids(pm; nw=nw)
            JuMP.set_lower_bound(res[i][c], 0.0)
        end
    end

    report && _IM.sol_component_value(pm, nw, :meas, :res, _PMs.ids(pm, nw, :meas), res)
end

"""
    variable_mc_load
"""
function variable_mc_load(pm::_PMs.AbstractPowerModel; kwargs...)
    variable_mc_load_active(pm; kwargs...)
    variable_mc_load_reactive(pm; kwargs...)
end


function variable_mc_load_active(pm::_PMs.AbstractPowerModel;
                                 nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, meas_start::Bool=false)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    if meas_start
        start_value = Dict(i => [_PMD.ref(pm, nw, :load, i)["pd_meas"][c] for c in 1:ncnds] for i in _PMD.ids(pm, nw, :load))
    else
        start_value =  Dict(i => [0.0 for c in 1:ncnds] for i in _PMD.ids(pm, nw, :load))
    end
    pd = _PMD.var(pm, nw)[:pd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_pd_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "pd_start", start_value[i][c])
        ) for i in _PMD.ids(pm, nw, :load)
    )

    if bounded
        for i in _PMs.ids(pm, nw, :load), c in _PMD.conductor_ids(pm; nw=nw)
            JuMP.set_lower_bound(pd[i][c], 0.0)
        end
    end

    _PMs.var(pm, nw)[:pd_bus] = Dict{Int, Any}()

    report && _IM.sol_component_value(pm, nw, :load, :pd, _PMD.ids(pm, nw, :load), pd)
end

function variable_mc_load_reactive(pm::_PMs.AbstractPowerModel;
                                   nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, meas_start::Bool=false)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    if meas_start
        start_value = Dict(i => [_PMD.ref(pm, nw, :load, i)["qd_meas"][c] for c in 1:ncnds] for i in _PMD.ids(pm, nw, :load))
    else
        start_value =  Dict(i => [0.0 for c in 1:ncnds] for i in _PMD.ids(pm, nw, :load))
    end

    qd = _PMD.var(pm, nw)[:qd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_qd_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "qd_start", start_value[i][c])
        ) for i in _PMD.ids(pm, nw, :load)
    )

    _PMs.var(pm, nw)[:qd_bus] = Dict{Int, Any}()

    report && _IM.sol_component_value(pm, nw, :load, :qd, _PMD.ids(pm, nw, :load), qd)

end

function variable_mc_load_current(pm::_PMs.IVRPowerModel; kwargs...)
    variable_mc_load_current_real(pm; kwargs...)
    variable_mc_load_current_imag(pm; kwargs...)
end


function variable_mc_load_current_real(pm::_PMs.IVRPowerModel;
                                 nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, meas_start::Bool=false)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    if meas_start
        start_value = Dict(i => [_PMD.ref(pm, nw, :load, i)["crd_meas"][c] for c in 1:ncnds] for i in _PMD.ids(pm, nw, :load))
    else
        start_value =  Dict(i => [0.0 for c in 1:ncnds] for i in _PMD.ids(pm, nw, :load))
    end
    crd = _PMD.var(pm, nw)[:crd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_crd_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "crd_start", start_value[i][c])
        ) for i in _PMD.ids(pm, nw, :load)
    )

    if bounded
        for i in _PMs.ids(pm, nw, :load), c in _PMD.conductor_ids(pm; nw=nw)
            JuMP.set_lower_bound(crd[i][c], 0.0)
        end
    end

    _PMs.var(pm, nw)[:crd_bus] = Dict{Int, Any}()

    report && _IM.sol_component_value(pm, nw, :load, :crd, _PMD.ids(pm, nw, :load), crd)
end

function variable_mc_load_current_imag(pm::_PMs.IVRPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, meas_start::Bool=false)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    if meas_start
        start_value = Dict(i => [_PMD.ref(pm, nw, :load, i)["cid_meas"][c] for c in 1:ncnds] for i in _PMD.ids(pm, nw, :load))
    else
        start_value =  Dict(i => [0.0 for c in 1:ncnds] for i in _PMD.ids(pm, nw, :load))
    end

    cid = _PMD.var(pm, nw)[:cid] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_cid_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "cid_start", start_value[i][c])
        ) for i in _PMD.ids(pm, nw, :load)
    )

    _PMs.var(pm, nw)[:cid_bus] = Dict{Int, Any}()

    report && _IM.sol_component_value(pm, nw, :load, :cid, _PMD.ids(pm, nw, :load), cid)

end
