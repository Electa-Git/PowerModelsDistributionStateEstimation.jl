################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                                             #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

abstract type ConversionType end

struct SquareFraction<:ConversionType
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    bus_ind::Int64
    numerator::Array
    denominator::Array
end

struct Square<:ConversionType
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    bus_ind::Int64
    elements::Array
end

struct Multiplication<:ConversionType
    msr_sym::Symbol
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    bus_ind::Int64
    mult1::Array
    mult2::Array
end

struct Tangent<:ConversionType
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    numerator::Symbol
    denominator::Symbol
end

struct Fraction<:ConversionType
    msr_type::Symbol
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    bus_ind::Int64
    numerator::Array
    denominator::Symbol
end

struct MultiplicationFraction<:ConversionType
    msr_type::Symbol
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    bus_ind::Int64
    power::Array
    voltage::Array
end

function assign_conversion_type_to_msr(pm::_PMs.AbstractACPModel,i,msr::Symbol;nw=nw)
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    if msr == :cm
        msr_type = SquareFraction(i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:p, :q], [:vm])
    elseif msr == :cmg
        msr_type = SquareFraction(i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:pg, :qg], [:vm])
    elseif msr == :cmd
        msr_type = SquareFraction(i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:pd, :qd], [:vm])
    elseif msr == :cr
        msr_type = Fraction(msr, i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:p, :q, :va], :vm)
    elseif msr == :crg
        msr_type = Fraction(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:pg, :qg, :va], :vm)
    elseif msr == :crd
        msr_type = Fraction(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:pd, :qd, :va], :vm)
    elseif msr == :ci
        msr_type = Fraction(msr, i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:p, :q, :va], :vm)
    elseif msr == :cig
        msr_type = Fraction(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:pg, :qg, :va], :vm)
    elseif msr == :cid
        msr_type = Fraction(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:pd, :qd, :va], :vm)
    else
       Memento.error(_LOGGER, "the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and should be removed")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMs.AbstractACRModel,i,msr::Symbol;nw=nw)
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    if msr == :vm
        msr_type = Square(i,:bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr])
    elseif msr == :va
        msr_type = Tangent(i, :bus, cmp_id, :vi, :vr)
    elseif msr == :cm
        msr_type = SquareFraction(i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:p, :q], [:vi, :vr])
    elseif msr == :cmg
        msr_type = SquareFraction(i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:pg, :qg], [:vi, :vr])
    elseif msr == :cmd
        msr_type = SquareFraction(i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:pd, :qd], [:vi, :vr])
    elseif msr == :cr
        msr_type = MultiplicationFraction(msr, i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:p, :q], [:vr, :vi])
    elseif msr == :crg
        msr_type = MultiplicationFraction(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:pg, :qg], [:vr, :vi])
    elseif msr == :crd
        msr_type = MultiplicationFraction(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:pd, :qd], [:vr, :vi])
    elseif msr == :ci
        msr_type = MultiplicationFraction(msr, i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:p, :q], [:vr, :vi])
    elseif msr == :cig
        msr_type = MultiplicationFraction(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:pg, :qg], [:vr, :vi])
    elseif msr == :cid
        msr_type = MultiplicationFraction(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:pd, :qd], [:vr, :vi])
    else
       Memento.error(_LOGGER, "the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and will be ignored")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMs.AbstractIVRModel,i,msr::Symbol;nw=nw)
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    if msr == :vm
        msr_type = Square(i,:bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr])
    elseif msr == :va
        msr_type = Tangent(i, :bus, cmp_id, :vi, :vr)
    elseif msr == :cm
        msr_type = Square(i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:cr, :ci])
    elseif msr == :cmg
        msr_type = Square(i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:crg, :cig])
    elseif msr == :cmd
        msr_type = Square(i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:crd, :cid])
    elseif msr == :ca
        msr_type = Tangent(i, :branch, cmp_id, :ci, :cr)
    elseif msr == :cag
        msr_type = Tangent(i, :gen, cmp_id, :cig, :crg)
    elseif msr == :cad
        msr_type = Tangent(i, :load, cmp_id, :cid, :crd)
    elseif msr == :p
        msr_type = Multiplication(msr, i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:cr, :ci], [:vr, :vi])
    elseif msr == :pg
        msr_type = Multiplication(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:crg, :cig], [:vr, :vi])
    elseif msr == :pd
        msr_type = Multiplication(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:crd, :cid], [:vr, :vi])
    elseif msr == :q
        msr_type = Multiplication(msr, i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:cr, :ci], [:vr, :vi])
    elseif msr == :qg
        msr_type = Multiplication(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:crg, :cig], [:vr, :vi])
    elseif msr == :qd
        msr_type = Multiplication(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:crd, :cid], [:vr, :vi])
    else
       Memento.error(_LOGGER, "the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and should be removed")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMD.LinDist3FlowPowerModel,i,msr::Symbol;nw=nw)
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    if msr == :vm
        msr_type = Square(i,:bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:w])
    elseif msr == :cm
        msr_type = SquareFraction(i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:p, :q], [:w])
    elseif msr == :cmg
        msr_type = SquareFraction(i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:pg, :qg], [:w])
    elseif msr == :cmd
        msr_type = SquareFraction(i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:pd, :qd], [:w])
    else
       Memento.error(_LOGGER, "the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and should be removed")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMD.SDPUBFPowerModel,i,msr::Symbol;nw=nw)
   Memento.error(_LOGGER, "Currently only a limited amount of measurement types is supported for the SDP model, $(msr) is not available")
