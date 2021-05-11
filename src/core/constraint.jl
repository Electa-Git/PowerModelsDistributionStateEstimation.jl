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

    cmp_id = get_cmp_id(pm, nw, i)
    res = _PMD.var(pm, nw, :res, i)
    var = _PMs.var(pm, nw, _PMs.ref(pm, nw, :meas, i, "var"), cmp_id)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :se_settings)["rescaler"]
    crit = _PMD.ref(pm, nw, :meas, i, "crit")
    conns = get_active_connections(pm, nw, _PMD.ref(pm, nw, :meas, i, "cmp"), cmp_id)

    for (idx, c) in enumerate(conns)
        if isa(dst[idx], Float64)
            JuMP.@constraint(pm.model, var[c] == dst[idx])
            JuMP.@constraint(pm.model, res[idx] == 0.0)
        elseif crit == "wls" && isa(dst[idx], _DST.Normal)
            μ, σ = _DST.mean(dst[idx]), _DST.std(dst[idx])
            JuMP.@constraint(pm.model,
                res[idx] == (var[c] - μ)^2 / σ^2 / rsc
            )
        elseif crit == "rwls" && isa(dst[idx], _DST.Normal)
            μ, σ = _DST.mean(dst[idx]), _DST.std(dst[idx])
            JuMP.@constraint(pm.model,
                res[idx] * rsc * σ^2 >= (var[c] - μ)^2
            )
        elseif crit == "wlav" && isa(dst[idx], _DST.Normal)
            μ, σ = _DST.mean(dst[idx]), _DST.std(dst[idx])
            JuMP.@NLconstraint(pm.model,
                res[idx] == abs(var[c] - μ) / σ / rsc
            )
        elseif crit == "rwlav" && isa(dst[idx], _DST.Normal)
            μ, σ = _DST.mean(dst[idx]), _DST.std(dst[idx])
            JuMP.@constraint(pm.model,
                res[idx] >= (var[c] - μ) / σ / rsc
            )
            JuMP.@constraint(pm.model,
                res[idx] >= - (var[c] - μ) / σ / rsc
            )
        elseif crit == "mle"
            ( isa(dst[idx], ExtendedBeta{Float64}) || isa(dst[idx], _GMM.GMM) ) ? pkg_id = _PMDSE : pkg_id = _DST
            ( !isa(dst[idx], _GMM.GMM) && !isinf(pkg_id.minimum(dst[idx])) ) ? lb = pkg_id.minimum(dst[idx]) : lb = -10
            ( !isa(dst[idx], _GMM.GMM) && !isinf(pkg_id.maximum(dst[idx])) ) ? ub = pkg_id.maximum(dst[idx]) : ub = 10
            if isa(dst[idx], _GMM.GMM) lb = _PMD.ref(pm, nw, :meas, i, "min") end
            if isa(dst[idx], _GMM.GMM) ub = _PMD.ref(pm, nw, :meas, i, "max") end
            
            shf = abs(Optim.optimize(x -> -pkg_id.logpdf(dst[idx],x),lb,ub).minimum)
            f = Symbol("df_",i,"_",c)

            fun(x) = rsc * ( - shf + pkg_id.logpdf(dst[idx],x) )
            grd(x) = pkg_id.gradlogpdf(dst[idx],x)
            hes(x) = heslogpdf(dst[idx],x)
            JuMP.register(pm.model, f, 1, fun, grd, hes)
            JuMP.add_NL_constraint(pm.model, :($(res[idx]) == - $(f)($(var[c]))))
        else
            error("SE criterion of measurement $(i) not recognized")
        end
    end
end
