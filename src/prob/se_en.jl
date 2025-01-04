"solves state estimation in current and voltage rectangular coordinates for an explicit neutral model (IVREN formulation)"
function solve_ivr_en_mc_se(data::Union{Dict{String,<:Any},String}, solver; kwargs...)
    return solve_mc_se(data, _PMD.IVRENPowerModel, solver; kwargs...)
end


#####################################################################
###################### Optimization Problem Formulation ##############
#####################################################################

"specification of the state estimation problem for the IVR Flow formulation"
function build_mc_se(pm::_PMD.IVRENPowerModel)
    # Variables  
    _PMD.variable_mc_bus_voltage(pm, bounded = true)
    _PMD.variable_mc_branch_current(pm, bounded = true)
    variable_mc_load_current(pm, bounded = true)    
    _PMD.variable_mc_generator_current(pm, bounded = true)
    _PMD.variable_mc_transformer_current(pm, bounded = true)
    variable_mc_residual(pm, bounded = true)
    variable_mc_measurement(pm, bounded = false)

    # Constraints

    for i in _PMD.ids(pm, :bus)
        if i in _PMD.ids(pm, :ref_buses)
            _PMD.constraint_mc_voltage_reference(pm, i)  # vm is not fixed
        end
        _PMD.constraint_mc_voltage_absolute(pm, i)
        _PMD.constraint_mc_voltage_pairwise(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_voltage(pm, i)
        _PMD.constraint_mc_transformer_current(pm, i)
    end


    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_current_balance_se(pm, i)
    end

    for (i,meas) in _PMD.ref(pm, :meas)
        constraint_mc_residual(pm, i)
    end


    objective_mc_se(pm)
end