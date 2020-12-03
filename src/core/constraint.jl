################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

"""
    constraint_mc_residual

Equality constraint that describes the residual definition, which depends on the chosen criterion
in data["se_settings"]["criterion"].
"""

function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    cmp_id = get_cmp_id(pm, nw, i)
    var = _PMs.var(pm, nw, _PMs.ref(pm, nw, :meas, i, "var"), cmp_id)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :se_settings)["rescaler"]
    criterion = _PMD.ref(pm, nw, :se_settings)["criterion"]
    criterion == "mixed" ? crit = _PMD.ref(pm, nw, :meas, i, "crit") : crit = criterion

    for c in _PMD.conductor_ids(pm; nw=nw)
        if isa(dst[c], Float64)
            JuMP.@constraint(pm.model, var[c] == dst[c])
            JuMP.@constraint(pm.model, res[c] == 0.0)
        elseif isa(dst[c], _DST.Normal) && crit ≠ "mle"
            μ, σ = _DST.mean(dst[c]), _DST.std(dst[c])
            if crit == "wls"
                JuMP.@constraint(pm.model,
                    res[c] == (var[c] - μ)^2 / σ^2 / rsc
                )
            elseif crit == "rwls"
                JuMP.@constraint(pm.model,
                    res[c] * rsc * σ^2 >= (var[c] - μ)^2
                )
            elseif crit == "wlav"
                JuMP.@NLconstraint(pm.model,
                    res[c] == abs(var[c] - μ) / σ / rsc
                )
            elseif crit == "rwlav"
                JuMP.@constraint(pm.model,
                    res[c] >= (var[c] - μ) / σ / rsc
                )
                JuMP.@constraint(pm.model,
                    res[c] >= - (var[c] - μ) / σ / rsc
                )
            else
                Memento.error(_LOGGER, "State estimation criterion not recognized")
            end
        elseif crit == "mle" && !isa(dst[c], Float64)
            typeof(dst[c]) == ExtendedBeta{Float64} ? pkg_id = _PMDSE : pkg_id = _DST
            minimum(dst[c]) > -Inf ? lb = minimum(dst[c]) : lb = -10
            maximum(dst[c]) <  Inf ? ub = maximum(dst[c]) : ub = 10
            shf = abs(Optim.optimize(x -> -pkg_id.logpdf(dst[c],x),lb,ub).minimum)
            f = Symbol("df_",i,"_",c)

            fun(x) = rsc * ( - shf + pkg_id.logpdf(dst[c],x) )
            grd(x) = pkg_id.gradlogpdf(dst[c],x)
            hes(x) = heslogpdf(dst[c],x)
            JuMP.register(pm.model, f, 1, fun, grd, hes)
            JuMP.add_NL_constraint(pm.model, :($(res[c]) == - $(f)($(var[c]))))
        else
            Memento.error(_LOGGER, "State estimation criterion not recognized")
        end
    end
end
