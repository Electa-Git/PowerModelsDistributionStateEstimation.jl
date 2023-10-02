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
function constraint_mc_residual(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=_IM.nw_id_default)

    cmp_id = get_cmp_id(pm, nw, i)
    res = _PMD.var(pm, nw, :res, i)
    var = _PMD.var(pm, nw, _PMD.ref(pm, nw, :meas, i, "var"), cmp_id)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :se_settings)["rescaler"]
    crit = _PMD.ref(pm, nw, :meas, i, "crit")
    conns = get_active_connections(pm, nw, _PMD.ref(pm, nw, :meas, i, "cmp"), cmp_id)

    for (idx, c) in enumerate(conns)
        if (occursin("ls", crit) || occursin("lav", crit)) && isa(dst[idx], _DST.Normal)
            μ, σ = occursin("w", crit) ? (_DST.mean(dst[idx]), _DST.std(dst[idx])) : (_DST.mean(dst[idx]), 1.0)
        end
        if isa(dst[idx], Float64)
            JuMP.@constraint(pm.model, var[c] == dst[idx])
            JuMP.@constraint(pm.model, res[idx] == 0.0)         
        elseif crit ∈ ["wls", "ls"] && isa(dst[idx], _DST.Normal)
            JuMP.@constraint(pm.model,
                res[idx] * rsc^2 * σ^2 == (var[c] - μ)^2 
            )
        elseif crit == "rwls" && isa(dst[idx], _DST.Normal)
            JuMP.@constraint(pm.model,
                res[idx] * rsc^2 * σ^2 >= (var[c] - μ)^2
            )
        elseif crit ∈ ["wlav", "lav"] && isa(dst[idx], _DST.Normal)
            JuMP.@NLconstraint(pm.model,
                res[idx] * rsc * σ == abs(var[c] - μ)
            )
        elseif crit == "rwlav" && isa(dst[idx], _DST.Normal)
            JuMP.@constraint(pm.model,
                res[idx] * rsc * σ >= (var[c] - μ) 
            )
            JuMP.@constraint(pm.model,
                res[idx] * rsc * σ >= - (var[c] - μ)
            )
        elseif crit == "mle"
            #TODO: enforce min and max in the meas dictionary and just with haskey make it optional for extendedbeta
            pkg_id = any([ dst[idx] isa d for d in [ExtendedBeta{Float64}, _Poly.Polynomial]]) ? _PMDSE : _DST
            lb = ( !isa(dst[idx], _DST.MixtureModel) && !isinf(pkg_id.minimum(dst[idx])) ) ? pkg_id.minimum(dst[idx]) : -10
            ub = ( !isa(dst[idx], _DST.MixtureModel) && !isinf(pkg_id.maximum(dst[idx])) ) ? pkg_id.maximum(dst[idx]) : 10
            if any([ dst[idx] isa d for d in [_DST.MixtureModel, _Poly.Polynomial]]) lb = _PMD.ref(pm, nw, :meas, i, "min") end
            if any([ dst[idx] isa d for d in [_DST.MixtureModel, _Poly.Polynomial]]) ub = _PMD.ref(pm, nw, :meas, i, "max") end
            
            shf = abs(Optim.optimize(x -> -pkg_id.logpdf(dst[idx],x),lb,ub).minimum)
            f = Symbol("df_",i,"_",c)

            fun(x) = rsc * ( - shf + pkg_id.logpdf(dst[idx],x) )
            grd(x) = pkg_id.gradlogpdf(dst[idx],x)
            hes(x) = heslogpdf(dst[idx],x)
            JuMP.register(pm.model, f, 1, fun, grd, hes)
            JuMP.add_nonlinear_constraint(pm.model, :($(res[idx]) == - $(f)($(var[c]))))
        else
            error("SE criterion of measurement $(i) not recognized")
        end
    end
end
