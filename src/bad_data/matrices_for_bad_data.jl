function build_H_matrix(functions::Vector, state::Array)
    H = Matrix(undef, length(functions), length(state))
    for row in 1:length(functions)
        H[row,:] = ForwardDiff.gradient(functions[row], state)
    end
    return H
end

# NB: G is positive definite
function build_G_matrix(H::Matrix, R::Matrix)
    return transpose(H)*inv(R)*H
end

function build_R_matrix(data::Dict)
    meas_row_order = [m for (m, meas) in data["meas"]]
    R_entries = vcat([_DST.std.(data["meas"][mid]["dst"])[1:length(data["meas"][mid]["dst"])] for mid in meas_row_order]...)
    return LinearAlgebra.diagm(R_entries.^2)
end
"""
# Ωᵢᵢ = Rᵢᵢ⋅Sᵢᵢ = R - H*G^(-1)*H^T
# S = I - K       # <- sensitivity matrix, no need to calculate it  
# K = H⋅G⁻¹⋅Hᵀ⋅R⁻¹ # <- hat matrix, no need to calculate it
"""
function build_omega_matrix(R::Matrix, H::Matrix, G::Matrix)
    return R - H*inv(G)*transpose(H)
end