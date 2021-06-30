"""
    simple_normalized_residuals(data::Dict, se_sol::Dict, R::Matrix)
It normalizes the residuals only based on their standard deviation, no sensitivity matrix involved.
R^2 replaces Ω, where Ω = S ⋅ R
Avoids all the matrix calculations but is a "simplified" method
"""
function simple_normalized_residuals(data::Dict, se_sol::Dict, R::Matrix)
    normalized_residuals(data, se_sol, R.^2)
end
"""
Adds the normalized residuals to the solution dictionary and returns the largest normalized residual,
its index (i.e., the measurement it refers to), and whether it exceeds the given threshold `t` or not.
"""
function normalized_residuals(data::Dict, se_sol::Dict, Ω::Matrix; t::Float64=3.0)
    lnr = ("0", 0)
    count = 1
    for (m, meas) in data["meas"]
        if !haskey(se_sol["solution"][string(meas["cmp"])], string(meas["cmp_id"]))
            r = [0.0, 0.0, 0.0]
            se_sol["solution"]["meas"][m]["r"] = [0.0, 0.0, 0.0]
        else
            h_x = se_sol["solution"][string(meas["cmp"])][string(meas["cmp_id"])][string(meas["var"])]
            z = _DST.mean.(meas["dst"])
            r = abs.(h_x-z)
            se_sol["solution"]["meas"][m]["r"] = r
        end
        se_sol["solution"]["meas"][m]["nr"] = [r[i]/sqrt(abs(Ω[count+i-1, count+i-1])) for i in 1:length(meas["dst"])]
        for i in 1:length(meas["dst"]) 
            if  se_sol["solution"]["meas"][m]["nr"][i] > last(lnr) lnr = (m,  se_sol["solution"]["meas"][m]["nr"][i]) end
        end
        count+=length(meas["dst"])
    end
    return lnr, last(lnr) > t
end
"""
Returns the Measurement Jacobian H
"""
function build_H_matrix(functions::Vector, state::Array)::Matrix{Float64}
    H = Matrix{Float64}(undef, length(functions), length(state))
    for row in 1:length(functions)
        H[row,:] = ForwardDiff.gradient(functions[row], state)
    end
    return H
end
"""
Returns the Gain Matrix G
"""
build_G_matrix(H::Matrix, R::Matrix)::Matrix{Float64} = transpose(H)*inv(R)*H
"""
Returns the Measurement Error Covariance Matrix R
"""
function build_R_matrix(data::Dict)::Matrix{Float64}
    meas_row_order = [m for (m, _) in data["meas"]]
    R_entries = vcat([_DST.std.(data["meas"][mid]["dst"])[1:length(data["meas"][mid]["dst"])] for mid in meas_row_order]...)
    return LinearAlgebra.diagm(R_entries.^2)
end
"""
Returns the Residual Covariance Matrix Ω, where:
Ω = R - H*G^(-1)*H^T
"""
build_omega_matrix(R::Matrix{Float64}, H::Matrix{Float64}, G::Matrix{Float64}) = R - H*inv(G)*transpose(H)
"""
Returns the Residual Covariance Matrix Ω, where:
Ωᵢᵢ = Rᵢᵢ⋅Sᵢᵢ
"""
build_omega_matrix(S::Matrix{Float64}, R::Matrix{Float64}) = diagm((sqrt.(abs.(diag(S).*diag(R)))))
"""
Returns the sensitivity matrix S starting from the hat matrix K
"""
build_S_matrix(K::Matrix{Float64}) = Matrix{Int64}(I, size(K)) - K 
"""
Returns the hat matrix K
"""
build_K_matrix(H::Matrix{Float64}, G::Matrix{Float64}, R::Matrix{Float64}) = H*inv(G)*transpose(H)*inv(R)