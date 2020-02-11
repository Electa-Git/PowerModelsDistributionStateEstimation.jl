""
function constraint_mc_power_balance_se(pm::_PMs.AbstractPowerModel, i::Int;
                                        nw::Int=pm.cnw)
    bus = _PMs.ref(pm, nw, :bus, i) ## why create this variable, its never uses again
    bus_arcs = _PMs.ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = _PMs.ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = _PMs.ref(pm, nw, :bus_arcs_trans, i)
    bus_shunts = _PMs.ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => _PMs.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PMs.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_mc_power_balance_se(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gs, bus_bs)
end
