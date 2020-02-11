# ""
# function constraint_mc_power_balance_se(pm::_PMs.AbstractACPModel, nw::Int, c::Int, i::Int, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
#     vm   = _PMs.var(pm, nw, c, :vm, i)
#     p    = get(_PMs.var(pm, nw, c),   :p, Dict()); _PMs._check_var_keys(p, bus_arcs, "active power", "branch")
#     q    = get(_PMs.var(pm, nw, c),   :q, Dict()); _PMs._check_var_keys(q, bus_arcs, "reactive power", "branch")
#     pg   = get(_PMs.var(pm, nw, c),  :pg, Dict()); _PMs._check_var_keys(pg, bus_gens, "active power", "generator")
#     qg   = get(_PMs.var(pm, nw, c),  :qg, Dict()); _PMs._check_var_keys(qg, bus_gens, "reactive power", "generator")
#     ps   = get(_PMs.var(pm, nw, c),  :ps, Dict()); _PMs._check_var_keys(ps, bus_storage, "active power", "storage")
#     qs   = get(_PMs.var(pm, nw, c),  :qs, Dict()); _PMs._check_var_keys(qs, bus_storage, "reactive power", "storage")
#     psw  = get(_PMs.var(pm, nw, c), :psw, Dict()); _PMs._check_var_keys(psw, bus_arcs_sw, "active power", "switch")
#     qsw  = get(_PMs.var(pm, nw, c), :qsw, Dict()); _PMs._check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
#     pt   = get(_PMs.var(pm, nw, c),  :pt, Dict()); _PMs._check_var_keys(pt, bus_arcs_trans, "active power", "transformer")
#     qt   = get(_PMs.var(pm, nw, c),  :qt, Dict()); _PMs._check_var_keys(qt, bus_arcs_trans, "reactive power", "transformer")
#     pd   = get(_PMs.var(pm, nw, c),  :pd, Dict()); _PMs._check_var_keys(pd, bus_loads, "active power", "load")
#     qd   = get(_PMs.var(pm, nw, c),  :qd, Dict()); _PMs._check_var_keys(pd, bus_loads, "reactive power", "load")
#
#     _PMs.con(pm, nw, c, :kcl_p)[i] = JuMP.@NLconstraint(pm.model,
#         sum(p[a] for a in bus_arcs)
#         + sum(psw[a_sw] for a_sw in bus_arcs_sw)
#         + sum(pt[a_trans] for a_trans in bus_arcs_trans)
#         ==
#         sum(pg[g] for g in bus_gens)
#         - sum(ps[s] for s in bus_storage)
#         - sum(pd[l] for l in bus_loads)
#         - sum(gs for gs in values(bus_gs))*vm^2
#     )
#     _PMs.con(pm, nw, c, :kcl_q)[i] = JuMP.@NLconstraint(pm.model,
#         sum(q[a] for a in bus_arcs)
#         + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
#         + sum(qt[a_trans] for a_trans in bus_arcs_trans)
#         ==
#         sum(qg[g] for g in bus_gens)
#         - sum(qs[s] for s in bus_storage)
#         - sum(qd[l] for l in bus_loads)
#         + sum(bs for bs in values(bus_bs))*vm^2
#     )
# end
