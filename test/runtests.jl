using PowerModelsDSSE
using Test

@testset "PowerModelsDSSE" begin

    include("estimation_examples.jl")
    include("io_handling.jl")
end
# using SafeTestsets
# @safetestset "my_f_tests" begin include("my_f_tests.jl") end
