""
function constraint_mc_residual(pm::_PMs.AbstractPowerModel, nw::Int, i::Int)

    res = _PMs.var(pm, nw, :res, i)
    var = _PMs.var(pm, nw, _PMs.ref(pm, nw, :meas, i, "var"),
                           _PMs.ref(pm, nw, :meas, i, "id"))
    dst = _PMs.ref(pm, nw, :meas, i, "dst")

    for c in _PMs.conductor_ids(pm; nw=nw)
        if typeof(dst[c]) == Nothing
            JuMP.@constraint(pm.model,
                res[c] == 0.0
            )
        elseif typeof(dst[c]) == Float64
            JuMP.@constraint(pm.model,
                var[c] == dst[c]
            )
            JuMP.@constraint(pm.model,
                res[c] == 0.0
            )
        elseif typeof(dst[c]) == Normal{Float64}
            if pm.setting["estimation_criterion"] == "wls"
                JuMP.@constraint(pm.model,
                    res[c] == (var[c]-_DST.mean(dst[c]))^2/_DST.var(dst[c])
                )
            elseif pm.setting["estimation_criterion"] == "wlav"
                JuMP.@constraint(pm.model,
                    res[c] >= (var[c]-_DST.mean(dst[c]))/_DST.var(dst[c])
                )
                JuMP.@constraint(pm.model,
                    res[c] >= -(var[c]-_DST.mean(dst[c]))/_DST.var(dst[c])
                )
            end
        else
            @warn "Currently, only Gaussian distributions are supported."
            # JuMP.set_lower_bound(var[c],_DST.minimum(dst[c]))
            # JuMP.set_upper_bound(var[c],_DST.maximum(dst[c]))
            # dst(x) = -_DST.logpdf(dst[c],x)
            # grd(x) = -_DST.gradlogpdf(dst[c],x)
            # hes(x) = -_DST.heslogpdf(dst[c],x) # doesn't exist yet
            # register(pm.model,Symbol("df_$(m)_$(c)"),1,dst,grd,hes)
            # Expr(:call, :myf, [x[i] for i=1:n]...)
            # https://stackoverflow.com/questions/44710900/juliajump-variable-number-of-arguments-to-function
            # JuMP.@NLconstraint(pm.model,res[c] == Expr(:call, Symbol("df_$(m)_$(c)"), var[c])
        end
    end
end
