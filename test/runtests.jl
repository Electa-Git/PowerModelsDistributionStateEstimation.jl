################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

# using pkgs
using Distributions
using HDF5
using Ipopt
using Polynomials
using PowerModels, PowerModelsDistribution
using PowerModelsDistributionStateEstimation
#using SCS #removed while SDP tests are not active
using Test

# pkg const
const _DST = Distributions
const _PMD = PowerModelsDistribution
const _PMDSE = PowerModelsDistributionStateEstimation
const _Poly = Polynomials

#network and feeder from ENWL for tests
ntw, fdr = 4, 2

season     = "summer"
time_step  = 144
elm        = ["load", "pv"]
pfs        = [0.95, 0.90]
rm_transfo = true
rd_lines   = true

# set solvers
ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>300.0,
                                                              "tol"=>1e-9,
                                                              "print_level"=>0)

# scs_solver = optimizer_with_attributes(SCS.Optimizer, "max_iters"=>20000, "eps"=>1e-5,
#                                                             "alpha"=>0.4, "verbose"=>0) #deactivated while SDP tests not active


@testset "PowerModelsDistributionStateEstimation" begin

    include("bad_data.jl")
    include("distributions.jl")
    include("estimation_criteria.jl")
    include("mixed_measurements.jl")
    include("non_exact_forms.jl")
    include("power_flow.jl")
    include("pseudo_measurements.jl")
    include("single_conductor_branches.jl")
    include("utils_and_start_val.jl")
    include("with_errors.jl")

end
ambiguities = Test.detect_ambiguities(PowerModelsDistributionStateEstimation);
if !isempty(ambiguities)
    println("ambiguities detected: $ambiguities")
end