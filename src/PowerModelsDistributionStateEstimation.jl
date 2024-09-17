################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
module PowerModelsDistributionStateEstimation

# import pkgs
import Base: maximum, minimum, rand
import CSV, DataFrames
import Distributions
import Distributions: logpdf, gradlogpdf
import ForwardDiff
import InfrastructureModels
import JuMP
import LinearAlgebra
import LinearAlgebra: diag, diagm, I
import Logging, LoggingExtras
import Optim
import Polynomials as _Poly
import PowerModelsDistribution
import PowerModelsDistribution: _has_nl_expression #need this to use @smart_constraint
import Random
import SpecialFunctions
import Statistics

#import and export so that users do not need to import JuMP to use a solver
import JuMP: optimizer_with_attributes
export optimizer_with_attributes

# pkg const
const _CSV = CSV
const _DFS = DataFrames
const _DST = Distributions
const _IM  = InfrastructureModels
const _PMD = PowerModelsDistribution
const _PMDSE = PowerModelsDistributionStateEstimation
const _RAN = Random
const _SF  = SpecialFunctions
const _STT = Statistics

# paths
const BASE_DIR = dirname(@__DIR__)

# fix a random seed
#_RAN.seed!(1234);

# logger for errors and warnings, etc.

include("core/logging.jl")
function __init__()
    global _DEFAULT_LOGGER = Logging.current_logger()
    global _LOGGER = Logging.ConsoleLogger(; meta_formatter = PowerModelsDistributionStateEstimation._pmdse_metafmt)
    
    Logging.global_logger(_LOGGER)
end

display("HEY! YOU ARE CURRENTLY RUNNING THE `adrian_quickdelta` BRANCH OF THE PMDSE PACKAGE, JUST SO YOU KNOW!")

# include
include("bad_data/chi_squares_test.jl")
include("bad_data/largest_normalized_residuals.jl")
include("bad_data/measurement_functions.jl")
include("bad_data/utils.jl")

include("core/constraint.jl")
include("core/measurement_conversion.jl")
include("core/objective.jl")
include("core/start_values_methods.jl")
include("core/utils.jl")
include("core/variable.jl")

include("form/adapted_pmd_constraints.jl")
include("form/reduced_ac.jl")
include("form/reduced_ivr.jl")

include("io/distributions.jl")
include("io/measurement_parser.jl")
include("io/network_parser.jl")
include("io/polynomials.jl")
include("io/postprocessing.jl")

include("prob/se.jl")

# quick fixes for adrian project that cannot wait the next release
include("adrian_quickextras/delta_users.jl")

# export
include("core/export.jl")

end
