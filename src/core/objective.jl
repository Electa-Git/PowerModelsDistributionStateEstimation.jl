################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
"""
    objective_mc_se
"""
function objective_mc_se(pm::_PMs.AbstractPowerModel)
    return JuMP.@objective(pm.model, Min,
    sum(
        sum(
            sum(_PMs.var(pm, nw, :res, i)[idx] for idx in 1:length(_PMs.var(pm, nw, :res, i)) )
        for i in _PMs.ids(pm, nw, :meas))
    for (nw, nw_ref) in _PMs.nws(pm) )
    )
end
