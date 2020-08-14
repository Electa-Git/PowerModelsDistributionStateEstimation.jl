using PowerModels #NB must be version 0.17.0
using Ipopt, NLsolve
using SparseArrays

ipopt = with_optimizer(Ipopt.Optimizer)

network_data = PowerModels.parse_file("C:\\Users\\mvanin\\.julia\\packages\\PowerModels\\Tq705\\test\\data\\matpower\\case14.m")
network_data["dcline"] = []
pfdata = instantiate_pf_data(network_data)
@time sol = _compute_ac_pf(pfdata, finite_differencing = false)
@time sol = _compute_ac_pf(pfdata, finite_differencing = true)
ipopt_sol = run_ac_pf(network_data, ipopt)
display(ipopt_sol["solve_time"])

otherdata = PowerModels.parse_file("C:\\Users\\mvanin\\.julia\\dev\\pglib_opf_case13659_pegase.m")
otherdata["dcline"] = []
otherpfdata = instantiate_pf_data(otherdata)
@time sol = _compute_ac_pf(otherpfdata, finite_differencing = false)
#@time sol = _compute_ac_pf(otherpfdata, finite_differencing = true)
otheripopt_sol = run_ac_pf(otherdata, ipopt)
display(otheripopt_sol["solve_time"])

##############################################################3333
###################################################################
#NB: below the required functions

struct PowerFlowData
    data::Dict{String,<:Any}
    bus_gens::Dict{Int,Vector}
    am::AdmittanceMatrix{Complex{Float64}}
    bus_type_idx::Vector{Int}
    p_delta_base_idx::Vector{Float64}
    q_delta_base_idx::Vector{Float64}
    p_inject_idx::Vector{Float64}
    q_inject_idx::Vector{Float64}
    vm_idx::Vector{Float64}
    va_idx::Vector{Float64}
    neighbors::Vector{Set{Int}}
    x0::Vector{Float64}
    F0::Vector{Float64}
    J0::SparseArrays.SparseMatrixCSC{Float64,Int}
end

import PowerModels.instantiate_pf_data

function instantiate_pf_data(data::Dict{String,Any})
    p_delta, q_delta = calc_bus_injection(data)

    # remove gen injections from slack and pv buses
    for (i,gen) in data["gen"]
        gen_bus = data["bus"]["$(gen["gen_bus"])"]
        if gen["gen_status"] != 0
            if gen_bus["bus_type"] == 3
                p_delta[gen_bus["index"]] += gen["pg"]
                q_delta[gen_bus["index"]] += gen["qg"]
            elseif gen_bus["bus_type"] == 2
                q_delta[gen_bus["index"]] += gen["qg"]
            else
                @assert false
            end
        end
    end


    bus_gens = Dict{Int,Array{Any}}()
    for (i,gen) in data["gen"]
        # skip inactive generators
        if gen["gen_status"] == 0
            continue
        end

        gen_bus_id = gen["gen_bus"]
        if !haskey(bus_gens, gen_bus_id)
            bus_gens[gen_bus_id] = []
        end
        push!(bus_gens[gen_bus_id], gen)
    end

    for (bus_id, gens) in bus_gens
        sort!(gens, by=x -> (x["qmax"] - x["qmin"], x["index"]))
    end


    am = calc_admittance_matrix(data)

    bus_type_idx = Int[data["bus"]["$(bus_id)"]["bus_type"] for bus_id in am.idx_to_bus]

    p_delta_base_idx = Float64[p_delta[bus_id] for bus_id in am.idx_to_bus]
    q_delta_base_idx = Float64[q_delta[bus_id] for bus_id in am.idx_to_bus]

    p_inject_idx = [0.0 for bus_id in am.idx_to_bus]
    q_inject_idx = [0.0 for bus_id in am.idx_to_bus]

    vm_idx = [1.0 for bus_id in am.idx_to_bus]
    va_idx = [0.0 for bus_id in am.idx_to_bus]

    # for buses with non-1.0 bus voltages
    for (i,bus) in data["bus"]
        if bus["bus_type"] == 2 || bus["bus_type"] == 3
            vm_idx[am.bus_to_idx[bus["index"]]] = bus["vm"]
        end
    end


    neighbors = [Set{Int}([i]) for i in eachindex(am.idx_to_bus)]
    I, J, V = findnz(am.matrix)
    for nz in eachindex(V)
        push!(neighbors[I[nz]], J[nz])
        push!(neighbors[J[nz]], I[nz])
    end

    x0 = [0.0 for i in 1:2*length(am.idx_to_bus)]
    F0 = similar(x0)

    J0_I = Int64[]
    J0_J = Int64[]
    J0_V = Float64[]

    for i in eachindex(am.idx_to_bus)
        f_i_r = 2*i - 1
        f_i_i = 2*i

        for j in neighbors[i]
            x_j_fst = 2*j - 1
            x_j_snd = 2*j

            push!(J0_I, f_i_r); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
            push!(J0_I, f_i_r); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
            push!(J0_I, f_i_i); push!(J0_J, x_j_fst); push!(J0_V, 0.0)
            push!(J0_I, f_i_i); push!(J0_J, x_j_snd); push!(J0_V, 0.0)
        end
    end
    J0 = sparse(J0_I, J0_J, J0_V)

    return PowerFlowData(data, bus_gens, am, bus_type_idx, p_delta_base_idx, q_delta_base_idx, p_inject_idx, q_inject_idx, vm_idx, va_idx, neighbors, x0, F0, J0)
