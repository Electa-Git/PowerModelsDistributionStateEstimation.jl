################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

import PowerModelsDistributionStateEstimation as _PMDSE

# import pkgs
import Distributions as _DST
import HDF5
import Ipopt
import Polynomials as _Poly
import PowerModels
import PowerModelsDistribution as _PMD
import Statistics
using Test

#network and feeder from ENWL for tests
ntw, fdr = 4, 2

season     = "summer"
time_step  = 144
elm        = ["load", "pv"]
pfs        = [0.95, 0.90]
rm_transfo = true
rd_lines   = true

# set solvers
ipopt_solver = _PMDSE.optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time" => 300.0,
                                                         "obj_scaling_factor" => 1e3,
                                                         "tol" => 1e-9,
                                                         "print_level" => 0, 
                                                         "mu_strategy" => "adaptive")

# scs_solver = _PMDSE.optimizer_with_attributes(SCS.Optimizer, "max_iters"=>20000, "eps"=>1e-5,
#                                                             "alpha"=>0.4, "verbose"=>0) #deactivated while SDP tests not active

@testset "PowerModelsDistributionStateEstimation" begin
    include("bad_data.jl")
    include("distributions.jl")
    include("estimation_criteria.jl")
    include("ivren.jl")
    include("mixed_measurements.jl")
    include("non_exact_forms.jl")
    include("power_flow.jl")
    include("pseudo_measurements.jl")
    include("reference_angles.jl")
    include("single_conductor_branches.jl")
    include("utils_and_start_val.jl")
    include("with_errors.jl")
end

ambiguities = Test.detect_ambiguities(_PMDSE);
if !isempty(ambiguities)
    println("ambiguities detected: $ambiguities")
end