"minimal residual of the state estimator"
function objective_mc_se(pm::_PMs.AbstractPowerModel)
    return @objective(pm.model, Min,
    sum(
        sum(
            sum( _PMs.var(pm, n, Symbol("res_$(m)"), i)[c] for i in _PMs.ids(pm, :bus), m in metric() )
            sum( _PMs.var(pm, n, Symbol("res_$(m)"), i)[c] for g in _PMs.ids(pm, :gen), m in metric() )
            sum( _PMs.var(pm, n, Symbol("res_$(m)"), i)[c] for l in _PMs.ids(pm, :load), m in metric() )
        for c in _PMs.conductor_ids(pm, n) )
    for (n, nw_ref) in _PMs.nws(pm) )
    )
end
