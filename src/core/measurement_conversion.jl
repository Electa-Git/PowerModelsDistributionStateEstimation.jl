function make_uniform_variable_space(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    msr_var = _PMD.ref(pm, nw, :meas, i, "var")
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    nph=3
    if no_conversion_needed(pm, msr_var)  #just creates the variable, which is naturally available in the given power model
        original_var = _PMD.var(pm, nw, msr_var, cmp_id)
    else
        if haskey(_PMD.var(pm, nw), msr_var)
            push!(_PMD.var(pm, nw)[msr_var], cmp_id => JuMP.@variable(pm.model,
                [c in 1:nph], base_name="$(nw)_$(String(msr_var))_$cmp_id" ))
        else
            _PMD.var(pm, nw)[msr_var] = Dict(cmp_id => JuMP.@variable(pm.model,
                [c in 1:nph], base_name="$(nw)_$(String(msr_var))_$cmp_id" ))
        end
        original_var = _PMD.var(pm, nw)[msr_var][cmp_id]
        msr_type = assign_conversion_type_to_msr(pm, i, msr_var; nw=nw)
        create_conversion_constraint(pm, _PMD.var(pm, nw)[msr_var], msr_type; nw=nw, nph=nph)
    end
    return original_var
end

function no_conversion_needed(pm::_PMs.ACPPowerModel, msr_var::Symbol)
  return msr_var ∈ [:vm, :va, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMs.ACRPowerModel, msr_var::Symbol)
  return msr_var ∈ [:vr, :vi, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMs.IVRPowerModel, msr_var::Symbol)
  return msr_var ∈ [:vr, :vi, :cr, :ci, :crg, :cig, :crd, :cid]
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::SquareFraction; nw=nw, nph=3)

    new_var_num = []
    for nvn in msr.numerator
        if occursin("v", String(nvn)) && msr.cmp_type != :bus
            push!(new_var_num, _PMD.var(pm, nw, nvn, msr.bus_ind))
        elseif msr.cmp_type == :branch
            push!(new_var_num, _PMD.var(pm, nw, nvn, (msr.cmp_id, msr.bus_ind, _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"])))
        else
            push!(new_var_num, _PMD.var(pm, nw, nvn, msr.cmp_id))
        end
    end
    new_var_den = []
    for nvd in msr.denominator
        if typeof(nvd)!=:Symbol #only case is when I have an array of ones
            push!(new_var_den, nvd)
        elseif occursin("v", String(nvd)) && msr.cmp_type != :bus
            push!(new_var_den, _PMD.var(pm, nw, nvd, msr.bus_ind))
        else
            push!(new_var_den, _PMD.var(pm, nw, nvd, msr.cmp_id))
        end
    end
    JuMP.@constraint(pm.model, [c in 1:nph],
        original_var[msr.cmp_id][c]^2 == sum( n[c]^2 for n in new_var_num )/
                   sum( d[c]^2 for d in new_var_den)
        )
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::Multiplication; nw=nw, nph = 3)

    m1 = []
    m2 = []

    for m in msr.mult1
        if occursin("v", String(m)) && msr.cmp_type != :bus
            push!(m1, _PMD.var(pm, nw, m, msr.bus_ind))
        elseif msr.cmp_type == :branch
            push!(m1, _PMD.var(pm, nw, m, (msr.cmp_id, msr.bus_ind, _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"])))
        else
            push!(m1, _PMD.var(pm, nw, m, msr.cmp_id))
        end
    end

    for mm in msr.mult2
        if occursin("v", String(mm)) && msr.cmp_type != :bus
            push!(m2, _PMD.var(pm, nw, mm, msr.bus_ind))
        elseif msr.cmp_type == :branch
            push!(m2, _PMD.var(pm, nw, mm, (msr.cmp_id, msr.bus_ind, _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"])))
        else
            push!(m2, _PMD.var(pm, nw, mm, msr.cmp_id))
        end
    end
    if occursin("p", String(msr.msr_sym))
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[msr.cmp_id][c] == m1[1][c]*m2[1][c]+m1[2][c]*m2[2][c]
            )
    elseif occursin("q", String(msr.msr_sym))
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[msr.cmp_id][c] == -m1[2][c]*m2[1][c]+m1[1][c]*m2[2][c]
            )
    end
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::PreProcessing; nw=nw, nph=3)
    #TODO for v0.2.0 this needs to be general to every distribution or we need to provide an exception
    for c in 1:nph
        if _PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c] != 0.0

            display("old va entry is $(_PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c])")

            μ_tan = tan(_DST.mean(_PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c]))
            σ_tan = sec(μ_tangen)*_DST.std(_PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c])
            _PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c] = Normal( μ_tan, σ_tan )

            display("new va entry is $(_PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c])")
            if msr.cmp_type == :branch
                num = _PMD.var(pm, nw, msr.numerator, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"]))
                den = _PMD.var(pm, nw, msr.denominator, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"]))
            else
                num = _PMD.var(pm, nw, msr.numerator, msr.cmp_id)
                den = _PMD.var(pm, nw, msr.numerator, msr.cmp_id)
            end
            JuMP.@constraint(pm.model,
                original_var[msr.cmp_id][c] == msr.numerator[c]/(msr.denominator[c]+0.0000001)
                )
        end
    end
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::Fraction; nw=nw, nph=3)
    num = []
    for n in msr.numerator
        if occursin("v", String(msr.numerator)) && msr.cmp_type != :bus
            push!(num, _PMD.var(pm, nw, n, msr.bus_ind))
        else
            push!(num, _PMD.var(pm, nw, n, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"])))
        end
    end

    den = _PMD.var(pm, nw, msr.denominator, msr.bus_ind)

    if occursin("r", String(msr.msr_type))
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[msr.cmp_id][c] == (num[1][c]*cos(num[3][c])+num[2][c]*sin(num[3][c]))/(den[c]+0.00001)
            )
    elseif occursin("i", String(msr.msr_type))
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[msr.cmp_id][c] == (-num[2][c]*cos(num[3][c])+num[1][c]*sin(num[3][c]))/(den[c]+0.00001)
            )
    else
        error("wrong measurement association")
    end
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::SquareFraction; nw=nw, nph=3)

    new_var_num = []
    for nvn in msr.numerator
        if occursin("v", String(nvn)) && msr.cmp_type != :bus
            push!(new_var_num, _PMD.var(pm, nw, nvn, msr.bus_ind))
        elseif msr.cmp_type == :branch
            push!(new_var_num, _PMD.var(pm, nw, nvn, (msr.cmp_id, msr.bus_ind, _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"])))
        else
            push!(new_var_num, _PMD.var(pm, nw, nvn, msr.cmp_id))
        end
    end
    new_var_den = []
    for nvd in msr.denominator
        if typeof(nvd)!=:Symbol #only case is when I have an array of ones
            push!(new_var_den, nvd)
        elseif occursin("v", String(nvd)) && msr.cmp_type != :bus
            push!(new_var_den, _PMD.var(pm, nw, nvd, msr.bus_ind))
        else
            push!(new_var_den, _PMD.var(pm, nw, nvd, msr.cmp_id))
        end
    end
    JuMP.@constraint(pm.model, [c in 1:nph],
        original_var[msr.cmp_id][c]^2 == sum( n[c]^2 for n in new_var_num )/
                   sum( d[c]^2 for d in new_var_den)
        )
end


# using Ipopt, JuMP
# model = JuMP.Model(with_optimizer(Ipopt.Optimizer))
# @variable(model, z)
# @variable(model, y)
# @variable(model, x)
# @constraint(model, y >= 1)
# @NLconstraint(model, x == atan(y))
# @objective(model, Min, x-2)
# optimize!(model)
#
