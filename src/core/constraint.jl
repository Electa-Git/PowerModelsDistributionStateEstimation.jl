"""
    constraint_mc_residual for power flow equations
"""
function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int;
                                nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    cmp_id = _PMs.ref(pm, nw, :meas, i, "cmp_id")
    _PMD.ref(pm, nw, :meas, i, "cmp") == :branch ? id = (cmp_id, _PMD.ref(pm,nw,:branch, cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,cmp_id)["t_bus"]) : id = _PMs.ref(pm, nw, :meas, i, "cmp_id")
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
            JuMP.register(pm.model, f,1,distr,grd,hes)
            JuMP.add_NL_constraint(pm.model,
                :($(res[c]) == - $(f)($(var[c]))) #NB The 100 is put in place to avoid that ρ goes negative
            )
        else
            error("State estimation criterion is not properly defined: wls and wlav only work with normal distribution")
        end
    end
end
