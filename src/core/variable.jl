"""
    variable_mc_residual
"""
function variable_mc_residual(  pm::_PMs.AbstractPowerModel;
                                nw::Int=pm.cnw, bounded::Bool=true,
                                report::Bool=true)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    res = _PMD.var(pm, nw)[:res] = Dict(i => JuMP.@variable(pm.model,
        [c in 1:ncnds], base_name = "$(nw)_res_$(i)",
        start = _PMD.comp_start_value(_PMD.ref(pm, nw, :meas, i), "res_start", c, 0.0)
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
    variable_mc_load in terms of power, for ACR and ACP
"""
function variable_mc_load(pm::_PMs.AbstractPowerModel; kwargs...)
    variable_mc_load_active(pm; kwargs...)
    variable_mc_load_reactive(pm; kwargs...)
end


function variable_mc_load_active(pm::_PMs.AbstractPowerModel;
                                 nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    pd = _PMD.var(pm, nw)[:pd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_pd_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "pd_start",c, 0.0)
        ) for i in _PMD.ids(pm, nw, :load)
    )

    if bounded
        for (i,load) in _PMD.ref(pm, nw, :load)
            if haskey(load, "pmin")
                JuMP.set_lower_bound.(pd[i], load["pmin"])
            end
            if haskey(load, "pmax")
                JuMP.set_upper_bound.(pd[i], load["pmax"])
            end
        end
    end

    _PMs.var(pm, nw)[:pd_bus] = Dict{Int, Any}()

    report && _IM.sol_component_value(pm, nw, :load, :pd, _PMD.ids(pm, nw, :load), pd)
end

function variable_mc_load_reactive(pm::_PMs.AbstractPowerModel;
                                   nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    qd = _PMD.var(pm, nw)[:qd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_qd_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "qd_start",c, 0.0)
        ) for i in _PMD.ids(pm, nw, :load)
    )

    if bounded
        for (i,load) in _PMD.ref(pm, nw, :load)
            if haskey(load, "qmin")
                JuMP.set_lower_bound.(qd[i], load["qmin"])
            end
            if haskey(load, "qmax")
                JuMP.set_upper_bound.(qd[i], load["qmax"])
            end
        end
    end

    _PMs.var(pm, nw)[:qd_bus] = Dict{Int, Any}()

    report && _IM.sol_component_value(pm, nw, :load, :qd, _PMD.ids(pm, nw, :load), qd)

end

"""
    variable_mc_load_current, IVR current equivalent of variable_mc_load
"""
function variable_mc_load_current(pm::_PMs.IVRPowerModel; kwargs...)
    variable_mc_load_current_real(pm; kwargs...)
    variable_mc_load_current_imag(pm; kwargs...)
end


function variable_mc_load_current_real(pm::_PMs.IVRPowerModel;
                                 nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    crd = _PMD.var(pm, nw)[:crd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_crd_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "crd_start", c, 0.0)
        ) for i in _PMD.ids(pm, nw, :load)
    )

    if bounded
        for i in _PMs.ids(pm, nw, :load), c in _PMD.conductor_ids(pm; nw=nw)
            JuMP.set_lower_bound(crd[i][c], 0.0)
        end
    end

    report && _IM.sol_component_value(pm, nw, :load, :crd, _PMD.ids(pm, nw, :load), crd)
end

function variable_mc_load_current_imag(pm::_PMs.IVRPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, meas_start::Bool=false)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    cid = _PMD.var(pm, nw)[:cid] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_cid_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "cid_start",c, 0.0)
        ) for i in _PMD.ids(pm, nw, :load)
    )

    report && _IM.sol_component_value(pm, nw, :load, :cid, _PMD.ids(pm, nw, :load), cid)

end

"""
    variable_mc_measurement, checks if the measured quantity belongs to the formulation's variable space and
    if not, it converts it
"""

function variable_mc_measurement(pm::_PMs.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=false)
    for i in _PMD.ids(pm, nw, :meas)
        msr_var = _PMD.ref(pm, nw, :meas, i, "var")
        cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
        cmp_type = _PMD.ref(pm, nw, :meas, i, "cmp")
        nph=3
        if no_conversion_needed(pm, msr_var)
            #no additional variable is created, it is already by default in the formulation
        else
            cmp_type == :branch ? id = (cmp_id, _PMD.ref(pm,nw,:branch, cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch, cmp_id)["t_bus"]) : id = cmp_id
            if haskey(_PMD.var(pm, nw), msr_var)
                push!(_PMD.var(pm, nw)[msr_var], id => JuMP.@variable(pm.model,
                    [c in 1:nph], base_name="$(nw)_$(String(msr_var))_$id"))
            else
                _PMD.var(pm, nw)[msr_var] = Dict(id => JuMP.@variable(pm.model,
                    [c in 1:nph], base_name="$(nw)_$(String(msr_var))_$id"))
            end
            msr_type = assign_conversion_type_to_msr(pm, i, msr_var; nw=nw)
            create_conversion_constraint(pm, _PMD.var(pm, nw)[msr_var], msr_type; nw=nw, nph=nph)
        end
    end
end

function variable_mc_gen_power_setpoint_se(pm::_PMs.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)

    _PMD.variable_mc_gen_current_setpoint_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_gen_current_setpoint_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PMs.var(pm, nw)[:crg_bus] = Dict{Int, Any}()
    _PMs.var(pm, nw)[:cig_bus] = Dict{Int, Any}()
end
