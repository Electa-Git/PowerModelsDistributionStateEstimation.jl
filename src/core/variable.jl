"Create variables for bus `active` and `reactive` power demand"
function variable_mc_demand(    pm::_PMs.AbstractPowerModel;
                                nw::Int=pm.cnw, kwargs...)
    for cnd in _PMs.conductor_ids(pm)
        _PMs.var(pm, nw, cnd)[:pd] = JuMP.@variable(pm.model,
            [i in _PMs.ids(pm, :bus)], base_name = "$(nw)_$(cnd)_pd")
        _PMs.var(pm, nw, cnd)[:qd] = JuMP.@variable(pm.model,
            [i in _PMs.ids(pm, :bus)], base_name = "$(nw)_$(cnd)_qd")
    end
end


"Create variables for ovr bus residuals and specific residuals for p, q and vm"
function variable_mc_residual(  pm::_PMs.AbstractPowerModel;
                                nw::Int=pm.cnw, kwargs...)
    for cnd in _PMs.conductor_ids(pm)
        _PMs.var(pm, nw, cnd)[:res] = @variable(pm.model,
            [i in _PMs.ids(pm, :bus)], base_name = "$(nw)_$(cnd)_res")
        _PMs.var(pm, nw, cnd)[:res_p] = @variable(pm.model,
            [i in _PMs.ids(pm, :bus)], base_name = "$(nw)_$(cnd)_res_p")
        _PMs.var(pm, nw, cnd)[:res_q] = @variable(pm.model,
            [i in _PMs.ids(pm, :bus)], base_name = "$(nw)_$(cnd)_res_q")
        _PMs.var(pm, nw, cnd)[:res_vm] = @variable(pm.model,
            [i in _PMs.ids(pm, :bus)], base_name = "$(nw)_$(cnd)_res_vm")
    end
end
