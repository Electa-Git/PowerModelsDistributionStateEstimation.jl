################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsSE.jl                                                             #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
"""
    objective_mc_se
"""
# Tom's remarks
# 1) Is this the most general way of doing this? Because in this case a residual
#    needs to be present for each of the conductors, which is not necessarily
#    the case.
function objective_mc_se(pm::_PMs.AbstractPowerModel)
    return JuMP.@objective(pm.model, Min,
    sum(
        sum(
            sum(_PMs.var(pm, n, :res, i)[c] for i in _PMs.ids(pm, n, :meas))
        for c in _PMs.conductor_ids(pm, n) )
    for (n, nw_ref) in _PMs.nws(pm) )
    )
end
