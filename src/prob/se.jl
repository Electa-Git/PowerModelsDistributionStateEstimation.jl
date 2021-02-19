################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

"solves the AC state estimation in polar coordinates (ACP formulation)"
function solve_acp_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, _PMs.ACPPowerModel, solver; kwargs...)
end

"depreciation message"
function run_acp_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    @warn "run_acp_mc_se is being depreciated in favor of solve_acp_mc_se, please update your code accordingly"
    return solve_mc_se(data, _PMs.ACPPowerModel, solver; kwargs...)
end

"solves the AC state estimation in rectangular coordinates (ACR formulation)"
function solve_acr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, _PMs.ACRPowerModel, solver; kwargs...)
end

"depreciation message"
function run_acr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    @warn "run_acr_mc_se is being depreciated in favor of solve_acr_mc_se, please update your code accordingly"
    return solve_mc_se(data, _PMs.ACRPowerModel, solver; kwargs...)
end

"solves state estimation in current and voltage rectangular coordinates (IVR formulation)"
function solve_ivr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, _PMs.IVRPowerModel, solver; kwargs...)
end

"depreciation message"
function run_ivr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    @warn "run_ivr_mc_se is being depreciated in favor of solve_ivr_mc_se, please update your code accordingly"
    return solve_mc_se(data, _PMs.IVRPowerModel, solver; kwargs...)
end

"solves state estimation with a positive semi-definite fomrulation of the power flow equations (SDP formulation)"
function solve_sdp_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, _PMD.SDPUBFPowerModel, solver; kwargs...)
end

"depreciation message"
function run_sdp_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    @warn "run_sdp_mc_se is being depreciated in favor of solve_sdp_mc_se, please update your code accordingly"
    return solve_mc_se(data, _PMD.SDPUBFPowerModel, solver; kwargs...)
end

"solves the reduced AC state estimation in polar coordinates (ReducedACP formulation)"
function solve_acp_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, ReducedACPPowerModel, solver; kwargs...)
end

"depreciation message"
function run_acp_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    @warn "run_acp_red_mc_se is being depreciated in favor of solve_acp_red_mc_se, please update your code accordingly"
    return solve_mc_se(data, ReducedACPPowerModel, solver; kwargs...)
end

"solves the reduced AC state estimation in rectangular coordinates (ReducedACR formulation)"
function solve_acr_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, ReducedACRPowerModel, solver; kwargs...)
end

"depreciation message"
function run_acr_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    @warn "run_acr_red_mc_se is being depreciated in favor of solve_acr_red_mc_se, please update your code accordingly"
    return solve_mc_se(data, ReducedACRPowerModel, solver; kwargs...)
end

"solves the reduced state estimation in current and voltage rectangular coordinates (ReducedIVR formulation)"
function solve_ivr_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, ReducedIVRPowerModel, solver; kwargs...)
end

"depreciation message"
function run_ivr_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    @warn "run_ivr_red_mc_se is being depreciated in favor of solve_ivr_red_mc_se, please update your code accordingly"
    return solve_mc_se(data, ReducedIVRPowerModel, solver; kwargs...)
end

"solves state estimation with a linear approximation of the power flow equations (LinDist3Flow formulation)"
function solve_linear_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, _PMD.LinDist3FlowPowerModel, solver; kwargs...)
end

"depreciation message"
function run_linear_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    @warn "run_linear_mc_se is being depreciated in favor of solve_linear_mc_se, please update your code accordingly"
    return solve_mc_se(data, _PMD.LinDist3FlowPowerModel, solver; kwargs...)
end

"depreciation message for run_mc_se"
function run_mc_se(data::Union{String,Dict{String,<:Any}}, model_type::Type, solver; kwargs...)::Dict{String,Any}
    @warn "run_mc_se is being depreciated in favor of solve_mc_se, please update your code accordingly"
    return solve_mc_se(data, model_type, solver; kwargs...)
end

