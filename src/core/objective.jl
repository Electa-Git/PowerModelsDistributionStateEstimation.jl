"""
    objective_mc_se
"""
function objective_mc_se(pm::_PMs.AbstractPowerModel)
    return JuMP.@objective(pm.model, Min,
    sum(
        sum(
            sum(_PMs.var(pm, n, :res, i)[c] for i in _PMs.ids(pm, n, :meas))
        for c in _PMs.conductor_ids(pm, n) )
    for (n, nw_ref) in _PMs.nws(pm) )
    )
end
