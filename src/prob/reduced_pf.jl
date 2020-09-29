"""
This function allows to run a power flow with the reduced formulations.
This is currently only used to validate the exactness of the reduced forms, but
the power flow calculation is faster than with with the full model, so it can
be used if faster calculations are desired.
Reduced forms are exact for network data such as that of the ENWL database,
where no ground admittance, bus shunts, storage units or active switches are present.
"""
function run_reduced_pf(data::Union{Dict{String,<:Any},String}, model_type::Type, solver; kwargs...)
    return _PMD.run_mc_model(data, model_type, solver, build_reduced_pf; kwargs...)
end

"""Constructor for reduced Power Flow Problem"""
function build_reduced_pf(pm::PowerModelsDSSE.AbstractReducedModel)
    _PMD.variable_mc_bus_voltage(pm; bounded=false)
    _PMD.variable_mc_branch_power(pm; bounded=false)
    _PMD.variable_mc_transformer_power(pm; bounded=false)
    _PMD.variable_mc_gen_power_setpoint(pm; bounded=false)
    _PMD.variable_mc_load_setpoint(pm; bounded=false)
    #_PMD.variable_mc_storage_power(pm; bounded=false)

    _PMD.constraint_mc_model_voltage(pm)

    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3

        _PMD.constraint_mc_theta_ref(pm, i)
        _PMD.constraint_mc_voltage_magnitude_only(pm, i)
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
        PowerModelsDSSE.constraint_mc_load_power_balance(pm, i)

        # PV Bus Constraints
        if length(_PMD.ref(pm, :bus_gens, i)) > 0 && !(i in _PMD.ids(pm,:ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2

            _PMD.constraint_mc_voltage_magnitude_only(pm, i)
            for j in _PMD.ref(pm, :bus_gens, i)
                _PMD.constraint_mc_gen_power_setpoint_real(pm, j)
            end
        end
    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_ohms_yt_from(pm, i)
        _PMD.constraint_mc_ohms_yt_to(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end
end

"Constructor for reduced power flow with ReducedIVRPowerModel (current-voltage variable space)"
function build_reduced_pf(pm::PowerModelsDSSE.ReducedIVRPowerModel)
    # Variables
    _PMD.variable_mc_bus_voltage(pm, bounded = false)
    PowerModelsDSSE.variable_mc_branch_current(pm, bounded = false)
    _PMD.variable_mc_transformer_current(pm, bounded = false)
    _PMD.variable_mc_gen_power_setpoint(pm, bounded = false)
    _PMD.variable_mc_load_setpoint(pm, bounded = false)

    # Constraints
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
        _PMD.constraint_mc_voltage_magnitude_only(pm, i)
    end

    for id in _PMD.ids(pm, :gen)
        PowerModelsDSSE.constraint_mc_gen_setpoint(pm, id)
    end

    for id in _PMD.ids(pm, :load)
        PowerModelsDSSE.constraint_mc_load_setpoint(pm, id)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        PowerModelsDSSE.constraint_mc_load_current_balance(pm, i)

        # PV Bus Constraints
        if length(_PMD.ref(pm, :bus_gens, i)) > 0 && !(i in _PMD.ids(pm,:ref_buses))
            @assert bus["bus_type"] == 2
            _PMD.constraint_mc_voltage_magnitude_only(pm, i)
            for j in ref(pm, :bus_gens, i)
                _PMD.constraint_mc_gen_power_setpoint_real(pm, j)
            end
        end
    end

    for i in _PMD.ids(pm, :branch)
        PowerModelsDSSE.constraint_mc_bus_voltage_drop(pm, i)
        PowerModelsDSSE.constraint_current_to_from(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end
end