end

function no_conversion_needed(pm::_PMs.AbstractACPModel, msr_var::Symbol)
  return msr_var ∈ [:vm, :va, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMs.AbstractACRModel, msr_var::Symbol)
  return msr_var ∈ [:vr, :vi, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMs.AbstractIVRModel, msr_var::Symbol)
  return msr_var ∈ [:vr, :vi, :cr, :ci, :crg, :cig, :crd, :cid]
end

function no_conversion_needed(pm::_PMD.AbstractLPUBFModel, msr_var::Symbol)
    return msr_var ∈ [:w, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMD.SDPUBFPowerModel, msr_var::Symbol)
    return msr_var ∈ [:w, :pd, :qd, :pg, :qg]
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

    msr.cmp_type == :branch ? id = (msr.cmp_id,  msr.bus_ind, _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id

    if typeof(pm) <: _PMD.LinDist3FlowPowerModel

        new_var_den = [_PMD.var(pm, nw, msr.denominator, msr.cmp_id)]

        JuMP.@NLconstraint(pm.model, [c in 1:nph],
            original_var[id][c]^2 == (sum( n[c]^2 for n in new_var_num ))/
                       (sum( d[c] for d in new_var_den))
            )
    else
        new_var_den = []
        for nvd in msr.denominator
            if !isa(nvd, Symbol) #only case is when I have an array of ones
                push!(new_var_den, nvd)
            elseif occursin("v", String(nvd)) && msr.cmp_type != :bus
                push!(new_var_den, _PMD.var(pm, nw, nvd, msr.bus_ind))
            else
                push!(new_var_den, _PMD.var(pm, nw, nvd, msr.cmp_id))
            end
        end

        JuMP.@NLconstraint(pm.model, [c in 1:nph],
            original_var[id][c]^2 == (sum( n[c]^2 for n in new_var_num ))/
                       (sum( d[c]^2 for d in new_var_den))
            )
    end
end

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::Square; nw=nw, nph=3)

    new_var = []
    for nvn in msr.elements
        if msr.cmp_type == :branch
            push!(new_var, _PMD.var(pm, nw, nvn, (msr.cmp_id, _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"])))
        else
            push!(new_var, _PMD.var(pm, nw, nvn, msr.cmp_id))
        end
    end

    msr.cmp_type == :branch ? id = (msr.cmp_id,  _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id

    if typeof(pm) <: _PMD.LinDist3FlowPowerModel
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[id][c]^2 == (sum( n[c] for n in new_var ))
            )
    else
        JuMP.@constraint(pm.model, [c in 1:nph],
            original_var[id][c]^2 == (sum( n[c]^2 for n in new_var ))
            )
    end
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

function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::Tangent; nw=nw, nph=3)
    #TODO for v0.2.0 this needs to be general to every distribution or we need to provide an exception
    warn("Performing a Tangent conversion only makes sense for Normal distributions and is in general not advised")
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
                original_var[id][c]*den[c] == num[c]
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
            original_var[id][c]*den[c] == num[1][c]*cos(num[3][c])+num[2][c]*sin(num[3][c])
            )
    elseif occursin("i", String(msr.msr_type))
        JuMP.@NLconstraint(pm.model, [c in 1:nph],
            original_var[id][c]*den[c] == -num[2][c]*cos(num[3][c])+num[1][c]*sin(num[3][c])
            )
    else
        Memento.error(_LOGGER, "wrong measurement association")
    end
end


function create_conversion_constraint(pm::_PMs.AbstractPowerModel, original_var, msr::MultiplicationFraction; nw=nw, nph=3)

    p = []
    v = []
    for pw in msr.power
        if msr.cmp_type == :branch
            push!(p, _PMD.var(pm, nw, pw, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"])))
        else
            push!(p, _PMD.var(pm, nw, pw, msr.cmp_id))
        end
    end
    for vl in msr.voltage
        push!(v, _PMD.var(pm, nw, vl, msr.bus_ind))
    end

    msr.cmp_type == :branch ? id = (msr.cmp_id,  _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id

    if occursin("cr", string(msr.msr_type))
        JuMP.@NLconstraint(pm.model, [c in 1:nph],
            original_var[id][c] == (p[1][c]*v[1][c]+p[2][c]*v[2][c])/(v[1][c]^2+v[2][c]^2)
            )
    elseif occursin("ci", string(msr.msr_type))
        JuMP.@NLconstraint(pm.model, [c in 1:nph],
            original_var[id][c] == (-p[2][c]*v[1][c]+p[1][c]*v[2][c])/(v[1][c]^2+v[2][c]^2)
            )
    end
end
