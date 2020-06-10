function make_uniform_variable_space(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    msr_var = _PMD.ref(pm, nw, :meas, i, "var")
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    nph=3
    if no_conversion_needed(pm, msr_var)  #just creates the variable, which is naturally available in the given power model
        original_var = _PMD.var(pm, nw, msr_var, cmp_id)
        residual_correction = 1
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
        residual_correction = create_conversion_constraint(pm, _PMD.var(pm, nw)[msr_var], msr_type; nw=nw, nph=nph)
    end
    return original_var, residual_correction
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

    JuMP.@NLconstraint(pm.model, [c in 1:nph],
        original_var[msr.cmp_id][c] == sum( n[c]^2 for n in new_var_num )/
                   sum( d[c]^2 for d in new_var_den)
        )

    residual_exp = 2
    return residual_exp
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::SquareMultiplication; nw=nw, nph = 3)
    display("new case")
    display(original_var)
    display(msr.mult1[1])
    display(msr.cmp_id)
    display(_PMD.var(pm, nw)[:crg])
    display(_PMD.var(pm, nw)[:crd])
    m1 = _PMD.var(pm, nw, msr.mult1[1], msr.cmp_id)
    display("m1 is $m1")
    m2 = []
    for m in msr.mult2
        if occursin("v", String(m)) && msr.cmp_type != :bus
            push!(m2, _PMD.var(pm, nw, m, msr.bus_ind))
        else
            push!(m2, _PMD.var(pm, nw, m, msr.cmp_id))
        end
    end

    JuMP.@NLconstraint(pm.model, [c in 1:nph],
        original_var[msr.cmp_id][c] == m1[c]^2*sum( m[c]^2 for m in m2 )
        )

    residual_exp = 2
    return residual_exp
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::ArcTang; nw=nw, nph=3)
    num = _PMD.var(pm, nw, msr.numerator, msr.cmp_id)
    den = _PMD.var(pm, nw, msr.denominator, msr.cmp_id)

    JuMP.@NLconstraint(pm.model, [c in 1:nph],
        original_var[c] == atan(den[c]/num[c])
        )

    residual_exp = 1 #this is to be checked.. is it true for both WLAV and WLS?
    return residual_exp
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::Fraction; nw=nw, nph=3)
    if occursin("v", String(msr.numerator)) && msr.cmp_type != :bus
        num = _PMD.var(pm, nw, msr.numerator,msr.bus_ind)
    else
        num = _PMD.var(pm, nw, msr.numerator, msr.cmp_id)
    end
    if occursin("v", String(msr.denominator)) && msr.cmp_type != :bus
        den = _PMD.var(pm, nw, msr.denominator, msr.bus_id)
    else
        den = _PMD.var(pm, nw, msr.denominator, msr.cmp_id)
    end

    JuMP.@constraint(pm.model, [c in 1:nph],
        original_var[c] == num[c]/den[c]
        )

    residual_exp = 1
    return residual_exp
end