end



function compute_ac_pf(file::String; kwargs...)
    data = PowerModels.parse_file(file)
    return compute_ac_pf(data, kwargs...)
end

function compute_ac_pf(data::Dict{String,Any}; kwargs...)
    # TODO check invariants
    # single connected component
    # all buses of type 2/3 have generators on them

    #NB marta edit...
    #pf_data = instantiate_pf_data(data)
    #pf_data = data
    return compute_ac_pf(data, kwargs...)
end

function _compute_ac_pf(pf_data::PowerFlowData; finite_differencing=false, flat_start=false, kwargs...)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    x0 = pf_data.x0
    F0 = pf_data.F0
    J0 = pf_data.J0

    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] == 1
                vm_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = x[2*i - 1]
                q_inject_idx[i] = x[2*i]
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            balance_real = p_delta_base_idx[i] + p_inject_idx[i]
            balance_imag = q_delta_base_idx[i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] * real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * (real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) - imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            F[2*i - 1] = balance_real
            F[2*i] = balance_imag
        end

        # complex varaint of above
        # for i in eachindex(am.idx_to_bus)
        #     balance = p_inject_idx[i] + q_inject_idx[i]im
        #     for j in neighbors[i]
        #         balance += vm_idx[i] * vm_idx[j] * (am.matrix[i,j] * (cos(va_idx[i] - va_idx[j]) + sin(va_idx[i] - va_idx[j])im))
        #     end
        #     F[2*i - 1] = real(balance)
        #     F[2*i] = imag(balance)
        # end
    end


    # ac power flow, sparse jacobian computation
    function jsp!(J::SparseMatrixCSC{Float64,Int64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            f_i_r = 2*i - 1
            f_i_i = 2*i

            for j in neighbors[i]
                x_j_fst = 2*j - 1
                x_j_snd = 2*j

                bus_type = bus_type_idx[j]
                if bus_type == 1
                    if i == j
                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_fst] = 2*real(y_ii)*vm_idx[i] +            sum( real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) - imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_r, x_j_snd] =                         vm_idx[i] * sum( real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) - imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_fst] = 2*imag(y_ii)*vm_idx[i] +            sum( imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_i, x_j_snd] =                         vm_idx[i] * sum( imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_fst] =             vm_idx[i] * (real(y_ij) * cos(va_idx[i] - va_idx[j]) - imag(y_ij) *  sin(va_idx[i] - va_idx[j]))
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * (real(y_ij) * sin(va_idx[i] - va_idx[j]) - imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_fst] =             vm_idx[i] * (imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif bus_type == 2
                    if i == j
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 1.0

                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_snd] =              vm_idx[i] * sum( real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) - imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_snd] =              vm_idx[i] * sum( imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 0.0

                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * (real(y_ij) * sin(va_idx[i] - va_idx[j]) - imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif bus_type == 3
                    # p_inject_idx[i] = p_delta_base_idx[i] + x[2*i - 1]
                    # q_inject_idx[i] = q_delta_base_idx[i] + x[2*i]
                    if i == j
                        J[f_i_r, x_j_fst] = 1.0
                        J[f_i_r, x_j_snd] = 0.0
                        J[f_i_i, x_j_fst] = 0.0
                        J[f_i_i, x_j_snd] = 1.0
                    end
                else
                    @assert false
                end
            end
        end
    end


    # basic init point
    for i in eachindex(am.idx_to_bus)
        if bus_type_idx[i] == 1
            x0[2*i - 1] = 1.0 #vm
        elseif bus_type_idx[i] == 2
        elseif bus_type_idx[i] == 3
        else
            @assert false
        end
    end

    # warm-start point
    if !flat_start
        p_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        q_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        for (i,gen) in data["gen"]
            if gen["gen_status"] != 0
                if haskey(gen, "pg_start")
                    p_inject[gen["gen_bus"]] += gen["pg_start"]
                end
                if haskey(gen, "qg_start")
                    q_inject[gen["gen_bus"]] += gen["qg_start"]
                end
            end
        end

        for (i,shunt) in data["shunt"]
            if shunt["status"] != 0
                bus = data["bus"]["$(shunt["shunt_bus"])"]
                if haskey(bus, "vm_start")
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]*bus["vm_start"]^2
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]*bus["vm_start"]^2
                else
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]
                end
            end
        end

        for (i,bid) in enumerate(am.idx_to_bus)
            bus = data["bus"]["$(bid)"]
            if bus_type_idx[i] == 1
                if haskey(bus, "vm_start")
                    x0[2*i - 1] = bus["vm_start"]
                end
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 2
                x0[2*i - 1] = -q_inject[bid]
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 3
                x0[2*i - 1] = -p_inject[bid]
                x0[2*i] = -q_inject[bid]
            else
                @assert false
            end
        end
    end


    # this is where the magic happens
    if finite_differencing
        result = NLsolve.nlsolve(f!, x0; kwargs...)
    else
        df = NLsolve.OnceDifferentiable(f!, jsp!, x0, F0, J0)
        result = NLsolve.nlsolve(df, x0; kwargs...)
    end

    return result
