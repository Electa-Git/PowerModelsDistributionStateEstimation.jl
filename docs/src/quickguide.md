# Quick Start Guide

Once PowerModelsDSSE is installed, together with its dependencies, install Ipopt and SCS. These are needed to solve non-convex and convex problems, respectively.
To run a simulation, a network data file (e.g. `"case3_unbalanced.dss"` in the package folder under `/test/data/opendss`) needs to be acquired, together with its relative measurement file (e.g. `"case3_input.csv"` in the package folder under `/test/data/`). Network and measurement data will be merged and a SE example can be run as follow:

```julia
using PowerModelsDSSE, PowerModelsDistribution
using Ipopt

_PMD = PowerModelsDistribution

data = parse_file("test/data/opendss/case3_unbalanced.dss")
pmd_data = _PMD.transform_data_model(data)
meas_file = "test/data/case3_input.csv"
add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)
add_measurement_id_to_load!(pmd_data, meas_file)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wls",
                                        "rescale_weight" => 1)

se_result = run_ivr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
```
The run commands return detailed results data in the form of a dictionary, following PowerModelsDistribution format, and can be saved for further processing, as above.

## Accessing Different Formulations

To different formulations correspond different run functions. The function "run_acp_mc_se" uses the AC Polar form, "run_acr_mc_se" uses the AC rectangular, etc.
