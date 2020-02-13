""
function constraint_mc_residual(pm::_PMs.AbstractPowerModel, nw::Int, i::Int)
    ng = _PMs.ref(pm, nw, :bus_gens, i)
    nl = _PMs.ref(pm, nw, :bus_loads, i)

    constraint_mc_residual_bus(pm, nw, i)
    for g in ng constraint_mc_residual_gen(pm, nw, g) end
    for l in nl constraint_mc_residual_load(pm, nw, l) end
end


""
function constraint_mc_residual_bus(pm::_PMs.AbstractACPModel, nw::Int, i::Int)

    for m in metrics(pm, nw, :bus)
        var = _PMs.var(pm, nw, m, i)
        res = _PMs.var(pm, nw, Symbol("res_$(m)"), i)
        dst = _PMs.ref(pm, nw, :bus, i, "dst")

        for c in _PMs.conductor_ids(pm; nw=nw)
            if typeof(dst[m][c]) == Nothing # Can be eliminated if the res is no longer decleared for dst[c] == nothing
                JuMP.@constraint(pm.model,
                    res[c] == 0.0
                    )
            elseif typeof(dst[m][c]) == Normal{Float64}
                if pm.setting["estimation_criterion"] == "wls"
                    JuMP.@constraint(pm.model,
                        res[c] == (var[c]-_DST.mean(dst[m][c]))^2/_DST.var(dst[m][c])
                        )
                elseif pm.setting["estimation_criterion"] == "wlav"
                    JuMP.@constraint(pm.model,
                        res[c] >= (var[c]-_DST.mean(dst[m][c]))/_DST.var(dst[m][c])
                        )
                    JuMP.@constraint(pm.model,
                        res[c] >= -(var[c]-_DST.mean(dst[m][c]))/_DST.var(dst[m][c])
                        )
                end
            else
                @warn "Currently, only Gaussian distributions are supported."
            end
    end

end


""
function constraint_mc_residual_gen(pm::_PMs.AbstractACPModel, nw::Int, g::Int)

    for m in metrics(pm, nw, :gen)
        var = _PMs.var(pm, nw, m, g)
        res = _PMs.var(pm, nw, Symbol("res_$(m)"), g)
        dst = _PMs.ref(pm, nw, :gen, g, "dst")
        par = _PMs.ref(pm, nw, :gen, g, "$(m)")

        for c in _PMs.conductor_ids(pm; nw=nw)
            if typeof(dst[m][c]) == Nothing # Can be eliminated if the res is no longer decleared for dst[c] == nothing
                JuMP.@constraint(pm.model,
                    res[c] == 0.0
                    )
                JuMP.@constraint(pm.model,
                    var[c] == par[c]
                    )
            elseif typeof(dst[m][c]) == Normal{Float64}
                if pm.setting["estimation_criterion"] == "wls"
                    JuMP.@constraint(pm.model,
                        res[c] == (var[c]-_DST.mean(dst[m][c]))^2/_DST.var(dst[m][c])
                        )
                elseif pm.setting["estimation_criterion"] == "wlav"
                    JuMP.@constraint(pm.model,
                        res[c] >= (var[c]-_DST.mean(dst[m][c]))/_DST.var(dst[m][c])
                        )
                    JuMP.@constraint(pm.model,
                        res[c] >= -(var[c]-_DST.mean(dst[m][c]))/_DST.var(dst[m][c])
                        )
                end
            else
                @warn "Currently, only Gaussian distributions are supported."
            end
    end
end

""
function constraint_mc_residual_load(pm::_PMs.AbstractACPModel, nw::Int, l::Int)

    for m in metrics(pm, nw, :load)
        var = _PMs.var(pm, nw, m, l)
        res = _PMs.var(pm, nw, Symbol("res_$(m)"), l)
        dst = _PMs.ref(pm, nw, :gen, l, "dst")
        par = _PMs.ref(pm, nw, :gen, l, "$(m)")

        for c in _PMs.conductor_ids(pm; nw=nw)
            if typeof(dst[m][c]) == Nothing # Can be eliminated if the res is no longer decleared for dst[c] == nothing
                JuMP.@constraint(pm.model,
                    res[c] == 0.0
                    )
                JuMP.@constraint(pm.model,
                    var[c] == par[c]
                    )
            elseif typeof(dst[m][c]) == Normal{Float64}
                if pm.setting["estimation_criterion"] == "wls"
                    JuMP.@constraint(pm.model,
                        res[c] == (var[c]-_DST.mean(dst[m][c]))^2/_DST.var(dst[m][c])
                        )
                elseif pm.setting["estimation_criterion"] == "wlav"
                    JuMP.@constraint(pm.model,
                        res[c] >= (var[c]-_DST.mean(dst[m][c]))/_DST.var(dst[m][c])
                        )
                    JuMP.@constraint(pm.model,
                        res[c] >= -(var[c]-_DST.mean(dst[m][c]))/_DST.var(dst[m][c])
                        )
                end
            else
                @warn "Currently, only Gaussian distributions are supported."
            end
    end
end
