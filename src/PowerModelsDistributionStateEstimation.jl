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
import CSV
import DataFrames
import Distributions
import Distributions: logpdf, gradlogpdf
import GaussianMixtures
import InfrastructureModels
import JuMP
import LinearAlgebra: diag
import Logging, LoggingExtras
import Optim
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
const _GMM = GaussianMixtures
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
    global _DEFAULT_LOGGER = Logging.currentlogger()
    global _LOGGER = Logging.ConsoleLogger(; meta_formatter = PowerModelsDistributionStateEstimation._pmdse_metafmt)
    
    Logging.global_logger(_LOGGER)
end

# include
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
include("io/postprocessing.jl")

include("prob/se.jl")

# export
export BASE_DIR
export minimum, maximum
export logpdf, gradlogpdf, heslogpdf
export run_mc_se, run_acp_mc_se, run_acr_mc_se, run_ivr_mc_se
export solve_mc_se, solve_acp_mc_se, solve_acr_mc_se, solve_ivr_mc_se
export rm_enwl_transformer!, reduce_enwl_lines_eng!
export add_measurements!, write_measurements!, assign_load_pseudo_measurement_info!
export assign_unique_individual_criterion!, assign_basic_individual_criteria!
export assign_start_to_variables!, assign_residual_ub!
export reduce_single_phase_loadbuses!
export calculate_voltage_magnitude_error
export update_load_bounds!, update_voltage_bounds!, update_generator_bounds!, update_all_bounds!
export ExtendedBeta

end
