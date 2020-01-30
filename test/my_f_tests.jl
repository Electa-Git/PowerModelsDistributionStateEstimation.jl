using PowerModelsDSSE
using Test

@testset "PowerModelsDSSE.jl" begin
    @test my_f(2,1) == 7
    @test my_f(1,2) == 8
end

@testset "derivatives" begin
    @test derivative_of_my_f(2,1) == 2
end
