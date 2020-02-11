# "KCL including transformer arcs and load variables."
# function constraint_mc_power_balance_se(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
#     for cnd in _PMs.conductor_ids(pm; nw=nw)
#         if !haskey(_PMs.con(pm, nw, cnd), :kcl_p)
#             _PMs.con(pm, nw, cnd)[:kcl_p] = Dict{Int,JuMP.ConstraintRef}()
#         end
#         if !haskey(_PMs.con(pm, nw, cnd), :kcl_q)
#             _PMs.con(pm, nw, cnd)[:kcl_q] = Dict{Int,JuMP.ConstraintRef}()
#         end
#
#         bus = _PMs.ref(pm, nw, :bus, i)
#         bus_arcs = _PMs.ref(pm, nw, :bus_arcs, i)
#         bus_arcs_sw = _PMs.ref(pm, nw, :bus_arcs_sw, i)
#         bus_arcs_trans = _PMs.ref(pm, nw, :bus_arcs_trans, i)
#         bus_gens = _PMs.ref(pm, nw, :bus_gens, i)
#         bus_storage = _PMs.ref(pm, nw, :bus_storage, i)
#         bus_loads = _PMs.ref(pm, nw, :bus_loads, i)
#         bus_shunts = _PMs.ref(pm, nw, :bus_shunts, i)
#
#         bus_gs = Dict(k => _PMs.ref(pm, nw, :shunt, k, "gs", cnd) for k in bus_shunts)
#         bus_bs = Dict(k => _PMs.ref(pm, nw, :shunt, k, "bs", cnd) for k in bus_shunts)
#
#         constraint_mc_power_balance_load_se(pm, nw, cnd, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
#     end
# end
#
# function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
#     for cnd in _PMs.conductor_ids(pm; nw = nw)
#
#         constraint_mc_residual(pm, nw, cnd, i, )
#     end
# end
