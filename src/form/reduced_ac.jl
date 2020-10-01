################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsSE.jl                                                             #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

mutable struct ReducedACPPowerModel <: _PMs.AbstractACPModel _PMs.@pm_fields end
mutable struct ReducedACRPowerModel <: _PMs.AbstractACRModel _PMs.@pm_fields end

AbstractReducedModel = Union{ReducedACRPowerModel, ReducedACPPowerModel}

"Power balance constraint for the reduced ACR and ACP formulations.
These formulation are exact for networks like those made available in the ENWL database,
where there are no gound admittance, storage elements and active switches.
Other than this, the function is the same as the constraint_mc_load_power_balance defined in PowerModelsDistribution "
function constraint_mc_load_power_balance(pm::AbstractReducedModel, i::Int; nw::Int=pm.cnw)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = _PMD.ref(pm, nw, :bus_gens, i)
    bus_loads = _PMD.ref(pm, nw, :bus_loads, i)

    p    = get(_PMD.var(pm, nw),    :p, Dict()); _PMs._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(_PMD.var(pm, nw),    :q, Dict()); _PMs._check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(_PMD.var(pm, nw),   :pg, Dict()); _PMs._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(_PMD.var(pm, nw),   :qg, Dict()); _PMs._check_var_keys(qg, bus_gens, "reactive power", "generator")
    pt   = get(_PMD.var(pm, nw),   :pt, Dict()); _PMs._check_var_keys(pt, bus_arcs_trans, "active power", "transformer")
    qt   = get(_PMD.var(pm, nw),   :qt, Dict()); _PMs._check_var_keys(qt, bus_arcs_trans, "reactive power", "transformer")
    pd   = get(_PMD.var(pm, nw),  :pd, Dict()); _PMs._check_var_keys(pd, bus_loads, "active power", "load")
    qd   = get(_PMD.var(pm, nw),  :qd, Dict()); _PMs._check_var_keys(pd, bus_loads, "reactive power", "load")

    # pd/qd can be NLexpressions, so cannot be vectorized
    for c in _PMs.conductor_ids(pm; nw=nw)
        cp = JuMP.@constraint(pm.model,
            sum(p[a][c] for a in bus_arcs)
            + sum(pt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(pg[g][c] for g in bus_gens)
            - sum(pd[l][c] for l in bus_loads)
        )

        cq = JuMP.@constraint(pm.model,
            sum(q[a][c] for a in bus_arcs)
            + sum(qt[a_trans][c] for a_trans in bus_arcs_trans)
            ==
            sum(qg[g][c] for g in bus_gens)
            - sum(qd[l][c] for l in bus_loads)
        )
    end
end

"If the formulation is not reduced, delegates back to PowerModelsDistribution"
function constraint_mc_load_power_balance(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    _PMD.constraint_mc_load_power_balance(pm, i; nw=nw)
end

function variable_mc_bus_voltage(pm::ReducedACPPowerModel; bounded = true)
    _PMD.variable_mc_bus_voltage_angle(pm; bounded = bounded)
    _PMD.variable_mc_bus_voltage_magnitude_only(pm; bounded = bounded)
end

function variable_mc_bus_voltage(pm::ReducedACRPowerModel; bounded = true)
    _PMD.variable_mc_bus_voltage(pm; bounded = bounded)
end

"If the formulation is not reduced, delegates back to PowerModelsDistribution"
function variable_mc_bus_voltage(pm::_PMs.AbstractPowerModel; bounded = true)
    _PMD.variable_mc_bus_voltage(pm; bounded = bounded)
end
