################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
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


struct LineVoltage<:ConversionType
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    bus_ind::Int64
    elements::Array
end

struct PowerSum<:ConversionType
    msr_sym::Symbol
    msr_id::Int64
    cmp_type::Symbol
    cmp_id::Int64
    bus_ind::Int64
    arr1::Array  
    arr2::Array  
end

function assign_conversion_type_to_msr(pm::_PMD.AbstractUnbalancedACPModel,i,msr::Symbol;nw=nw)
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
    elseif msr ∈ [:qtot, :ptot]
        cmp_string = String(_PMD.ref(pm,nw,:meas,i)["cmp"]) # "load" or "gen"
        cmp_symb = _PMD.ref(pm,nw,:meas,i)["cmp"] #:load or :gen
        msr_type = PowerSum(msr, i, cmp_symb , cmp_id, _PMD.ref(pm,nw,cmp_symb,cmp_id)["$(cmp_string)_bus"], [:p], [:q])
    elseif msr == :vll
        msr_type = LineVoltage(i, :bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"],[:vm, :va]) 
    else
       error("the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and should be removed")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMD.AbstractUnbalancedACRModel,i,msr::Symbol;nw=nw)
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
    elseif msr ∈ [:qtot, :ptot]
        cmp_string = String(_PMD.ref(pm,nw,:meas,i)["cmp"]) # "load" or "gen"
        cmp_symb = _PMD.ref(pm,nw,:meas,i)["cmp"] #:load or :gen
        msr_type = PowerSum(msr, i, cmp_symb , cmp_id, _PMD.ref(pm,nw,cmp_symb,cmp_id)["$(cmp_string)_bus"], [:p], [:q]) 
    else
       error("the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and will be ignored")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMD.AbstractUnbalancedIVRModel,i,msr::Symbol;nw=nw)
    cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
    # VOLTAGES
    if msr == :vm || msr == :vmn
        msr_type = Square(i,:bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr])
    elseif msr == :va
        msr_type = Tangent(i, :bus, cmp_id, :vi, :vr)
    elseif msr == :vll
        msr_type = LineVoltage(i, :bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"],[:vi, :vr])
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
    # POWERS
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
    elseif msr ∈ [:qtot, :ptot]
        cmp_string = String(_PMD.ref(pm,nw,:meas,i)["cmp"]) # "load" or "gen"
        cmp_symb = _PMD.ref(pm,nw,:meas,i)["cmp"] #:load or :gen
        msr_type = PowerSum(msr, i, cmp_symb, cmp_id, _PMD.ref(pm,nw,cmp_symb,cmp_id)["$(cmp_string)_bus"], [:cr, :ci], [:vr, :vi])  # _PMD.ref(pm,nw,:meas,i)["cmp"] -> :gen or :bus
    else
       error("the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and should be removed")
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
    elseif msr ∈ [:qtot, :ptot]
        cmp_string = String(_PMD.ref(pm,nw,:meas,i)["cmp"]) # "load" or "gen"
        cmp_symb = _PMD.ref(pm,nw,:meas,i)["cmp"] #:load or :gen
        msr_type = PowerSum(msr, i, cmp_symb , cmp_id, _PMD.ref(pm,nw,cmp_symb,cmp_id)["$(cmp_string)_bus"], [:p], [:q]) 
    else
       error("the chosen measurement $(msr) at $(_PMD.ref(pm, nw, :meas, i, "cmp")) $(_PMD.ref(pm, nw, :meas, i, "cmp_id")) is not supported and should be removed")
    end
    return msr_type
end

function assign_conversion_type_to_msr(pm::_PMD.SDPUBFPowerModel,i,msr::Symbol;nw=nw)
   error("Currently only a limited amount of measurement types is supported for the SDP model, $(msr) is not available")
end

function no_conversion_needed(pm::_PMD.AbstractUnbalancedACPModel, msr_var::Symbol)
  return msr_var ∈ [:vm, :va, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMD.AbstractUnbalancedACRModel, msr_var::Symbol)
  return msr_var ∈ [:vr, :vi, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMD.AbstractUnbalancedIVRModel, msr_var::Symbol)
  return msr_var ∈ [:vr, :vi, :cr, :ci, :crg, :cig, :crd, :cid]
end

function no_conversion_needed(pm::_PMD.AbstractLPUBFModel, msr_var::Symbol)
    return msr_var ∈ [:w, :pd, :qd, :pg, :qg, :p, :q]
end

function no_conversion_needed(pm::_PMD.SDPUBFPowerModel, msr_var::Symbol)
    return msr_var ∈ [:w, :pd, :qd, :pg, :qg]
end

function create_conversion_constraint(pm::_PMD.AbstractUnbalancedPowerModel, original_var, msr::SquareFraction; nw=nw)

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
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)

    if typeof(pm) <: _PMD.LinDist3FlowPowerModel

        new_var_den = [_PMD.var(pm, nw, msr.denominator, msr.cmp_id)]

        JuMP.@constraint(pm.model, [c in conn],
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

        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c]^2 == (sum( n[c]^2 for n in new_var_num ))/
                       (sum( d[c]^2 for d in new_var_den))
            )
    end
