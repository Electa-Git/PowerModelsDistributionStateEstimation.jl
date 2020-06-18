
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
    return run_mc_se(data, _PMDs.SDPUBFPowerModel, solver; kwargs...)
end
""
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
function build_mc_se(pm::_PMs.AbstractPowerModel)#works with both ACPolar and ACRectangular

    # Variables
    _PMD.variable_mc_bus_voltage(pm; bounded = false)
    _PMD.variable_mc_branch_power(pm; bounded = false)
    _PMD.variable_mc_transformer_power(pm; bounded = false)
    _PMD.variable_mc_gen_power_setpoint(pm; bounded = false)
    variable_mc_load(pm; report = true)
    variable_mc_residual(pm, bounded = true)

    # Constraints
    for (i,load) in _PMD.ref(pm, :load)
        _PMD.constraint_mc_load_setpoint(pm, i)
    end
    for (i,gen) in _PMD.ref(pm, :gen)
        _PMD.constraint_mc_gen_setpoint(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end
    for (i,bus) in _PMD.ref(pm, :bus)
        _PMD.constraint_mc_load_power_balance(pm, i)
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

    _PMD.variable_mc_bus_voltage(pm, bounded = false)
    _PMD.variable_mc_branch_current(pm, bounded = false)
    _PMD.variable_mc_gen_power_setpoint(pm, bounded = false)
    _PMD.variable_mc_transformer_current(pm, bounded = false)
    variable_mc_load_current(pm, bounded = false)
    variable_mc_residual(pm, bounded = true)

    # Constraints
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
    end

    # gens should be constrained before KCL, or Pd/Qd undefined
    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_gen_setpoint(pm, id)
    end

    # loads should be constrained before KCL, or Pd/Qd undefined
    for id in _PMD.ids(pm, :load)
        _PMD.constraint_mc_load_setpoint(pm, id)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        _PMD.constraint_mc_load_current_balance(pm, i)
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
