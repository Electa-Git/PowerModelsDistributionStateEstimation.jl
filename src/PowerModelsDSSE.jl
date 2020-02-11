module PowerModelsDSSE

## To add dependency packages, follow the following steps:
#   In the REPL
#   - go to the pkg-manager, using: ]
#   - activate PowerModelsDSSE, using: activate PowerModelsDSSE
#   - add the dependency package, using: add package_name
#   In file: Project.toml
#   - add pkg version in compat section, adding: package_name = "version_number"
#   In the REPL
#   - resolve the pkg, using: Pkg.resolve()

using JuMP
using PowerModels
using Distributions
using PowerModelsDistribution

const _PMs = PowerModels
const _DST = Distributions
const _PMD = PowerModelsDistribution

include("core/variable.jl")
include("core/constraint.jl")
include("core/objective.jl")

include("prob/se.jl")

end
