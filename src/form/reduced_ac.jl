################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModelsDistribution.jl for Static Power System   #
# State Estimation.                                                            #
################################################################################

mutable struct ReducedACPPowerModel <: _PMD.AbstractUnbalancedACPModel _PMD.@pmd_fields end
mutable struct ReducedACRPowerModel <: _PMD.AbstractUnbalancedACRModel _PMD.@pmd_fields end

AbstractReducedModel = Union{ReducedACRPowerModel, ReducedACPPowerModel}

"Power balance constraint for the reduced ACR and ACP formulations.
These formulation are exact for networks like those made available in the ENWL database,
where there are no gound admittance, storage elements and active switches.
Other than this, the function is the same as the constraint_mc_load_power_balance defined in PowerModelsDistribution "
function constraint_mc_power_balance(pm::AbstractReducedModel, i::Int; nw::Int=pm.cnw)

    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs_conns_branch, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_conns_transformer, i)
    bus_gens = _PMD.ref(pm, nw, :bus_conns_gen, i)
    bus_loads = _PMD.ref(pm, nw, :bus_conns_load, i)

    p    = get(_PMD.var(pm, nw),    :p, Dict()); _PMD._check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(_PMD.var(pm, nw),    :q, Dict()); _PMD._check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(_PMD.var(pm, nw),   :pg, Dict()); _PMD._check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(_PMD.var(pm, nw),   :qg, Dict()); _PMD._check_var_keys(qg, bus_gens, "reactive power", "generator")
    pt   = get(_PMD.var(pm, nw),   :pt, Dict()); _PMD._check_var_keys(pt, bus_arcs_trans, "active power", "transformer")
    qt   = get(_PMD.var(pm, nw),   :qt, Dict()); _PMD._check_var_keys(qt, bus_arcs_trans, "reactive power", "transformer")
    pd   = get(_PMD.var(pm, nw),  :pd, Dict()); _PMD._check_var_keys(pd, bus_loads, "active power", "load")
    qd   = get(_PMD.var(pm, nw),  :qd, Dict()); _PMD._check_var_keys(pd, bus_loads, "reactive power", "load")

    terminals = bus["terminals"]
    grounded =  bus["grounded"]

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx,t) in ungrounded_terminals
        cp = JuMP.@constraint(pm.model,
        sum(  p[a][t] for (a, conns) in bus_arcs if t in conns)
      + sum( pt[a][t] for (a, conns) in bus_arcs_trans if t in conns)
      - sum( pg[g][t] for (g, conns) in bus_gens if t in conns)
      + sum( pd[l][t] for (l, conns) in bus_loads if t in conns)
      == 0.0
      )

        cq = JuMP.@constraint(pm.model,
        sum(  q[a][t] for (a, conns) in bus_arcs if t in conns)
      + sum( qt[a][t] for (a, conns) in bus_arcs_trans if t in conns)
      - sum( qg[g][t] for (g, conns) in bus_gens if t in conns)
      + sum( qd[l][t] for (l, conns) in bus_loads if t in conns)
      == 0.0
      )
   end
end

"If the formulation is not reduced, delegates back to PowerModelsDistribution"
function constraint_mc_power_balance(pm::_PMD.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    _PMD.constraint_mc_power_balance(pm, i; nw=nw)
end

function variable_mc_bus_voltage(pm::ReducedACPPowerModel; bounded = true)
    _PMD.variable_mc_bus_voltage_angle(pm; bounded = bounded)
    _PMD.variable_mc_bus_voltage_magnitude_only(pm; bounded = bounded)
end

function variable_mc_bus_voltage(pm::ReducedACRPowerModel; bounded = true)
    _PMD.variable_mc_bus_voltage(pm; bounded = bounded)
end

"If the formulation is not reduced, delegates back to PowerModelsDistribution"
function variable_mc_bus_voltage(pm::_PMD.AbstractPowerModel; bounded = true)
    _PMD.variable_mc_bus_voltage(pm; bounded = bounded)
end
