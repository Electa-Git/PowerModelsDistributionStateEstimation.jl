function no_conversion_needed(pm::_PMs.ACPPowerModel, msr_var::Symbol)
  return msr_var ∈ [:vm, :va, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMs.ACRPowerModel, msr_var::Symbol)
  return msr_var ∈ [:vr, :vi, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMs.IVRPowerModel, msr_var::Symbol)
  return msr_var ∈ [:vr, :vi, :cr, :ci, :crg, :cig, :crd, :cid]
end

function no_conversion_needed(pm::_PMD.SDPUBFPowerModel, msr_var::Symbol)
    #NOTE we could extend this to current values crd, cid etc. putting hands on powermodelsdistribution, like they already do for w (diag of Wr)
    if msr_var ∈ [:w, :pd, :qd, :pg, :qg, :p, :q, :cm]
        return msr_var ∈ [:w, :pd, :qd, :pg, :qg, :p, :q, :cm]
    else
        error("Currently, $msr_var is not supported in for the _PMD.SDPUBFPowerModel,
               consider using an exact model")
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
        if typeof(nvd) != Symbol #only case is when I have an array of ones
            push!(new_var_den, nvd)
        elseif occursin("v", String(nvd)) && msr.cmp_type != :bus
            push!(new_var_den, _PMD.var(pm, nw, nvd, msr.bus_ind))
        else
            push!(new_var_den, _PMD.var(pm, nw, nvd, msr.cmp_id))
        end
    end
    msr.cmp_type == :branch ? id = (msr.cmp_id,  msr.bus_ind, _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
    JuMP.@NLconstraint(pm.model, [c in 1:nph],
        original_var[id][c]^2 == (sum( n[c]^2 for n in new_var_num ))/
                   (sum( d[c]^2 for d in new_var_den))
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
    msr.cmp_type == :branch ? id = (msr.cmp_id,  msr.bus_ind, _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
    if occursin("p", String(msr.msr_sym))
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[id][c] == m1[1][c]*m2[1][c]+m1[2][c]*m2[2][c]
            )
    elseif occursin("q", String(msr.msr_sym))
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[id][c] == -m1[2][c]*m2[1][c]+m1[1][c]*m2[2][c]
            )
    end
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::PreProcessing; nw=nw, nph=3)
    #TODO for v0.2.0 this needs to be general to every distribution or we need to provide an exception
    for c in 1:nph
        if _PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c] != 0.0

            μ_tan = tan(_DST.mean(_PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c]))
            σ_tan = abs(sec(μ_tan)*_DST.std(_PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c]))
            _PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c] = _DST.Normal( μ_tan, σ_tan )

            if msr.cmp_type == :branch
                num = _PMD.var(pm, nw, msr.numerator, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"]))
                den = _PMD.var(pm, nw, msr.denominator, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"]))
            else
                num = _PMD.var(pm, nw, msr.numerator, msr.cmp_id)
                den = _PMD.var(pm, nw, msr.numerator, msr.cmp_id)
            end
            msr.cmp_type == :branch ? id = (msr.cmp_id, _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
            JuMP.@NLconstraint(pm.model,
                original_var[id][c] == num[c]/(den[c]+0.00000001)
                )
        end
    end
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::Fraction; nw=nw, nph=3)
    num = []
    for n in msr.numerator
        if occursin("v", String(n))
            push!(num, _PMD.var(pm, nw, n, msr.bus_ind))
        elseif !occursin("v", String(n)) && msr.cmp_type != :branch
            push!(num, _PMD.var(pm, nw, n, msr.cmp_id))
        else
            push!(num, _PMD.var(pm, nw, n, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"])))
        end
    end

    den = _PMD.var(pm, nw, msr.denominator, msr.bus_ind)
    msr.cmp_type == :branch ? id = (msr.cmp_id,  msr.bus_ind, _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id

    if occursin("r", String(msr.msr_type))
        JuMP.@NLconstraint(pm.model, [c in 1:nph],
            original_var[id][c] == (num[1][c]*cos(num[3][c])+num[2][c]*sin(num[3][c]))/(den[c]+0.00001)
            )
    elseif occursin("i", String(msr.msr_type))
        JuMP.@NLconstraint(pm.model, [c in 1:nph],
            original_var[id][c] == (-num[2][c]*cos(num[3][c])+num[1][c]*sin(num[3][c]))/(den[c]+0.00001)
            )
    else
        error("wrong measurement association")
    end
end


function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::MultiplicationFraction; nw=nw, nph=3)

    power_var = []
    voltage_var = []
    for p in msr.power
        if msr.cmp_type == :branch
            push!(power_var, _PMD.var(pm, nw, p, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"])))
        else
            push!(power_var, _PMD.var(pm, nw, p, msr.cmp_id))
        end
    end
    for v in msr.voltage
        push!(voltage_var, _PMD.var(pm, nw, v, msr.bus_ind))
    end

    msr.cmp_type == :branch ? id = (msr.cmp_id,  msr.bus_ind, _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
    if occursin("p", string(msr.msr_type))
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[id][c] == (p[1][c]*v[1][c]+p[2][c]*v[2][c])/(v[1][c]^2+v[2][c]^2)
            )
    elseif occursin("q", string(msr.msr_type))
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[id][c] == (-p[2][c]*v[1][c]+p[1][c]*v[2][c])/(v[1][c]^2+v[2][c]^2)
            )
    end
end
