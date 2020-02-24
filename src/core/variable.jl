""
function variable_mc_residual(  pm::_PMs.AbstractPowerModel;
                                nw::Int=pm.cnw, report::Bool=true)
    cnds  = _PMs.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    res = _PMs.var(pm, nw)[:res] = Dict(m => JuMP.@variable(pm.model,
        [c in 1:ncnds], base_name = "res_$(i)"
        ) for i in _PMs.ids(pm, nw, :meas)
    )

    report && _PMs.sol_component_value(pm, nw, :meas, :res, _PMs.ids(pm, nw, :meas), res)
end
