# Quick Start Guide


To perform a state estimation (SE), a network data file (e.g. `"case3_unbalanced.dss"` in `../test/data/extra/networks`) needs to be acquired, together with its related measurement file (e.g. `"case3_meas.csv"` in `../test/data/extra/measurements`). The absolute path to the package is provided through the constant `BASE_DIR`. Network and measurement data will be merged and a SE can be run as follows:
```julia
using PowerModelsDistribution, PowerModelsDistributionStateEstimation
using JuMP, Ipopt

#full paths to files
ntw_path = joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss")
msr_path = joinpath(BASE_DIR, "test/data/extra/measurements/case3_meas.csv")

#parse network data file
data = PowerModelsDistribution.parse_file(ntw_path; data_model=MATHEMATICAL)

#add measurement data to network data file
add_measurements!(data, msr_path, actual_meas = true)

#set state estimation settings
data["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1)

#set solver parameters
slv = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)

#run state estimation
se_result = solve_acp_mc_se(data, slv)
```
The run commands return detailed results in the form of a dictionary, following PowerModelsDistribution format, and can be saved for future processing, like in `se_result` above.

## Accessing Different Formulations

Different run functions correspond to different formulations. The function `solve_acp_mc_se` uses the AC Polar form, `solve_acr_mc_se` uses the AC rectangular, etc. Alternatively, the formulation type can directly be passed to the generic `solve_mc_se` function:
```julia
solve_mc_se(data, ACPUPowerModel, slv)
```
It should be noted that not all solvers can handle all problem types. For example, to use the SDP formulation, you have to use a SDP-capable solver, such as the open-source solver SCS.

## Providing a Warm Start

Providing a (good) initial value to some or all optimization variables can reduce the number of solver iterations. PowerModelsDistributionStateEstimation provides the `assign_start_to_variables!` function.
```@docs
assign_start_to_variables!(data)
```
```@docs
assign_start_to_variables!(data, start_values_source)
```
Alternatively, the user can directly assign a value or vector (depending on the dimensions of the variable) in the data dictionary, under the key `variablename_start`. The example below shows how to do it for the `vm` and `va` variables.
```julia
data = parse_file("case3_unbalanced.dss"; data_model=MATHEMATICAL)
data["bus"]["2"]["vm_start"] = [0.996, 0.996, 0.996]
data["bus"]["2"]["va_start"] = [0.00, -2.0944, 2.0944]
```
It should be noted that providing a bad initial value might result in longer calculation times or convergence issues, so the start value assignment should be done cautiously.
If no initial value is provided, a flat start is assigned by default. The default initial value of each variable is indicated in the function where the variable is defined, as the last argument of the `comp_start_value` function (this is valid for both imported PowerModelsDistribution and native PowerModelsDistributionStateEstimation variables).

## Updating Variable Bounds

In constrained optimization, reducing the search space might be an effective way to reduce solver time. Search space reduction can be done by assigning bounds to the variables.
This must also be done attentively, though, to make sure that the feasible space is not cut, i.e., that feasible solutions are not removed by this process.
This can be avoided if good knowledge of the system is available or if some variable have particularly obvious bounds, e.g., voltage magnitude cannot be negative, so its lower bound can be set to 0 without risk.
Similar to providing a warm start, it is to user discretion to assign meaningful and "safe" variable bounds.
PowerModelsDistributionStateEstimation has functions that allow to define bounds on voltage magnitude, power generation (active and reactive) or power demand (active and reactive):
```@docs
update_voltage_bounds!(data::Dict; v_min=0.0, v_max=Inf)
```
```@docs
update_generator_bounds!(data::Dict; p_min::Float64=0.0, p_max::Float64=Inf, q_min::Float64=-Inf, q_max::Float64=Inf)
```
```@docs
update_load_bounds!(data::Dict; p_min::Float64=0.0, p_max::Float64=Inf, q_min::Float64=-Inf, q_max::Float64=Inf)
```
or, alternatively, all the above at once:
```@docs
update_all_bounds!(data::Dict; v_min::Float64=0.0, v_max::Float64=Inf, pg_min::Float64=0.0, pg_max::Float64=Inf, qg_min::Float64=-Inf, qg_max::Float64=Inf, pd_min::Float64=0.0, pd_max::Float64=Inf, qd_min::Float64=-Inf, qd_max::Float64=Inf)
```
Alternatively, the user can directly assign a value or vector (depending on the dimensions of the variable) in the data dictionary, under the key `variablenamemin`/`variablenamemax`. The example below shows how to do it for the active power.
```julia
data["load"]["1"]["pmax"] = [1.0, 1.0, 1.0]
data["load"]["1"]["pmin"] = [0.0, 0.0, 0.0]
```
### Updating Residual Bounds

Residuals are a type of variable that is specific to the state estimation problem (and not, e.g., of power flow studies). If you do not know what a residual is, please read the [Problem Specifications](@ref) section of the documentation.
While the residuals as defined in the present package are always non-negative (default lower bound is 0), there is no default upper bound.
A function is available to add customized upper bounds:
```@docs
assign_residual_ub!(data::Dict; chosen_upper_bound::Float64=100.0, rescale::Bool=false)
```