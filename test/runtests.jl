using PowerModelsDSSE, Ipopt, SCS
using Test

ipopt_solver_se = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "hessian_approximation"=>"limited-memory", "print_level"=>0)
ipopt_solver_pf = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>0)
scs_solver = optimizer_with_attributes(SCS.Optimizer, "max_iters"=>20000, "eps"=>1e-5, "alpha"=>0.4, "verbose"=>0)
@testset "PowerModelsDSSE" begin

    include("native_se.jl")

end
