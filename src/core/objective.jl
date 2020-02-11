"minimal residual of the state estimator"
function objective_mc_se(pm::_PMs.AbstractPowerModel)
    return @objective(pm.model, Min,
    sum(
        sum(
            sum( var(pm, n, c, :res, i) for i in _PMs.ids(pm, :bus) )
        for c in _PMs.conductor_ids(pm, n) )
    for (n, nw_ref) in _PMs.nws(pm) )
    )
end