end

function create_conversion_constraint(pm::_PMD.AbstractUnbalancedPowerModel, original_var, msr::Square; nw=nw)

    new_var = []
    for nvn in msr.elements
        if msr.cmp_type == :branch
            push!(new_var, _PMD.var(pm, nw, nvn, (msr.cmp_id, _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"])))
        else
            push!(new_var, _PMD.var(pm, nw, nvn, msr.cmp_id))
        end
    end

    msr.cmp_type == :branch ? id = (msr.cmp_id,  _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)

    if typeof(pm) <: _PMD.LinDist3FlowPowerModel
        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c]^2 == (sum( n[c] for n in new_var ))
            )
    else
        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c]^2 == (sum( n[c]^2 for n in new_var ))
            )
    end
end

function create_conversion_constraint(pm::_PMD.AbstractUnbalancedPowerModel, original_var, msr::Multiplication; nw=nw)

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
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)

    if occursin("p", String(msr.msr_sym))
        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c] == m1[1][c]*m2[1][c]+m1[2][c]*m2[2][c]
            )
    elseif occursin("q", String(msr.msr_sym))
        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c] == -m1[2][c]*m2[1][c]+m1[1][c]*m2[2][c]
            )
    end
end

function create_conversion_constraint(pm::_PMD.AbstractUnbalancedPowerModel, original_var, msr::Tangent; nw=nw)
    #TODO for v0.2.0 this needs to be general to every distribution or we need to provide an exception
    @warn "Performing a Tangent conversion only makes sense for Normal distributions and is in general not advised"
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)
    for c in conn
        if _PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c] != 0.0

            μ_tan = tan(_DST.mean(_PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c]))
            σ_tan = abs(sec(μ_tan)*_DST.std(_PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c]))
            _PMD.ref(pm, nw, :meas, msr.msr_id, "dst")[c] = _DST.Normal( μ_tan, σ_tan )

            if msr.cmp_type == :branch
                num = _PMD.var(pm, nw, msr.numerator, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"]))
                den = _PMD.var(pm, nw, msr.denominator, (msr.cmp_id, _PMD.ref(pm, nw, :branch,msr.cmp_id)["f_bus"], _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"]))
            else
                num = _PMD.var(pm, nw, msr.numerator, msr.cmp_id)
                den = _PMD.var(pm, nw, msr.denominator, msr.cmp_id)
            end
            msr.cmp_type == :branch ? id = (msr.cmp_id, _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
            JuMP.@constraint(pm.model,
                original_var[id][c]*den[c] == num[c]
                )
        end
    end
end

function create_conversion_constraint(pm::_PMD.AbstractUnbalancedPowerModel, original_var, msr::Fraction; nw=nw)
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
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)

    if occursin("r", String(msr.msr_type))
        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c]*den[c] == num[1][c]*cos(num[3][c])+num[2][c]*sin(num[3][c])
            )
    elseif occursin("i", String(msr.msr_type))
        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c]*den[c] == -num[2][c]*cos(num[3][c])+num[1][c]*sin(num[3][c])
            )
    else
        error("wrong measurement association")
    end
end


function create_conversion_constraint(pm::_PMD.AbstractUnbalancedPowerModel, original_var, msr::MultiplicationFraction; nw=nw)

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
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)

    if occursin("cr", string(msr.msr_type))
        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c] == (p[1][c]*v[1][c]+p[2][c]*v[2][c])/(v[1][c]^2+v[2][c]^2)
            )
    elseif occursin("ci", string(msr.msr_type))
        JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c] == (-p[2][c]*v[1][c]+p[1][c]*v[2][c])/(v[1][c]^2+v[2][c]^2)
            )
    end
end