end

function calc_admittance_matrix(data::Dict{String,<:Any})
    if length(data["dcline"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with dclines")
    end
    if length(data["switch"]) > 0
        Memento.error(_LOGGER, "calc_susceptance_matrix does not support data with switches")
    end

    #TODO check single connected component

    # NOTE currently exactly one reference bus is required
    ref_bus = reference_bus(data)

    buses = [x.second for x in data["bus"] if (x.second[pm_component_status["bus"]] != pm_component_status_inactive["bus"])]
    sort!(buses, by=x->x["index"])

    idx_to_bus = [x["index"] for x in buses]
    bus_to_idx = Dict(x["index"] => i for (i,x) in enumerate(buses))

    I = Int64[]
    J = Int64[]
    V = Complex{Float64}[]

    for (i,branch) in data["branch"]
        if branch[pm_component_status["branch"]] != pm_component_status_inactive["branch"]
            f_bus = bus_to_idx[branch["f_bus"]]
            t_bus = bus_to_idx[branch["t_bus"]]
            y = inv(branch["br_r"] + branch["br_x"]im)
            tr, ti = calc_branch_t(branch)
            t = tr + ti*im
            lc_fr = branch["g_fr"] + branch["b_fr"]im
            lc_to = branch["g_to"] + branch["b_to"]im
            push!(I, f_bus); push!(J, t_bus); push!(V, -conj(y)/t)
            push!(I, t_bus); push!(J, f_bus); push!(V, -conj(y/t))
            push!(I, f_bus); push!(J, f_bus); push!(V, conj(y + lc_fr)/abs2(t))
            push!(I, t_bus); push!(J, t_bus); push!(V, conj(y + lc_to))
        end
    end

    for (i,shunt) in data["shunt"]
        if shunt[pm_component_status["shunt"]] != pm_component_status_inactive["shunt"]
            bus = bus_to_idx[shunt["shunt_bus"]]

            ys = conj(shunt["gs"] + shunt["bs"]im)

            push!(I, bus); push!(J, bus); push!(V, ys)
        end
    end

    m = sparse(I,J,V)

    return AdmittanceMatrix(idx_to_bus, bus_to_idx, bus_to_idx[ref_bus["index"]], m)
end

function compute_ac_pf!(pf_data::PowerFlowData; kwargs...)
    result = _compute_ac_pf(pf_data, kwargs...)

    if !(result.x_converged || result.f_converged)
        Memento.warn(_LOGGER, "ac power flow solver convergence failed!  use `show_trace = true` for more details")
    end

    data = pf_data.data
    bus_gens = pf_data.bus_gens
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx


    for (i,bid) in enumerate(am.idx_to_bus)
        bus = data["bus"]["$(bid)"]

        if bus_type_idx[i] == 1
            @assert !haskey(bus_gens, bid)
            bus["vm"] = result.zero[2*i - 1]
            bus["va"] = result.zero[2*i]
        elseif bus_type_idx[i] == 2
            for gen in bus_gens[bid]
                gen["qg"] = 0.0
            end

            qg_remaining = -result.zero[2*i - 1]
            _assign_qg!(data["gen"], bus_gens[bid], qg_remaining)

            bus["va"] = result.zero[2*i]

        elseif bus_type_idx[i] == 3
            for gen in bus_gens[bid]
                gen["pg"] = 0.0
                gen["qg"] = 0.0
            end

            pg_remaining = -result.zero[2*i - 1]
            _assign_pg!(data["gen"], bus_gens[bid], pg_remaining)

            qg_remaining = -result.zero[2*i]
            _assign_qg!(data["gen"], bus_gens[bid], qg_remaining)
        else
            @assert false
        end
    end
end

function _assign_pg!(sol_gens::Dict{String,<:Any}, bus_gens::Vector, pg_remaining::Float64)
    for gen in bus_gens[1:end-1]
        pmin = gen["pmin"]
        pmax = gen["pmax"]

        if (pg_remaining <= 0.0 && pmin >= 0.0) || (pg_remaining >= 0.0 && pmax <= 0.0)
            # keep pg assignment as zero
            continue
        end

        sol_gen = sol_gens["$(gen["index"])"]
        if pg_remaining < pmin
            sol_gen["pg"] = pmin
        elseif pg_remaining > pmax
            sol_gen["pg"] = pmax
        else
            sol_gen["pg"] = pg_remaining
            pg_remaining = 0.0
            break
        end
        pg_remaining -= sol_gen["pg"]
    end
    if !isapprox(pg_remaining, 0.0)
        gen = bus_gens[end]
        sol_gen = sol_gens["$(gen["index"])"]
        sol_gen["pg"] = pg_remaining
    end
end


function _assign_qg!(sol_gens::Dict{String,<:Any}, bus_gens::Vector, qg_remaining::Float64)
    for gen in bus_gens[1:end-1]
        qmin = gen["qmin"]
        qmax = gen["qmax"]

        if (qg_remaining <= 0.0 && qmin >= 0.0) || (qg_remaining >= 0.0 && qmax <= 0.0)
            # keep qg assignment as zero
            continue
        end

        sol_gen = sol_gens["$(gen["index"])"]
        if qg_remaining < qmin
            sol_gen["qg"] = qmin
        elseif qg_remaining > qmax
            sol_gen["qg"] = qmax
        else
            sol_gen["qg"] = qg_remaining
            qg_remaining = 0.0
            break
        end
        qg_remaining -= sol_gen["qg"]
    end
    if !isapprox(qg_remaining, 0.0)
        gen = bus_gens[end]
        sol_gen = sol_gens["$(gen["index"])"]
        sol_gen["qg"] = qg_remaining
    end
end


function _compute_ac_pf(pf_data::PowerFlowData; finite_differencing=false, flat_start=false, kwargs...)
    data = pf_data.data
    am = pf_data.am
    bus_type_idx = pf_data.bus_type_idx
    p_delta_base_idx = pf_data.p_delta_base_idx
    q_delta_base_idx = pf_data.q_delta_base_idx
    p_inject_idx = pf_data.p_inject_idx
    q_inject_idx = pf_data.q_inject_idx
    vm_idx = pf_data.vm_idx
    va_idx = pf_data.va_idx
    neighbors = pf_data.neighbors
    x0 = pf_data.x0
    F0 = pf_data.F0
    J0 = pf_data.J0

    # ac power flow, nodal power balance function eval
    function f!(F::Vector{Float64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            if bus_type_idx[i] == 1
                vm_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
            elseif bus_type_idx[i] == 2
                q_inject_idx[i] = x[2*i - 1]
                va_idx[i] = x[2*i]
            elseif bus_type_idx[i] == 3
                p_inject_idx[i] = x[2*i - 1]
                q_inject_idx[i] = x[2*i]
            else
                @assert false
            end
        end

        for i in eachindex(am.idx_to_bus)
            balance_real = p_delta_base_idx[i] + p_inject_idx[i]
            balance_imag = q_delta_base_idx[i] + q_inject_idx[i]
            for j in neighbors[i]
                if i == j
                    balance_real += vm_idx[i] * vm_idx[i] * real(am.matrix[i,i])
                    balance_imag += vm_idx[i] * vm_idx[i] * imag(am.matrix[i,i])
                else
                    balance_real += vm_idx[i] * vm_idx[j] * (real(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) - imag(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                    balance_imag += vm_idx[i] * vm_idx[j] * (imag(am.matrix[i,j]) * cos(va_idx[i] - va_idx[j]) + real(am.matrix[i,j]) * sin(va_idx[i] - va_idx[j]))
                end
            end
            F[2*i - 1] = balance_real
            F[2*i] = balance_imag
        end

        # complex varaint of above
        # for i in eachindex(am.idx_to_bus)
        #     balance = p_inject_idx[i] + q_inject_idx[i]im
        #     for j in neighbors[i]
        #         balance += vm_idx[i] * vm_idx[j] * (am.matrix[i,j] * (cos(va_idx[i] - va_idx[j]) + sin(va_idx[i] - va_idx[j])im))
        #     end
        #     F[2*i - 1] = real(balance)
        #     F[2*i] = imag(balance)
        # end
    end


    # ac power flow, sparse jacobian computation
    function jsp!(J::SparseMatrixCSC{Float64,Int64}, x::Vector{Float64})
        for i in eachindex(am.idx_to_bus)
            f_i_r = 2*i - 1
            f_i_i = 2*i

            for j in neighbors[i]
                x_j_fst = 2*j - 1
                x_j_snd = 2*j

                bus_type = bus_type_idx[j]
                if bus_type == 1
                    if i == j
                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_fst] = 2*real(y_ii)*vm_idx[i] +            sum( real(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) - imag(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_r, x_j_snd] =                         vm_idx[i] * sum( real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) - imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_fst] = 2*imag(y_ii)*vm_idx[i] +            sum( imag(am.matrix[i,k]) * vm_idx[k] *  cos(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * sin(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                        J[f_i_i, x_j_snd] =                         vm_idx[i] * sum( imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_fst] =             vm_idx[i] * (real(y_ij) * cos(va_idx[i] - va_idx[j]) - imag(y_ij) *  sin(va_idx[i] - va_idx[j]))
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * (real(y_ij) * sin(va_idx[i] - va_idx[j]) - imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_fst] =             vm_idx[i] * (imag(y_ij) * cos(va_idx[i] - va_idx[j]) + real(y_ij) *  sin(va_idx[i] - va_idx[j]))
                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif bus_type == 2
                    if i == j
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 1.0

                        y_ii = am.matrix[i,i]
                        J[f_i_r, x_j_snd] =              vm_idx[i] * sum( real(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) - imag(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)

                        J[f_i_i, x_j_snd] =              vm_idx[i] * sum( imag(am.matrix[i,k]) * vm_idx[k] * -sin(va_idx[i] - va_idx[k]) + real(am.matrix[i,k]) * vm_idx[k] * cos(va_idx[i] - va_idx[k]) for k in neighbors[i] if k != i)
                    else
                        J[f_i_r, x_j_fst] = 0.0
                        J[f_i_i, x_j_fst] = 0.0

                        y_ij = am.matrix[i,j]
                        J[f_i_r, x_j_snd] = vm_idx[i] * vm_idx[j] * (real(y_ij) * sin(va_idx[i] - va_idx[j]) - imag(y_ij) * -cos(va_idx[i] - va_idx[j]))

                        J[f_i_i, x_j_snd] = vm_idx[i] * vm_idx[j] * (imag(y_ij) * sin(va_idx[i] - va_idx[j]) + real(y_ij) * -cos(va_idx[i] - va_idx[j]))
                    end
                elseif bus_type == 3
                    # p_inject_idx[i] = p_delta_base_idx[i] + x[2*i - 1]
                    # q_inject_idx[i] = q_delta_base_idx[i] + x[2*i]
                    if i == j
                        J[f_i_r, x_j_fst] = 1.0
                        J[f_i_r, x_j_snd] = 0.0
                        J[f_i_i, x_j_fst] = 0.0
                        J[f_i_i, x_j_snd] = 1.0
                    end
                else
                    @assert false
                end
            end
        end
    end


    # basic init point
    for i in eachindex(am.idx_to_bus)
        if bus_type_idx[i] == 1
            x0[2*i - 1] = 1.0 #vm
        elseif bus_type_idx[i] == 2
        elseif bus_type_idx[i] == 3
        else
            @assert false
        end
    end

    # warm-start point
    if !flat_start
        p_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        q_inject = Dict{Int,Float64}(bus["index"] => 0.0 for (i,bus) in data["bus"])
        for (i,gen) in data["gen"]
            if gen["gen_status"] != 0
                if haskey(gen, "pg_start")
                    p_inject[gen["gen_bus"]] += gen["pg_start"]
                end
                if haskey(gen, "qg_start")
                    q_inject[gen["gen_bus"]] += gen["qg_start"]
                end
            end
        end

        for (i,shunt) in data["shunt"]
            if shunt["status"] != 0
                bus = data["bus"]["$(shunt["shunt_bus"])"]
                if haskey(bus, "vm_start")
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]*bus["vm_start"]^2
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]*bus["vm_start"]^2
                else
                    p_inject[shunt["shunt_bus"]] += shunt["gs"]
                    p_inject[shunt["shunt_bus"]] -= shunt["bs"]
                end
            end
        end

        for (i,bid) in enumerate(am.idx_to_bus)
            bus = data["bus"]["$(bid)"]
            if bus_type_idx[i] == 1
                if haskey(bus, "vm_start")
                    x0[2*i - 1] = bus["vm_start"]
                end
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 2
                x0[2*i - 1] = -q_inject[bid]
                if haskey(bus, "va_start")
                    x0[2*i] = bus["va_start"]
                end
            elseif bus_type_idx[i] == 3
                x0[2*i - 1] = -p_inject[bid]
                x0[2*i] = -q_inject[bid]
            else
                @assert false
            end
        end
    end


    # this is where the magic happens
    if finite_differencing
        result = NLsolve.nlsolve(f!, x0; kwargs...)
    else
        df = NLsolve.OnceDifferentiable(f!, jsp!, x0, F0, J0)
        result = NLsolve.nlsolve(df, x0; kwargs...)
    end

    return result
end
