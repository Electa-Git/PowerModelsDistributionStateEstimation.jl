""
function variable_mc_injection(pm::_PMs.AbstractPowerModel; kwargs...)
    variable_mc_injection_active(pm; kwargs...)
    variable_mc_injection_reactive(pm; kwargs...)
end

function variable_mc_injection_active(  pm::_PMs.AbstractPowerModel;
                                        nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    pi = _PMs.var(pm, nw)[:pi] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = "$(nw)_pi_$(i)"
            ) for i in _PMs.ids(pm, nw, :bus)
        )

    report && _PMs.sol_component_value(pm, nw, :bus, :pi, _PMs.ids(pm, nw, :bus), pi)
end


""
function variable_mc_injection_reactive(pm::_PMs.AbstractPowerModel;
                                        nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    qi = _PMs.var(pm, nw)[:qi] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = "$(nw)_qi_$(i)"
            ) for i in _PMs.ids(pm, nw, :bus)
        )

    report && _PMs.sol_component_value(pm, nw, :bus, :qi, _PMs.ids(pm, nw, :bus), qi)
end


""
function variable_mc_residual(  pm::_PMs.AbstractACPModel;
                                nw::Int=pm.cnw, report::Bool=true)
    variable_mc_residual_overall(pm; kwargs...)
    variable_mc_residual_active_power(pm; kwargs...)
    variable_mc_residual_reactive_power(pm; kwargs...)
    variable_mc_residual_voltage_magnitude(pm; kwargs...)
end


""
function variable_mc_residual_overall(  pm::_PMs.AbstractPowerModel;
                                        nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    res = _PMs.var(pm, nw)[:res] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = "$(nw)_res_$(i)"
            ) for i in _PMs.ids(pm, nw, :bus)
        )

    report && _PMs.sol_component_value(pm, nw, :bus, :res, _PMs.ids(pm, nw, :bus), res)
end


""
function variable_mc_residual_active_power( pm::_PMs.AbstractPowerModel;
                                            nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    res_p = _PMs.var(pm, nw)[:res_p] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = "$(nw)_res_p_$(i)"
            ) for i in _PMs.ids(pm, nw, :bus)
        )

    report && _PMs.sol_component_value(pm, nw, :bus, :res_p, _PMs.ids(pm, nw, :bus), res_p)
end


""
function variable_mc_residual_reactive_power(   pm::_PMs.AbstractPowerModel;
                                                nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    res_q = _PMs.var(pm, nw)[:res_q] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = "$(nw)_res_q_$(i)"
            ) for i in _PMs.ids(pm, nw, :bus)
        )

    report && _PMs.sol_component_value(pm, nw, :bus, :res_q, _PMs.ids(pm, nw, :bus), res_q)
end


""
function variable_mc_residual_voltage_magnitude(pm::_PMs.AbstractPowerModel;
                                                nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    res_vm = _PMs.var(pm, nw)[:res_vm] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name = "$(nw)_res_vm_$(i)"
            ) for i in _PMs.ids(pm, nw, :bus)
        )

    report && _PMs.sol_component_value(pm, nw, :bus, :res_vm, _PMs.ids(pm, nw, :bus), res_vm)
end