function solve_mc_se(data::Union{Dict{String,<:Any},String}, model_type::Type, solver; kwargs...)
    if haskey(data["se_settings"], "criterion")
        _PMDSE.assign_unique_individual_criterion!(data)
    end
    if !haskey(data["se_settings"], "rescaler")
        data["se_settings"]["rescaler"] = 1
        Memento.warn(_LOGGER, "Rescaler set to default value, edit data dictionary if you wish to change it.")
    end
    if !haskey(data["se_settings"], "number_of_gaussian")
        data["se_settings"]["number_of_gaussian"] = 10
        Memento.warn(_LOGGER, "Estimation criterion set to default value, edit data dictionary if you wish to change it.")
    end
    return _PMD.run_mc_model(data, model_type, solver, build_mc_se; kwargs...)
end

"specification of the state estimation problem for a bus injection model - ACP and ACR formulations"
function build_mc_se(pm::_PMs.AbstractPowerModel)

    # Variables
    _PMDSE.variable_mc_bus_voltage(pm; bounded = true)
    _PMD.variable_mc_branch_power(pm; bounded = true)
    _PMD.variable_mc_transformer_power(pm; bounded = true)
    _PMD.variable_mc_generator_power(pm; bounded = true)
    variable_mc_load(pm; report = true)
    variable_mc_residual(pm; bounded = true)
    variable_mc_measurement(pm; bounded = false)

    # Constraints
    for (i,gen) in _PMD.ref(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :bus)
        _PMDSE.constraint_mc_power_balance_se(pm, i)
    end
    for (i,branch) in _PMD.ref(pm, :branch)
        _PMD.constraint_mc_ohms_yt_from(pm, i)
        _PMD.constraint_mc_ohms_yt_to(pm,i)
    end
    for (i,meas) in _PMD.ref(pm, :meas)
        constraint_mc_residual(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    # Objective
    objective_mc_se(pm)

end

"specification of the state estimation problem for the IVR Flow formulation"
function build_mc_se(pm::_PMs.AbstractIVRModel)
    # Variables

    _PMD.variable_mc_bus_voltage(pm, bounded = true)
    _PMDSE.variable_mc_branch_current(pm, bounded = true)
    variable_mc_generator_current_se(pm, bounded = true)
    _PMD.variable_mc_transformer_current(pm, bounded = false)
    variable_mc_load_current(pm, bounded = false)#TODO bug in the bounds assignment
    variable_mc_residual(pm, bounded = true)
    variable_mc_measurement(pm, bounded = false)

    # Constraints
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end

    # gens should be constrained before KCL, or Pd/Qd undefined
    for id in _PMD.ids(pm, :gen)
        constraint_mc_generator_power_se(pm, id)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_current_balance_se(pm, i)
    end

    if typeof(pm) <: ReducedIVRPowerModel
        for i in _PMD.ids(pm, :branch)
            constraint_current_to_from(pm, i)
            constraint_mc_bus_voltage_drop(pm, i)
        end
    else
        for i in _PMD.ids(pm, :branch)
            _PMD.constraint_mc_current_from(pm, i)
            _PMD.constraint_mc_current_to(pm, i)
            _PMD.constraint_mc_bus_voltage_drop(pm, i)
        end
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    for (i,meas) in _PMD.ref(pm, :meas)
        constraint_mc_residual(pm, i)
    end

    objective_mc_se(pm)

end

"specification of the state estimation problem for a branch flow model - SDP and LinDist3Flow formulations"
function build_mc_se(pm::_PMD.AbstractUBFModels)

    # Variables
    _PMD.variable_mc_bus_voltage(pm)
    _PMD.variable_mc_branch_current(pm)
    _PMD.variable_mc_branch_power(pm)
    _PMD.variable_mc_transformer_power(pm; bounded=true)
    _PMD.variable_mc_generator_power(pm; bounded=true)
    variable_mc_load(pm; report = true)
    variable_mc_residual(pm, bounded = true)
    variable_mc_measurement(pm, bounded = false)

    #Constraints
    _PMD.constraint_mc_model_current(pm)

    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end

    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, id)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        _PMDSE.constraint_mc_power_balance_se(pm,i)
    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_power_losses(pm, i)
        _PMD.constraint_mc_model_voltage_magnitude_difference(pm, i)
        _PMD.constraint_mc_voltage_angle_difference(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    for (i,meas) in _PMD.ref(pm, :meas)
        constraint_mc_residual(pm, i)
    end

    objective_mc_se(pm)

end
