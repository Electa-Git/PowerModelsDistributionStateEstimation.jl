################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

"""
    constraint_mc_residual

Equality constraint that describes the residual definition, which depends on the
criterion assigned to each individual measurement in data["meas"]["m"]["crit"].
"""

function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    cmp_id = get_cmp_id(pm, nw, i)
    var = _PMs.var(pm, nw, _PMs.ref(pm, nw, :meas, i, "var"), cmp_id)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :se_settings)["rescaler"]
    crit = _PMD.ref(pm, nw, :meas, i, "crit")

    for c in _PMD.conductor_ids(pm; nw=nw)
        if isa(dst[c], Float64)
            JuMP.@constraint(pm.model, var[c] == dst[c])
            JuMP.@constraint(pm.model, res[c] == 0.0)
        elseif crit == "wls" && isa(dst[c], _DST.Normal)
            μ, σ = _DST.mean(dst[c]), _DST.std(dst[c])
            JuMP.@constraint(pm.model,
                res[c] == (var[c] - μ)^2 / σ^2 / rsc
            )
        elseif crit == "rwls" && isa(dst[c], _DST.Normal)
            μ, σ = _DST.mean(dst[c]), _DST.std(dst[c])
            JuMP.@constraint(pm.model,
                res[c] * rsc * σ^2 >= (var[c] - μ)^2
            )
        elseif crit == "wlav" && isa(dst[c], _DST.Normal)
            μ, σ = _DST.mean(dst[c]), _DST.std(dst[c])
            JuMP.@NLconstraint(pm.model,
                res[c] == abs(var[c] - μ) / σ / rsc
            )
        elseif crit == "rwlav" && isa(dst[c], _DST.Normal)
            μ, σ = _DST.mean(dst[c]), _DST.std(dst[c])
            JuMP.@constraint(pm.model,
                res[c] >= (var[c] - μ) / σ / rsc
            )
            JuMP.@constraint(pm.model,
                res[c] >= - (var[c] - μ) / σ / rsc
            )
        elseif crit == "gmm"
            N   = _PMD.ref(pm, nw, :se_settings)["number_of_gaussian"]
            gmm = _GMM.GMM(N, rand(dst[c], 10000))
            gmv = _PMD.var(pm, nw, :gmv, i)
            JuMP.@constraint(pm.model,
                var[c] == sum(gmm.w[n] * gmv[c,n] for n in 1:N)
            )
            JuMP.@constraint(pm.model,
                res[c] >= sum(gmm.w[n] * (gmv[c,n] - gmm.μ[n]) / gmm.Σ[n] / rsc
                                        for n in 1:N)
            )
            JuMP.@constraint(pm.model,
                res[c] >= - sum(gmm.w[n] * (gmv[c,n] - gmm.μ[n]) / gmm.Σ[n] / rsc
                                        for n in 1:N)
            )
        elseif crit == "mle"
            isa(dst[c], ExtendedBeta{Float64}) ? pkg_id = _PMDSE : pkg_id = _DST
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
            Memento.error(_LOGGER, "SE criterion of measurement $(i) not recognized")
        end
    end
end
