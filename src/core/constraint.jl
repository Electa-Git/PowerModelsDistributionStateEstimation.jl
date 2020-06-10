"""
    constraint_mc_residual for polar and rectangular power flow equations
"""
function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int;
                                nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    var, res_corr = make_uniform_variable_space(pm, i; nw=nw)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    rsc = _PMD.ref(pm, nw, :setting)["weight_rescaler"]
    nph = 3

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
                JuMP.@constraint(pm.model,
                    res[c] == (var[c]-_DST.mean(dst[c])^res_corr)^2/(_DST.std(dst[c])*rsc)^2
                )
            elseif _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wlav"
                JuMP.@constraint(pm.model,
                    res[c] >= (var[c]-_DST.mean(dst[c])^res_corr)/(_DST.std(dst[c])*rsc)
                )
                JuMP.@constraint(pm.model,
                    res[c] >= -(var[c]-_DST.mean(dst[c])^res_corr)/(_DST.std(dst[c])*rsc)
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

# """
#     constraint_mc_residual, IVR version
# """
# function constraint_mc_residual(pm::_PMs.AbstractIVRModel, i::Int;
#                                 nw::Int=pm.cnw)
#     res = _PMD.var(pm, nw, :res, i)
#     dst = _PMD.ref(pm, nw, :meas, i, "dst")
#     rsc = _PMD.ref(pm, nw, :setting)["weight_rescaler"]
#     nph = 3
#     σ = [1.0 1.0 1.0]
#     z = [0.0 0.0 0.0]
#     #NB I need to register the following expressions to include them in jump constraints
#     for c in 1:nph σ[c] = _DST.std(dst[c])*rsc end
#     for c in 1:nph z[c] = _DST.mean(dst[c]) end
#
#     if _PMD.ref(pm, nw, :meas, i, "var") == :vm
#         vi = _PMD.var(pm, nw, :vi, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
#         vr = _PMD.var(pm, nw, :vr, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
#         expr = JuMP.@NLexpression( pm.model, [c in 1:nph], vi[c]^2+vr[c]^2 )
#     elseif _PMD.ref(pm, nw, :meas, i, "var") == :pg || _PMD.ref(pm, nw, :meas, i, "var") == :qg
#         bus_id = _PMD.ref(pm, nw, :gen, _PMD.ref(pm, nw, :meas, i, "cmp_id"), "gen_bus")
#         # TODO: This seems like a lot of duplicate code, suggestion (see issue), return an expression for the var, similar for everything that follows!
#         vr = _PMD.var(pm, nw, :vr, bus_id)
#         vi = _PMD.var(pm, nw, :vi, bus_id)
#         crg = _PMD.var(pm, nw, :crg, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
#         cig = _PMD.var(pm, nw, :cig, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
#         if _PMD.ref(pm, nw, :meas, i, "var") == :pg
#             expr = JuMP.@NLexpression(pm.model, [c in 1:nph], vr[c]*crg[c]+vi[c]*cig[c])
#         elseif  _PMD.ref(pm, nw, :meas, i, "var") == :qg
#             expr = JuMP.@NLexpression(pm.model, [c in 1:nph], -vr[c]*cig[c]+vi[c]*crg[c])
#         end
#     end
#     if _PMD.ref(pm, nw, :meas, i, "var") == :vm
#         for c in _PMD.conductor_ids(pm; nw=nw)
#             if typeof(dst[c]) == Float64
#                 JuMP.@NLconstraint(pm.model,
#                     expr[c] == dst[c]^2
#                 )
#                 JuMP.@constraint(pm.model,
#                     res[c] == 0.0
#                 )
#             elseif typeof(dst[c]) == _DST.Normal{Float64}
#                 if  _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wls"
#                     JuMP.@NLconstraint(pm.model,
#                         res[c] == (expr[c]-z[c]^2)^2/σ[c]^2
#                     )
#                 elseif _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wlav"
#                     JuMP.@NLconstraint(pm.model,
#                         res[c] >= (expr[c]-z[c]^2)/σ[c]
#                     )
#                     JuMP.@NLconstraint(pm.model,
#                         res[c] >= -(expr[c]-z[c]^2)/σ[c]
#                     )
#                 end
#             else
#                 @warn "Currently, only Gaussian distributions are supported."
#                 # JuMP.set_lower_bound(var[c],_DST.minimum(dst[c]))
#                 # JuMP.set_upper_bound(var[c],_DST.maximum(dst[c]))
#                 # dst(x) = -_DST.logpdf(dst[c],x)
#                 # grd(x) = -_DST.gradlogpdf(dst[c],x)
#                 # hes(x) = -_DST.heslogpdf(dst[c],x) # doesn't exist yet
#                 # register(pm.model,Symbol("df_$(i)_$(c)"),1,dst,grd,hes)
#                 # Expr(:call, :myf, [x[i] for i=1:n]...)
#                 # https://stackoverflow.com/questions/44710900/juliajump-variable-number-of-arguments-to-function
#                 # JuMP.@NLconstraint(pm.model,
#                 #     res[c] == Expr(:call, Symbol("df_$(i)_$(c)"), var[c]
#                 # )
#             end
#         end
#     elseif _PMD.ref(pm, nw, :meas, i, "var") == :pg || _PMD.ref(pm, nw, :meas, i, "var") == :qg
#
#        for c in _PMD.conductor_ids(pm; nw=nw)
#            if typeof(dst[c]) == Float64
#                JuMP.@NLconstraint(pm.model,
#                    expr[c] == dst[c]
#                )
#                JuMP.@constraint(pm.model,
#                    res[c] == 0.0
#                )
#            elseif typeof(dst[c]) == _DST.Normal{Float64}
#                if _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wls"
#                    JuMP.@NLconstraint(pm.model,
#                        res[c] == (expr[c]-z[c])^2/σ[c]^2
#                    )
#                elseif _PMD.ref(pm, nw, :setting)["estimation_criterion"] == "wlav"
#                    JuMP.@NLconstraint(pm.model,
#                        res[c] >= (expr[c]-z[c])/σ[c]
#                    )
#                    JuMP.@NLconstraint(pm.model,
#                        res[c] >= -(expr[c]-z[c])/σ[c]
#                    )
#                end
#            else
#                @warn "Currently, only Gaussian distributions are supported."
#                # JuMP.set_lower_bound(var[c],_DST.minimum(dst[c]))
#                # JuMP.set_upper_bound(var[c],_DST.maximum(dst[c]))
#                # dst(x) = -_DST.logpdf(dst[c],x)
#                # grd(x) = -_DST.gradlogpdf(dst[c],x)
#                # hes(x) = -_DST.heslogpdf(dst[c],x) # doesn't exist yet
#                # register(pm.model,Symbol("df_$(i)_$(c)"),1,dst,grd,hes)
#                # Expr(:call, :myf, [x[i] for i=1:n]...)
#                # https://stackoverflow.com/questions/44710900/juliajump-variable-number-of-arguments-to-function
#                # JuMP.@NLconstraint(pm.model,
#                #     res[c] == Expr(:call, Symbol("df_$(i)_$(c)"), var[c]
#                # )
#            end
#         end
#     end
# end
