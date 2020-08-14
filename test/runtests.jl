################################################################################
#  Copyright 2020, Tom Van Acker, Marta Vanin                                  #
################################################################################
# PowerModelsDSSE.jl                                                           #
# An extention package of PowerModelsDistribution.jl for Static Distribution   #
# System State Estimation.                                                     #
# See http://github.com/timmyfaraday/PowerModelsDSSE.jl                        #
################################################################################

# using pkgs
using Ipopt
using JuMP
using PowerModels
using PowerModelsDistribution
using PowerModelsDSSE
using Test

# pkg const
const _JMP = JuMP
const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _PMS = PowerModelsDSSE

# set solvers
ipopt_solver = _JMP.optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>100.0,
                                                              "tol"=>1e-10,
                                                              "print_level"=>0)

@testset "PowerModelsDSSE" begin

    include("power_flow.jl")

end
