################################################################################
#  Copyright 2020, Tom Van Acker, Marta Vanin                                  #
################################################################################
# PowerModelsDSSE.jl                                                           #
# An extention package of PowerModelsDistribution.jl for Static Distribution   #
# System State Estimation.                                                     #
# See http://github.com/timmyfaraday/PowerModelsDSSE.jl                        #
################################################################################

module PowerModelsDSSE

# import pkgs
import CSV
import DataFrames
import Distributions
import InfrastructureModels
import JuMP
import PowerModels
import PowerModelsDistribution
import Random
import Statistics

# pkg const
const _CSV = CSV
const _DFS = DataFrames
const _DST = Distributions
const _IM  = InfrastructureModels
const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _RAN = Random
const _STT = Statistics

# paths
const BASE_DIR = dirname(@__DIR__)

#include
include("core/adapted_pmd_constraints.jl")
include("core/constraint.jl")
include("core/measurement_conversion.jl")
include("core/objective.jl")
include("core/start_values_methods.jl")
include("core/variable.jl")

include("form/no_shunt_ac.jl")
include("form/no_shunt_ivr.jl")

include("io/measurement_parser.jl")
include("io/network_parser.jl")
include("io/postprocessing.jl")

include("prob/se.jl")
include("prob/reduced_pf.jl")
include("prob/reduced_se.jl")

#export
export BASE_DIR
export run_mc_se, run_acp_mc_se, run_acr_mc_se, run_ivr_mc_se
export rm_enwl_transformer!, reduce_enwl_lines_eng!
export add_measurements!, write_measurements!
export assign_start_to_variables!
export calculate_voltage_magnitude_error

end
