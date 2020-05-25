""
#TODO:deprecated?
function constraint_mc_load(pm::_PMs.AbstractPowerModel, i::Int;
                            nw::Int=pm.cnw, report::Bool=true)
    _PMs.var(pm, nw, :pd_bus)[i] = _PMs.var(pm, nw, :pd, i)
    _PMs.var(pm, nw, :qd_bus)[i] = _PMs.var(pm, nw, :qd, i)

    if report
        _PMs.sol(pm, nw, :load, i)[:pd_bus] = _PMs.var(pm, nw, :pd_bus, i)
        _PMs.sol(pm, nw, :load, i)[:qd_bus] = _PMs.var(pm, nw, :qd_bus, i)
    end
end


"""
    constraint_mc_residual
"""
function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int;
                                nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    var = _PMD.var(pm, nw, _PMD.ref(pm, nw, :meas, i, "var"),
                           _PMD.ref(pm, nw, :meas, i, "cmp_id"))
    dst = _PMD.ref(pm, nw, :meas, i, "dst")

    for c in _PMD.conductor_ids(pm; nw=nw)
        if typeof(dst[c]) == Float64
            JuMP.@constraint(pm.model,
                var[c] == dst[c]
            )
            JuMP.@constraint(pm.model,
                res[c] == 0.0
            )
        elseif typeof(dst[c]) == _DST.Normal{Float64}
            if pm.setting["estimation_criterion"] == "wls"
                JuMP.@constraint(pm.model,
                    res[c] == (var[c]-_DST.mean(dst[c]))^2/_DST.var(dst[c])^2
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
            # register(pm.model,Symbol("df_$(i)_$(c)"),1,dst,grd,hes)
            # Expr(:call, :myf, [x[i] for i=1:n]...)
            # https://stackoverflow.com/questions/44710900/juliajump-variable-number-of-arguments-to-function
            # JuMP.@NLconstraint(pm.model,
            #     res[c] == Expr(:call, Symbol("df_$(i)_$(c)"), var[c]
            # )
        end
    end
end

function constraint_mc_residual(pm::_PMs.AbstractIVRModel, i::Int;
                                nw::Int=pm.cnw)

    res = _PMD.var(pm, nw, :res, i)
    dst = _PMD.ref(pm, nw, :meas, i, "dst")
    display(_PMD.ref(pm, nw, :meas, i, "var"))

    if _PMD.ref(pm, nw, :meas, i, "var") == :vm
        vi = _PMD.var(pm, nw, :vi, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
        vr = _PMD.var(pm, nw, :vr, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
        for c in _PMD.conductor_ids(pm; nw=nw)
            if typeof(dst[c]) == Float64
                JuMP.@constraint(pm.model,
                    (vi[c]^2+vr[c]^2) == dst[c]^2
                )
                JuMP.@constraint(pm.model,
                    res[c] == 0.0
                )
            elseif typeof(dst[c]) == _DST.Normal{Float64}
                if pm.setting["estimation_criterion"] == "wls"
                    JuMP.@constraint(pm.model,
                        res[c] == (vi[c]^2+vr[c]^2-_DST.mean(dst[c])^2)^2/_DST.var(dst[c])^2
                    )
                elseif pm.setting["estimation_criterion"] == "wlav"
                    JuMP.@constraint(pm.model,
                        res[c] >= (vi[c]^2+vr[c]^2-_DST.mean(dst[c])^2)/_DST.var(dst[c])
                    )
                    JuMP.@constraint(pm.model,
                        res[c] >= -(vi[c]^2+vr[c]^2-_DST.mean(dst[c])^2)/_DST.var(dst[c])
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
    elseif _PMD.ref(pm, nw, :meas, i, "var") == :pg
        bus_id = _PMD.ref(pm, nw, :gen, _PMD.ref(pm, nw, :meas, i, "cmp_id"), "gen_bus")
        display(bus_id)
        vr = _PMD.var(pm, nw, :vr, bus_id)
        vi = _PMD.var(pm, nw, :vi, bus_id)
        crg = _PMD.var(pm, nw, :crg, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
        cig = _PMD.var(pm, nw, :cig, _PMD.ref(pm, nw, :meas, i, "cmp_id"))

       for c in _PMD.conductor_ids(pm; nw=nw)
           if typeof(dst[c]) == Float64
               JuMP.@constraint(pm.model,
                   vr[c]*crg[c]+vi[c]*cig[c] == dst[c]
               )
               JuMP.@constraint(pm.model,
                   res[c] == 0.0
               )
           elseif typeof(dst[c]) == _DST.Normal{Float64}
               if pm.setting["estimation_criterion"] == "wls"
                   JuMP.@constraint(pm.model,
                       res[c] == (vr[c]*crg[c]+vi[c]*cig[c]-_DST.mean(dst[c]))^2/_DST.var(dst[c])^2
                   )
               elseif pm.setting["estimation_criterion"] == "wlav"
                   JuMP.@constraint(pm.model,
                       res[c] >= (vr[c]*crg[c]+vi[c]*cig[c]-_DST.mean(dst[c]))/_DST.var(dst[c])
                   )
                   JuMP.@constraint(pm.model,
                       res[c] >= -(vr[c]*crg[c]+vi[c]*cig[c]-_DST.mean(dst[c]))/_DST.var(dst[c])
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
       elseif _PMD.ref(pm, nw, :meas, i, "var") == :qg
           bus_id = _PMD.ref(pm, nw, :gen, _PMD.ref(pm, nw, :meas, i, "cmp_id"), "gen_bus")
           display(bus_id)
           vr = _PMD.var(pm, nw, :vr, bus_id)
           vi = _PMD.var(pm, nw, :vi, bus_id)
           crg = _PMD.var(pm, nw, :crg, _PMD.ref(pm, nw, :meas, i, "cmp_id"))
           cig = _PMD.var(pm, nw, :cig, _PMD.ref(pm, nw, :meas, i, "cmp_id"))

          for c in _PMD.conductor_ids(pm; nw=nw)
              if typeof(dst[c]) == Float64
                  JuMP.@constraint(pm.model,
                      -vr[c]*cig[c]+vi[c]*crg[c] == dst[c]
                  )
                  JuMP.@constraint(pm.model,
                      res[c] == 0.0
                  )
              elseif typeof(dst[c]) == _DST.Normal{Float64}
                  if pm.setting["estimation_criterion"] == "wls"
                      JuMP.@constraint(pm.model,
                          res[c] == (-vr[c]*cig[c]+vi[c]*crg[c]-_DST.mean(dst[c]))^2/_DST.var(dst[c])^2
                      )
                  elseif pm.setting["estimation_criterion"] == "wlav"
                      JuMP.@constraint(pm.model,
                          res[c] >= (-vr[c]*cig[c]+vi[c]*crg[c]-_DST.mean(dst[c]))/_DST.var(dst[c])
                      )
                      JuMP.@constraint(pm.model,
                          res[c] >= -(-vr[c]*cig[c]+vi[c]*crg[c]-_DST.mean(dst[c]))/_DST.var(dst[c])
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
    end#TODO add same for :va, even though we don't use it
end
