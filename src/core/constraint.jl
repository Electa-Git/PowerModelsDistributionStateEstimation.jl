"""
    constraint_mc_residual for power flow equations
"""
# Tom's remarks:
# 1) Is there no cleaner call for (l,i,j)?
# 2) For the logpdf form the rescaler seems to be a ?tuple?, whereas, this does 
#    does not seem to be true for the gaussian.
# 3) The terms "rescaler" and "criterion" might be cleaner compared to 
#    "weight_rescaler" (2x the same word) and "estimation_criterion"
# 4) In general, one could also call the mean and std of a distribution dst, 
#    using dst.μ and dst.σ. This would reduce the amount of code. Alternatively,
#    these could be preallocated in the initial gaussian if clause.
# 5) I would prefer fun, in stead of distr in the logpdf part, as it is a 
#    probability density function.
# 6) The NB can be removed.
# 7) The last error does not make sense anymore.
# 8) The if/ifelse clauses could be shortened by pre-allocating some stuff.
# 9) Comparing types is preferably done using isa()
# 10) The implementation of the mixed criterion does not make a lot of sense. 
#     How is the gaussian criterion given in this case?
# 11) Is the Float64 necessary in the type checking of the normal. 
# 12) For the errors we should look into Memento.
function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int;
                                nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    id = _PMs.ref(pm, nw, :meas, i, "cmp_id")
    _PMD.ref(pm, nw, :meas, i, "cmp") == :branch ? id = (id, _PMD.ref(pm,nw,:branch, id)["f_bus"], _PMD.ref(pm,nw,:branch,id)["t_bus"]) : ~ ;
    var = _PMs.var(pm, nw, _PMs.ref(pm, nw, :meas, i, "var"), id)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :se_settings)["weight_rescaler"]
    for c in _PMD.conductor_ids(pm; nw=nw)
        if typeof(dst[c]) == Float64
            JuMP.@constraint(pm.model,
                var[c] == dst[c]
            )
            JuMP.@constraint(pm.model,
                res[c] == 0.0
            )
        elseif typeof(dst[c]) == _DST.Normal{Float64} && _PMD.ref(pm, nw, :se_settings)["estimation_criterion"] != "mle"
            if _PMD.ref(pm, nw, :se_settings)["estimation_criterion"] == "wls"
                JuMP.@constraint(pm.model,
                    res[c] == (var[c]-_DST.mean(dst[c]))^2 / (_DST.std(dst[c]) * rsc)^2
                )
            elseif _PMD.ref(pm, nw, :se_settings)["estimation_criterion"] == "rwls"
                    JuMP.@constraint(pm.model,
                        res[c] * (_DST.std(dst[c]) * rsc)^2 >= (var[c]-_DST.mean(dst[c]))^2
                    )
            elseif _PMD.ref(pm, nw, :se_settings)["estimation_criterion"] == "wlav"
                μ= _DST.mean(dst[c])
                σ = _DST.std(dst[c])
                JuMP.@NLconstraint(pm.model,
                    res[c] == abs(var[c]-μ) / σ / rsc
                )
            elseif _PMD.ref(pm, nw, :se_settings)["estimation_criterion"] == "rwlav"
                JuMP.@constraint(pm.model,
                    res[c] >= (var[c]-_DST.mean(dst[c])) / _DST.std(dst[c]) / rsc
                )
                JuMP.@constraint(pm.model,
                    res[c] >= -(var[c]-_DST.mean(dst[c])) / _DST.std(dst[c]) / rsc
                )
            else
                error("State estimation criterion not recognized")
            end
        elseif (_PMD.ref(pm, nw, :se_settings)["estimation_criterion"] == "mle" && typeof(dst[c]) != Float64) || (_PMD.ref(pm, nw, :se_settings)["estimation_criterion"] == "mixed" && typeof(dst[c]) ∉ [Float64, _DST.Normal{Float64}])
            distr(x) = - rsc[2] + rsc[1] * _DST.logpdf(dst[c],x)
            grd(x) = _DST.gradlogpdf(dst[c],x)
            hes(x) = heslogpdf(dst[c],x)
            f = Symbol("df_",i,"_",c)
            JuMP.register(pm.model, f, 1, distr, grd,hes)
            JuMP.add_NL_constraint(pm.model,
                :($(res[c]) == - $(f)($(var[c]))) #NB The 100 is put in place to avoid that ρ goes negative
            )
        else
            error("State estimation criterion is not properly defined: wls and wlav only work with normal distribution")
        end
    end
end

function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    cmp_id = _PMs.ref(pm, nw, :meas, i, "cmp_id")
    _PMD.ref(pm, nw, :meas, i, "cmp") == :branch ? id = (cmp_id, _PMD.ref(pm,nw,:branch, cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,cmp_id)["t_bus"]) : id = _PMs.ref(pm, nw, :meas, i, "cmp_id")
    var = _PMs.var(pm, nw, _PMs.ref(pm, nw, :meas, i, "var"), id)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :se_settings)["rescaler"]

    criterion = _PMD.ref(pm, nw, :se_settings)["criterion"]

    for c in _PMD.conductor_ids(pm; nw=nw)
        if isa(dst[c], Float64)
            JuMP.@constraint(pm.model, var[c] == dst[c])
            JuMP.@constraint(pm.model, res[c] == 0.0)
        elseif isa(dst[c], _DST.Normal) && criterion ≠ "mle" 
            μ, σ = _DST.mean(dst[c]), _DST.std(dst[c])
            if criterion == "wls"
                JuMP.@constraint(pm.model, 
                    res[c] == (var[c] - μ)^2 / (σ * rsc)^2
                )
            elseif criterion == "rwls"
                JuMP.@constraint(pm.model,
                    res[c] * (σ * rsc)^2 >= (var[c] - μ)^2
                )
            elseif criterion == "wlav"
                JuMP.@NLconstraint(pm.model,
                    res[c] == abs(var[c] - μ) / σ / rsc
                )
            elseif criterion == "rwlav"
                JuMP.@constraint(pm.model,
                    res[c] >= (var[c] - μ) / σ / rsc
                )
                JuMP.@constraint(pm.model,
                    res[c] >= - (var[c] - μ) / σ / rsc
                )
            else
                error("State estimation criterion not recognized")
            end
        elseif (criterion == "mle" && !isa(dst[c], Float64)) || (criterion == "mixed" && (!isa(dst[c],Float64) || !isa(dst[c],_DST.Normal)))
            f = Symbol("df_",i,"_",c)
            fun(x) = - rsc[2] + rsc[1] * _DST.logpdf(dst[c],x)
            grd(x) = _DST.gradlogpdf(dst[c],x)
            hes(x) = heslogpdf(dst[c],x)
            JuMP.register(pm.model, f, 1, distr, grd,hes)
            JuMP.add_NL_constraint(pm.model, :($(res[c]) == - $(f)($(var[c]))))
        else
            error("State estimation criterion not recognized")
        end
    end
end

