"""
    simple_normalized_residuals(data::Dict, se_sol::Dict, state_estimation_type::String; rescaler::Float64=1.0)
It normalizes the residuals only based on their standard deviation, no sensitivity matrix involved.
Avoids all the matrix calculations but is relatively rudimental
"""
function simple_normalized_residuals(data::Dict, se_sol::Dict, state_estimation_type::String; rescaler::Float64=1.0)
    if occursin(state_estimation_type, "wls")
        p = 2
    elseif occursin(state_estimation_type, "wlav")
        p = 1
    else
        error("This method works only with (r)wls and (r)wlav state estimation")
    end
    for (m, meas) in se_sol["solution"]["meas"]
        meas["norm_res"] = abs.(meas["res"])./_DST.std.(data["meas"][m]["dst"]).^p*rescaler
    end
end

"""
Adds the normalized residuals to the solution dictionary and returns the largest normalized residual,
its index (i.e., the measurement it refers to), and whether it exceeds the given threshold `t` or not.
"""
function normalized_residuals(se_sol::Dict, Ω::Matrix; t::Float64=3.0, resc::Float64=1.0)
    lnr = ("0", 0)
    for (m, meas) in se_sol["solution"]["meas"]
        meas["nr"] = [abs(meas["res"][i])*resc/sqrt(abs(Ω[parse(Int64,m)+i-1, parse(Int64,m)+i-1])) for i in 1:length(meas["res"])]
        for i in 1:length(meas["res"]) 
            if meas["nr"][i] > last(lnr) lnr = ("$(parse(Int64,m)+i-1)", meas["nr"][i]) end
        end
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
Ωᵢᵢ = Rᵢᵢ⋅Sᵢᵢ = R - H*G^(-1)*H^T
S = I - K       # <- sensitivity matrix, no need to calculate it for bad data purposes  
K = H⋅G⁻¹⋅Hᵀ⋅R⁻¹ # <- hat matrix, no need to calculate it for bad data purposes
"""
build_omega_matrix(R::Matrix{Float64}, H::Matrix{Float64}, G::Matrix{Float64}) = R - H*inv(G)*transpose(H)