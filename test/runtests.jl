using PowerModelsDSSE, Ipopt, SCS, JuMP, PowerModels, PowerModelsDistribution
using Test

_PMD = PowerModelsDistribution
_PMs = PowerModels

ipopt_solver_se = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "hessian_approximation"=>"limited-memory", "print_level"=>2)
ipopt_solver_pf = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>0)
scs_solver = optimizer_with_attributes(SCS.Optimizer, "max_iters"=>20000, "eps"=>1e-5, "alpha"=>0.4, "verbose"=>0)

@testset "PowerModelsDSSE" begin

    include("sdp_se.jl")
    include("exact_native_se.jl")
    include("variable_conversion.jl")

end
