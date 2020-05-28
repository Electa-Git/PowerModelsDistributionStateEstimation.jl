"""
    constraint_mc_residual, polar version (and rectangular?)
"""
function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int;
                                nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    var = _PMD.var(pm, nw, _PMD.ref(pm, nw, :meas, i, "var"),
                           _PMD.ref(pm, nw, :meas, i, "cmp_id"))
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :setting)["weight_rescaler"]

    for c in _PMD.conductor_ids(pm; nw=nw)
        if typeof(dst[c]) == Float64
            JuMP.@constraint(pm.model,
                var[c] == dst[c]
            )
            JuMP.@constraint(pm.model,
                res[c] == 0.0
            )
        elseif typeof(dst[c]) == _DST.Normal{Float64}
            if _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wls"
                JuMP.@NLconstraint(pm.model,
                    res[c] == (var[c]-_DST.mean(dst[c]))^2/(_DST.std(dst[c])*rsc)^2
                )
            elseif _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wlav"
                JuMP.@constraint(pm.model,
                    res[c] >= (var[c]-_DST.mean(dst[c]))/(_DST.std(dst[c])*rsc)
                )
                JuMP.@constraint(pm.model,
                    res[c] >= -(var[c]-_DST.mean(dst[c]))/(_DST.std(dst[c])*rsc)
                )
            end
        else
            @warn "Currently, only Gaussian distributions are supported."
            # JuMP.set_lower_bound(var[c],_DST.minimum(dst[c]))
            # JuMP.set_upper_bound(var[c],_DST.maximum(dst[c]))
            # dst(x) = -_DST.logpdf(dst[c],x)
            # grd(x) = -_DST.gradlogpdf(dst[c],x)
            # hes(x) = -_DST.heslogpdf(dst[c],x) # doesn't exist yet
            # register(pm.model,Symbol("df_$(i)_$(c)"),1,dst,grd,hes)
            # Expr(:call, :myf, [x[i] for i=1:n]...)
            # https://stackoverflow.com/questions/44710900/juliajump-variable-number-of-arguments-to-function
            # JuMP.@NLconstraint(pm.model,
            #     res[c] == Expr(:call, Symbol("df_$(i)_$(c)"), var[c]
            # )
        end
    end
end

