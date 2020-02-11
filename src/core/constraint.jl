# function constraint_mc_residual(pm::_PMs.AbstractPowerModel, i::Int)
#
# # Design-choice: split the residuals in their respective parts, i.e., p, q and
# # vm. This introduces a significant number of extra variables and constraints
# # which might not be necessary, as they will equal zero and which are not
# # elimated as Ipopt does not have a presolve. It might be better from a
# # computational perspective to do this using a single variable res. Anyway k-bye
# # This constraint is for the absolute basecase, i.e., it does not containt the
# # variables for storage and transformers.
#
#
#
#     # res     = get(_PMs.var(pm, nw, c), :res, Dict())
#     # res_p   =
#     # res_q   =
#     # res_v   =
#     #
#     #
#     # _PMs.con(pm, nw, c, :res_ovr)[i] = JuMP.@constraint(pm.model,
#     #     res == res_p + res_q + res_v
#     # )
#     # if isa(x,Normal)
#     #
#     # else
#     #     @warn "Currently, only Gaussian distributions are included. Consequently,
#     #            no contraints are for bus $i, i.e., the bus will be considered as
#     #            a zero-injection bus."
#     #     ## -logpdf(distₓ,X)
#     # end
#     # _PMs.con(pm, nw, c, :res_ovr)[i] = JuMP.@constraint(pm.model,
#     #     res == res_p + res_q + res_v
#     # )
#     #
#     # if res_type == "wls"
#     # _PMs.con(pm, nw, c, :res_wls)[i] = JuMP.@NLconstraint(pm.model,
#     #     res == sum(-logpdf(x,Y)             for x in X if !isa(x,Normal))
#     #          + sum((Y - mean(x))^2/var(x))  for x in X if isa(x,Normal))
#     # )
#     # end
#     # if res_type == "wlav"
#     # _PMs.con(pm, nw, c, :res_wlav_a)[i] = JuMP.@NLconstraint(pm.model,
#     #     res >= sum(-logpdf(x,Y)             for x in X if !isa(x,Normal))
#     #          + sum((Y - mean(x)/var(x))     for x in X if isa(x,Normal))
#     # )
#     # _PMs.con(pm, nw, c, :res_wlav_b)[i] = JuMP.@NLconstraint(pm.model,
#     #     res >= sum(-logpdf(x,Y)             for x in X if !isa(x,Normal))
#     #          - sum((Y - mean(x))/var(x)     for x in X if isa(x,Normal))
#     # )
#     # end
#
# end