#                                                                                       msr_type = PowerSum(msr, i, cmp_symb , cmp_id, _PMD.ref(pm,nw,cmp_symb,cmp_id)["$(cmp_string)_bus"], [:p], [:q])  
#                                                                                                ↗ PowerSum(msr, i,:load, cmp_id, load_bus_id, [:pd], [:qd])
#                                                                         ↗ :qtot || :ptot       ↗ PowerSum(msr, i,:gen, cmp_id, gen_bus_id, [:pg], [:qg])
function create_conversion_constraint(pm::_PMD.AbstractUnbalancedPowerModel, original_var, msr::PowerSum, nw=nw) 

    cmp_indication = msr.cmp_type == :load ? "d" : msr.cmp_type == :gen ? "g" : ""
    
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)

    if occursin("p", string(msr.msr_sym)) # then it is :ptot
            
        ps = Symbol.(String.(msr.arr1).*cmp_indication)
        px = _PMD.var(pm, nw, ps[1], msr.cmp_id)
        JuMP.@constraint(pm.model, 
        original_var[msr.cmp_id] .- sum(px[c] for c in conn) == 0
                    )

    elseif occursin("q", string(msr.msr_sym)) # then it is :qtot
        qs = Symbol.(String.(msr.arr2).*cmp_indication)
        qx = _PMD.var(pm, nw, qs[1], msr.cmp_id)

        JuMP.@constraint(pm.model, 
        original_var[msr.cmp_id] .- sum(qx[c] for c in conn) == 0
                    )
    end
end



#                                                                                       msr_type = PowerSum(msr, i, cmp_symb , cmp_id, _PMD.ref(pm,nw,cmp_symb,cmp_id)["$(cmp_string)_bus"], [:p], [:q])  
#                                                               ↗  :ptot || :qtot         ↗ PowerSum(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["load_bus"], [:crd, :cid], [:vr, :vi])
#                                                               ↗  :ptot || :qtot         ↗ PowerSum(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:crg, :cig], [:vr, :vi])
function create_conversion_constraint(pm::_PMD.AbstractUnbalancedIVRModel, original_var, msr::PowerSum; nw=nw)  
    #This works for both four and three wire IVR (might be overriding to the funtion at se_en.jl)

    cmp_indication =    msr.cmp_type == :load ? "d" : msr.cmp_type == :gen ? "g" : ""
    cs = Symbol.(String.(msr.arr1).*cmp_indication)
    vs = msr.arr2
    vr = _PMD.var(pm,nw, vs[1],msr.bus_ind)
    vi = _PMD.var(pm,nw, vs[2],msr.bus_ind)
    cr = _PMD.var(pm,nw, cs[1],msr.cmp_id)
    ci = _PMD.var(pm,nw, cs[2],msr.cmp_id)

    allconn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)
    conn = setdiff(allconn,_N_IDX)

    threeWireIVR = conn == allconn ? true : false

    if occursin("p", String(msr.msr_sym))
        
        if threeWireIVR
            JuMP.@constraint(pm.model, 
                original_var[msr.cmp_id] .- sum(cr[c]*(vr[c])+ci[c]*(vi[c]) for c in conn) == 0
            )
        else
            JuMP.@constraint(pm.model, 
                original_var[msr.cmp_id] .- sum(cr[c]*(vr[c]-vr[_N_IDX])+ci[c]*(vi[c]-vi[_N_IDX]) for c in conn) == 0
            )
        end

    elseif occursin("q", String(msr.msr_sym))

        if threeWireIVR
            JuMP.@constraint(pm.model, 
                original_var[msr.cmp_id] .- sum(-ci[c]*(vr[c])+cr[c]*(vi[c])  for c in conn) == 0
            )
        else
        JuMP.@constraint(pm.model, 
            original_var[msr.cmp_id] .- sum(-ci[c]*(vr[c]-vr[_N_IDX])+cr[c]*(vi[c]-vi[_N_IDX])  for c in conn) == 0
        )
        end
    end
end

#                                                                           msr_type = LineVoltage(i, :bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"],[:vm, :va]) 
#↗                                                               :vll        ↗ LineVoltage(i, :bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr])
function create_conversion_constraint(pm::_PMD.AbstractUnbalancedIVRModel, original_var, msr::LineVoltage; nw=nw)
    # msr.elements = [:vi, :vr]
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id) 
    vr = _PMD.var(pm, nw, msr.elements[2], msr.cmp_id) # msr.elements[2] = :vr  0_vr_3[]
    vi = _PMD.var(pm, nw, msr.elements[1], msr.cmp_id) # msr.elements[1] = :vi
    index_pairs = length(conn) > 2 ?  [(1,2), (2,3), (3,1)] :  [tuple(setdiff(conn, _N_IDX)...)] # checks if :vll is for three phase or single line-to-line load
    for (idx, (i, j)) in enumerate(index_pairs)
        JuMP.@constraint(pm.model, original_var[msr.cmp_id][idx]^2 == vr[i]^2 + vr[j]^2 - 2*vr[i]*vr[j] + vi[i]^2 + vi[j]^2 - 2*vi[i]*vi[j])
    end
