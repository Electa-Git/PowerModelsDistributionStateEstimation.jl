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
function objective_mc_se(pm::_PMD.AbstractPowerModel)
    return JuMP.@objective(pm.model, Min,
    sum(
        sum(
            sum(_PMD.var(pm, nw, :res, i)[idx] for idx in 1:length(_PMD.var(pm, nw, :res, i)) )
        for i in _PMD.ids(pm, nw, :meas))
    for (nw, nw_ref) in _PMD.nws(pm) )
    )
end
