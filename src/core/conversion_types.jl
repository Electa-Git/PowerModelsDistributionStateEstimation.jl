abstract type ConversionType end

struct SquareFraction<:ConversionType
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    bus_ind::Int64
    numerator::Array
    denominator::Array
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

struct PreProcessing<:ConversionType
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
       error("the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and should be removed")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMs.AbstractACRModel,i,msr::Symbol;nw=nw)
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    if msr == :vm
        msr_type = SquareFraction(i,:bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr], [[1, 1, 1]])
    elseif msr == :va
        msr_type = PreProcessing(i, :bus, cmp_id, :vi, :vr)
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
       error("the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and will be ignored")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMs.AbstractIVRModel,i,msr::Symbol;nw=nw)
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    if msr == :vm
        msr_type = SquareFraction(i,:bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr], [[1, 1, 1]])
    elseif msr == :va
        msr_type = PreProcessing(i, :bus, cmp_id, :vi, :vr)
    elseif msr == :cm
        msr_type = SquareFraction(i,:branch, cmp_id, _PMD.ref(pm,nw,:branch,cmp_id)["f_bus"], [:cr, :ci], [[1, 1, 1]])
    elseif msr == :cmg
        msr_type = SquareFraction(i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:crg, :cig], [[1, 1, 1]])
    elseif msr == :cmd
        msr_type = SquareFraction(i,:load, cmp_id, _PMD.ref(pm,nw,:load,cmp_id)["load_bus"], [:crd, :cid], [[1, 1, 1]])
    elseif msr == :ca
        msr_type = PreProcessing(i, :branch, cmp_id, :ci, :cr)
    elseif msr == :cag
        msr_type = PreProcessing(i, :gen, cmp_id, :cig, :crg)
    elseif msr == :cad
        msr_type = PreProcessing(i, :load, cmp_id, :cid, :crd)
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
       error("the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and should be removed")
    end
    return msr_type
end
