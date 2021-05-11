################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
"""
    variable_mc_residual

This is the residual variable, which is later associated to the residual (in)equality constraint(s), depending on the chosen
state estimation criterion.
If bounded, the lower bound is set to zero, while the upper bound defaults to Inf, unless the user provides
a different value in the measurement dictionary.
"""
function variable_mc_residual(  pm::_PMD.AbstractPowerModel;
                                nw::Int=pm.cnw, bounded::Bool=true,
                                report::Bool=true)

    connections = Dict(i => length(meas["dst"]) for (i,meas) in _PMD.ref(pm, nw, :meas) )

    res = _PMD.var(pm, nw)[:res] = Dict(i => JuMP.@variable(pm.model,
        [c in 1:connections[i]], base_name = "$(nw)_res_$(i)",
        start = _PMD.comp_start_value(_PMD.ref(pm, nw, :meas, i), "res_start", c, 0.0)
        ) for i in _PMD.ids(pm, nw, :meas)
    )

    if bounded
        for i in _PMD.ids(pm, nw, :meas), c in 1:connections[i]
            JuMP.set_lower_bound(res[i][c], 0.0)
            haskey(_PMD.ref(pm, nw, :meas, i), "res_max") ? res_max = meas["res_max"] : res_max = Inf
            JuMP.set_upper_bound(res[i][c], res_max)
        end
    end

    report && _IM.sol_component_value(pm, nw, :meas, :res, _PMD.ids(pm, nw, :meas), res)
end
"""
    variable_mc_load in terms of power, for ACR and ACP
"""
function variable_mc_load(pm::_PMD.AbstractPowerModel; kwargs...)
    variable_mc_load_active(pm; kwargs...)
    variable_mc_load_reactive(pm; kwargs...)
end

function variable_mc_load_active(pm::_PMD.AbstractPowerModel;
                                 nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)

    connections = Dict(i => load["connections"] for (i,load) in _PMD.ref(pm, nw, :load))

    pd = _PMD.var(pm, nw)[:pd] = Dict(i => JuMP.@variable(pm.model,
            [c in connections[i]], base_name="$(nw)_pd_$(i)"
            #,start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "pd_start", c, 0.0) #findall(idx -> idx == c, connections[i])[1]
        ) for i in _PMD.ids(pm, nw, :load)
    )

    if bounded
        for (i,load) in _PMD.ref(pm, nw, :load)
            if haskey(load, "pmin")
                for (idx, c) in enumerate(connections[i])
                    JuMP.set_lower_bound(pd[i][c], load["pmin"][idx])
                end
            end
            if haskey(load, "pmax")
                for (idx, c) in enumerate(connections[i])
                    JuMP.set_upper_bound(pd[i][c], load["pmax"][idx])
                end
            end
        end
    end

    report && _IM.sol_component_value(pm, nw, :load, :pd, _PMD.ids(pm, nw, :load), pd)
end

function variable_mc_load_reactive(pm::_PMD.AbstractPowerModel;
                                   nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)

    connections = Dict(i => load["connections"] for (i,load) in _PMD.ref(pm, nw, :load))

    qd = _PMD.var(pm, nw)[:qd] = Dict(i => JuMP.@variable(pm.model,
            [c in connections[i]], base_name="$(nw)_qd_$(i)"
            #,start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "qd_start", c, 0.0) #findall(idx -> idx == c, connections[i])[1]
        ) for i in _PMD.ids(pm, nw, :load)
    )

    if bounded
        for (i,load) in _PMD.ref(pm, nw, :load)
            if haskey(load, "qmin")
                for (idx, c) in enumerate(connections[i])
                    JuMP.set_lower_bound(qd[i][c], load["qmin"][idx])
                end
            end
            if haskey(load, "qmax")
                for (idx, c) in enumerate(connections[i])
                    JuMP.set_upper_bound(qd[i][c], load["qmax"][idx])
                end
            end
        end
    end

    report && _IM.sol_component_value(pm, nw, :load, :qd, _PMD.ids(pm, nw, :load), qd)

end
"""
    variable_mc_load_current, IVR current equivalent of variable_mc_load
"""
function variable_mc_load_current(pm::_PMD.AbstractUnbalancedIVRModel; kwargs...)
    variable_mc_load_current_real(pm; kwargs...)
    variable_mc_load_current_imag(pm; kwargs...)
end


function variable_mc_load_current_real(pm::_PMD.AbstractUnbalancedIVRModel;
                                 nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)

    connections = Dict(i => load["connections"] for (i,load) in _PMD.ref(pm, nw, :load))

    crd = _PMD.var(pm, nw)[:crd] = Dict(i => JuMP.@variable(pm.model,
            [c in connections[i]], base_name="$(nw)_crd_$(i)"
            #,start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "crd_start", c, 0.0)
        ) for i in _PMD.ids(pm, nw, :load)
    )

    report && _IM.sol_component_value(pm, nw, :load, :crd, _PMD.ids(pm, nw, :load), crd)
end

function variable_mc_load_current_imag(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, meas_start::Bool=false)

    connections = Dict(i => load["connections"] for (i,load) in _PMD.ref(pm, nw, :load))

    cid = _PMD.var(pm, nw)[:cid] = Dict(i => JuMP.@variable(pm.model,
            [c in connections[i]], base_name="$(nw)_cid_$(i)"
            #,start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "cid_start",c, 0.0)
        ) for i in _PMD.ids(pm, nw, :load)
    )

    report && _IM.sol_component_value(pm, nw, :load, :cid, _PMD.ids(pm, nw, :load), cid)

end
"""
    variable_mc_measurement
checks for every measurement if the measured
quantity belongs to the formulation's variable space. If not, the function
`create_conversion_constraint' is called, that adds a constraint that
associates the measured quantity to the formulation's variable space.
"""
function variable_mc_measurement(pm::_PMD.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=false)
    for i in _PMD.ids(pm, nw, :meas)
        msr_var = _PMD.ref(pm, nw, :meas, i, "var")
        cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
        cmp_type = _PMD.ref(pm, nw, :meas, i, "cmp")
        connections = get_active_connections(pm, nw, cmp_type, cmp_id)
        if no_conversion_needed(pm, msr_var)
            #no additional variable is created, it is already by default in the formulation
        else
            cmp_type == :branch ? id = (cmp_id, _PMD.ref(pm,nw,:branch, cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch, cmp_id)["t_bus"]) : id = cmp_id
            if haskey(_PMD.var(pm, nw), msr_var)
                push!(_PMD.var(pm, nw)[msr_var], id => JuMP.@variable(pm.model,
                    [c in connections], base_name="$(nw)_$(String(msr_var))_$id"))
            else
                _PMD.var(pm, nw)[msr_var] = Dict(id => JuMP.@variable(pm.model,
                    [c in connections], base_name="$(nw)_$(String(msr_var))_$id"))
            end
            msr_type = assign_conversion_type_to_msr(pm, i, msr_var; nw=nw)
            create_conversion_constraint(pm, _PMD.var(pm, nw)[msr_var], msr_type; nw=nw)
        end
    end
end

function variable_mc_generator_current_se(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    #NB: the difference with PowerModelsDistributions is that pg and qg expressions are not created
    _PMD.variable_mc_generator_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_generator_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end
