
""
function run_acp_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return run_mc_se(data, _PMs.ACPPowerModel, solver; kwargs...)
end

""
function run_acr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return run_mc_se(data, _PMs.ACRPowerModel, solver; kwargs...)
end

""
function run_ivr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return run_mc_se(data, _PMs.IVRPowerModel, solver; kwargs...)
end

""
function run_sdp_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return run_mc_se(data, _PMD.SDPUBFPowerModel, solver; kwargs...)
end
""
function run_acp_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return run_mc_se(data, ReducedACPPowerModel, solver; kwargs...)
end

""
function run_acr_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return run_mc_se(data, ReducedACRPowerModel, solver; kwargs...)
end

""
function run_ivr_red_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return run_mc_se(data, ReducedIVRPowerModel, solver; kwargs...)
end

# ""
#NB TODO
# function run_sdpr_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
#     return run_mc_se(data, _PMD.ReduceSDPUBFPowerModel, solver; kwargs...)
# end
# ""

function run_mc_se(data::Union{Dict{String,<:Any},String}, model_type::Type, solver; kwargs...)
    if !haskey(data["setting"], "weight_rescaler")
        data["setting"]["weight_rescaler"] = 1
    end
    if !haskey(data["setting"], "estimation_criterion")
        data["setting"]["estimation_criterion"] = "wls"
    end
    return _PMD.run_mc_model(data, model_type, solver, build_mc_se; kwargs...)
end

""
function build_mc_se(pm::_PMs.AbstractPowerModel)

    # Variables
    _PMD.variable_mc_bus_voltage(pm; bounded = true)
    _PMD.variable_mc_branch_power(pm; bounded = true)
    _PMD.variable_mc_transformer_power(pm; bounded = true)
    _PMD.variable_mc_gen_power_setpoint(pm; bounded = true)
    variable_mc_load(pm; report = true)
    variable_mc_residual(pm, bounded = true)
    variable_mc_measurement(pm, bounded = false)

    # Constraints
    for (i,gen) in _PMD.ref(pm, :gen)
        _PMD.constraint_mc_gen_setpoint(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_load_power_balance_se(pm, i)
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

function build_mc_se(pm::_PMs.AbstractIVRModel)
    # Variables

    _PMD.variable_mc_bus_voltage(pm, bounded = true)
    _PMD.variable_mc_branch_current(pm, bounded = true)
    variable_mc_gen_power_setpoint_se(pm, bounded = true)#NB the difference with PMD is that I don't write a pg,qg expression. I create crg/cig vars and crg_bus/cig_bus expressions
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
        constraint_mc_gen_setpoint_se(pm, id)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_load_current_balance_se(pm, i)
    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)

        _PMD.constraint_mc_bus_voltage_drop(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    for (i,meas) in _PMD.ref(pm, :meas)
        constraint_mc_residual(pm, i)
    end

    objective_mc_se(pm)

end

function build_mc_se(pm::_PMD.AbstractUBFModels)

    # Variables
    _PMD.variable_mc_bus_voltage(pm) # TODO in _PMD: should be false
    _PMD.variable_mc_branch_current(pm)
    _PMD.variable_mc_branch_power(pm)
    _PMD.variable_mc_transformer_power(pm; bounded=false)
    _PMD.variable_mc_gen_power_setpoint(pm; bounded=false)
    _PMD.variable_mc_load_setpoint(pm)
    variable_mc_residual(pm, bounded = true)
    variable_mc_measurement(pm, bounded = false)

    # Constraints
    _PMD.constraint_mc_model_current(pm)

    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        if !(typeof(pm)<:_PMD.LPUBFDiagPowerModel)
            _PMD.constraint_mc_theta_ref(pm, i)
        end
    end

    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_gen_setpoint(pm, id)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        _PMD.constraint_mc_load_power_balance(pm, i)
    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_power_losses(pm, i)
        _PMD.constraint_mc_model_voltage_magnitude_difference(pm, i)
        _PMD.constraint_mc_voltage_angle_difference(pm, i)

        _PMD.constraint_mc_thermal_limit_from(pm, i)
        _PMD.constraint_mc_thermal_limit_to(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    for (i,meas) in _PMD.ref(pm, :meas)
        constraint_mc_residual(pm, i)
    end

    objective_mc_se(pm)

end

function build_mc_se(pm::PowerModelsDSSE.AbstractReducedModel)

    # Variables
    PowerModelsDSSE.variable_mc_bus_voltage(pm; bounded = true)
    _PMD.variable_mc_branch_power(pm; bounded = true)
    _PMD.variable_mc_transformer_power(pm; bounded = true)
    _PMD.variable_mc_gen_power_setpoint(pm; bounded = true)
    variable_mc_load(pm; report = true)
    variable_mc_residual(pm, bounded = true)
    variable_mc_measurement(pm, bounded = false)

    # Constraints
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end

    for (i,gen) in _PMD.ref(pm, :gen)
        _PMD.constraint_mc_gen_setpoint(pm, i)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        PowerModelsDSSE.constraint_mc_load_power_balance(pm, i)
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

function build_mc_se(pm::ReducedIVRPowerModel)
    # Variables
    _PMD.variable_mc_bus_voltage(pm, bounded = true)
    variable_mc_branch_current(pm, bounded = true)
    variable_mc_gen_power_setpoint_se(pm, bounded = true)
    _PMD.variable_mc_transformer_current(pm, bounded = false)
    variable_mc_load_current(pm, bounded = true)#TODO bug in the bounds assignment
    variable_mc_residual(pm, bounded = true)
    variable_mc_measurement(pm, bounded = false)

    # Constraints
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end

    # gens should be constrained before KCL, or Pd/Qd undefined
    for id in _PMD.ids(pm, :gen)
        constraint_mc_gen_setpoint_se(pm, id)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_load_current_balance_se(pm, i)
    end

    for i in _PMD.ids(pm, :branch)
        constraint_current_to_from(pm, i)
        constraint_mc_bus_voltage_drop(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    for (i,meas) in _PMD.ref(pm, :meas)
        constraint_mc_residual(pm, i)
    end

    objective_mc_se(pm)

end