"""
    constraint_mc_residual, IVR version
"""
function constraint_mc_residual(pm::_PMs.AbstractIVRModel, i::Int;
                                nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :setting)["weight_rescaler"]
    nph = 3

    if _PMD.ref(pm, nw, :meas, i, "var") == :vm
        vi = _PMD.var(pm, nw, :vi, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
        vr = _PMD.var(pm, nw, :vr, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
        expr = JuMP.@NLexpression( pm.model, [c in 1:nph], vi[c]^2+vr[c]^2 )
    elseif _PMD.ref(pm, nw, :meas, i, "var") == :pg || _PMD.ref(pm, nw, :meas, i, "var") == :qg
        bus_id = _PMD.ref(pm, nw, :gen, _PMD.ref(pm, nw, :meas, i, "cmp_id"), "gen_bus")
        vr = _PMD.var(pm, nw, :vr, bus_id)
        vi = _PMD.var(pm, nw, :vi, bus_id)
        crg = _PMD.var(pm, nw, :crg, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
        cig = _PMD.var(pm, nw, :cig, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
        if _PMD.ref(pm, nw, :meas, i, "var") == :pg
            expr = JuMP.@NLexpression(pm.model, [c in 1:nph], vr[c]*crg[c]+vi[c]*cig[c])
        elseif  _PMD.ref(pm, nw, :meas, i, "var") == :qg
            expr = JuMP.@NLexpression(pm.model, [c in 1:nph], -vr[c]*cig[c]+vi[c]*crg[c])
        end
    end
    if _PMD.ref(pm, nw, :meas, i, "var") == :vm
        for c in _PMD.conductor_ids(pm; nw=nw)
            if typeof(dst[c]) == Float64
                JuMP.@NLconstraint(pm.model,
                    expr[c] == dst[c]^2
                )
                JuMP.@constraint(pm.model,
                    res[c] == 0.0
                )
            elseif typeof(dst[c]) == _DST.Normal{Float64}
                if  _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wls"
                    JuMP.@NLconstraint(pm.model,
                        res[c] == (expr[c]-_DST.mean(dst[c])^2)^2/(_DST.std(dst[c])*rsc)^2
                    )
                elseif _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wlav"
                    JuMP.@NLconstraint(pm.model,
                        res[c] >= (expr[c]-_DST.mean(dst[c])^2)/(_DST.std(dst[c])*rsc)
                    )
                    JuMP.@NLconstraint(pm.model,
                        res[c] >= -(expr[c]-_DST.mean(dst[c])^2)/(_DST.std(dst[c])*rsc)
                    )
                end
            else
                @warn "Currently, only Gaussian distributions are supported."
                # JuMP.set_lower_bound(var[c],_DST.minimum(dst[c]))
                # JuMP.set_upper_bound(var[c],_DST.maximum(dst[c]))
                # dst(x) = -_DST.logpdf(dst[c],x)
                # grd(x) = -_DST.gradlogpdf(dst[c],x)
                # hes(x) = -_DST.heslogpdf(dst[c],x) # doesn't exist yet
                # register(pm.model,Symbol("df_$(i)_$(c)"),1,dst,grd,hes)
                # Expr(:call, :myf, [x[i] for i=1:n]...)
                # https://stackoverflow.com/questions/44710900/juliajump-variable-number-of-arguments-to-function
                # JuMP.@NLconstraint(pm.model,
                #     res[c] == Expr(:call, Symbol("df_$(i)_$(c)"), var[c]
                # )
            end
        end
    elseif _PMD.ref(pm, nw, :meas, i, "var") == :pg || _PMD.ref(pm, nw, :meas, i, "var") == :qg

       for c in _PMD.conductor_ids(pm; nw=nw)
           if typeof(dst[c]) == Float64
               JuMP.@NLconstraint(pm.model,
                   expr[c] == dst[c]
               )
               JuMP.@constraint(pm.model,
                   res[c] == 0.0
               )
           elseif typeof(dst[c]) == _DST.Normal{Float64}
               if _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wls"
                   JuMP.@NLconstraint(pm.model,
                       res[c] == (expr[c]-_DST.mean(dst[c]))^2/(_DST.std(dst[c])*rsc)^2
                   )
               elseif _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wlav"
                   JuMP.@NLconstraint(pm.model,
                       res[c] >= (expr[c]-_DST.mean(dst[c]))/(_DST.std(dst[c])*rsc)
                   )
                   JuMP.@NLconstraint(pm.model,
                       res[c] >= -(expr[c]-_DST.mean(dst[c]))/(_DST.std(dst[c])*rsc)
                   )
               end
           else
               @warn "Currently, only Gaussian distributions are supported."
               # JuMP.set_lower_bound(var[c],_DST.minimum(dst[c]))
               # JuMP.set_upper_bound(var[c],_DST.maximum(dst[c]))
               # dst(x) = -_DST.logpdf(dst[c],x)
               # grd(x) = -_DST.gradlogpdf(dst[c],x)
               # hes(x) = -_DST.heslogpdf(dst[c],x) # doesn't exist yet
               # register(pm.model,Symbol("df_$(i)_$(c)"),1,dst,grd,hes)
               # Expr(:call, :myf, [x[i] for i=1:n]...)
               # https://stackoverflow.com/questions/44710900/juliajump-variable-number-of-arguments-to-function
               # JuMP.@NLconstraint(pm.model,
               #     res[c] == Expr(:call, Symbol("df_$(i)_$(c)"), var[c]
               # )
           end
        end
    end
end