end

# Explicit Neutral related conversion functions 

#                                                                 ↗  :vmn        ↗ Square(i, :bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr])
function create_conversion_constraint(pm::_PMD.IVRENPowerModel, original_var, msr::Square; nw=nw)
    new_var = []
    # prepare the :vi and :vr inside pm.model
    for nvn in msr.elements
        if msr.cmp_type == :branch
            push!(new_var, _PMD.var(pm, nw, nvn, (msr.cmp_id, _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"])))
        else
            push!(new_var, _PMD.var(pm, nw, nvn, msr.cmp_id))
        end
    end
    

    msr.cmp_type == :branch ? id = (msr.cmp_id,  _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)  # 1:4 for buses and branches while 1:3 for loads and gens by nature

    JuMP.@constraint(pm.model, [c in setdiff(conn,_N_IDX)],
    original_var[id][c]^2 == (sum( (n[c]- n[_N_IDX])^2 for n in new_var ))

    )

end

#                                                                    ↗  :vll        ↗ LineVoltage(i, :bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr])
function create_conversion_constraint(pm::_PMD.IVRENPowerModel, original_var, msr::LineVoltage; nw=nw)
    # msr.elements = [:vi, :vr]
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id) 
    vr = _PMD.var(pm, nw, msr.elements[2], msr.cmp_id) # msr.elements[2] = :vr  0_vr_3[]
    vi = _PMD.var(pm, nw, msr.elements[1], msr.cmp_id) # msr.elements[1] = :vi
    index_pairs = length(conn) > 2 ?  [(1,2), (2,3), (3,1)] :  [tuple(setdiff(conn, _N_IDX)...)] # checks if :vll is for three phase or single line-to-line load
    for (idx, (i, j)) in enumerate(index_pairs)
        JuMP.@constraint(pm.model, original_var[msr.cmp_id][idx]^2 == vr[i]^2 + vr[j]^2 - 2*vr[i]*vr[j] + vi[i]^2 + vi[j]^2 - 2*vi[i]*vi[j])
    end
end

#                                                               ↗  :pd || :qd         ↗ Multiplication(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["load_bus"], [:crd, :cid], [:vr, :vi])
#                                                               ↗  :pg || :qg         ↗ Multiplication(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:crg, :cig], [:vr, :vi])
function create_conversion_constraint(pm::_PMD.IVRENPowerModel, original_var, msr::Multiplication; nw=nw)

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
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)

    conn = setdiff(conn,_N_IDX)
    if occursin("p", String(msr.msr_sym))
        pcons = JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c] == m1[1][c]*(m2[1][c]-m2[1][_N_IDX])+m1[2][c]*(m2[2][c]-m2[2][_N_IDX]) 
            )
            display(pcons)
    elseif occursin("q", String(msr.msr_sym))
        qcons= JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c] == -m1[2][c]*(m2[1][c]-m2[1][_N_IDX])+m1[1][c]*(m2[2][c]-m2[2][_N_IDX])
            )
            display(qcons)
    end
end


#                                                               ↗  :ptot || :qtot         ↗ PowerSum(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["load_bus"], [:crd, :cid], [:vr, :vi])
#                                                               ↗  :ptot || :qtot         ↗ PowerSum(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:crg, :cig], [:vr, :vi])
function create_conversion_constraint(pm::_PMD.IVRENPowerModel, original_var, msr::PowerSum; nw=nw)

    # decide if its a load or a generator
    cmp_indication =    msr.cmp_type == :load ? "d" : msr.cmp_type == :gen ? "g" : ""
    cs = Symbol.(String.(msr.arr1).*cmp_indication)
    vs = msr.arr2
    vr = _PMD.var(pm,nw, vs[1],msr.bus_ind)
    vi = _PMD.var(pm,nw, vs[2],msr.bus_ind)
    cr = _PMD.var(pm,nw, cs[1],msr.cmp_id)
    ci = _PMD.var(pm,nw, cs[2],msr.cmp_id)

    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)
    conn = setdiff(conn,_N_IDX)
    if occursin("p", String(msr.msr_sym))
        JuMP.@constraint(pm.model, 
            original_var[msr.cmp_id] .- sum(cr[c]*(vr[c]-vr[_N_IDX])+ci[c]*(vi[c]-vi[_N_IDX]) for c in conn) == 0
        )
    elseif occursin("q", String(msr.msr_sym))
        JuMP.@constraint(pm.model, 
            original_var[msr.cmp_id] .- sum(-ci[c]*(vr[c]-vr[_N_IDX])+cr[c]*(vi[c]-vi[_N_IDX])  for c in conn) == 0
        )
    end
end