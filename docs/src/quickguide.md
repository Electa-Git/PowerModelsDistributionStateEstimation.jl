# Quick Start Guide

Once PowerModelsDSSE and PowerModelsDistribution are installed, the user should install a solver, such as Ipopt. Here, Ipopt is chosen because it can solve a large variety of problems, including non-convex ones.
To run a simulation, a network data file (e.g. `"case3_unbalanced.dss"` in the package folder under `/test/data/extra/networks`) needs to be acquired, together with its relative measurement file (e.g. `"case3_meas.csv"` in the package folder under `/test/data/extra/measurements`). Network and measurement data will be merged and a SE example can be run as follows:

```julia
using PowerModelsDSSE, PowerModelsDistribution
using Ipopt

_PMD = PowerModelsDistribution
pmd_data = _PMD.parse_file("test/data/extra/networks/case3_unbalanced.dss"; data_model=MATHEMATICAL)
meas_file = "test/data/extra/measurements/case3_meas.csv"
add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)
pmd_data["se_settings"] = Dict{String,Any}("estimation_criterion" => "rwls",
                                        "rescale_weight" => 1)

run_acp_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
```
The run commands return detailed results data in the form of a dictionary, following PowerModelsDistribution format, and can be saved for further processing, like in "se_result" below:

```julia
se_result = run_acp_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
```

## Parsing files

As can be observed in the example above, the PowerModelsDistribution parser is invoke to parse the network data from an OpenDSS file.
The function to parse measurement data from CSV files, on the other hand, is made available in PowerModelsDSSE itself.

## Accessing Different Formulations

To different formulations correspond different run functions. The function "run_acp_mc_se" uses the AC Polar form, "run_acr_mc_se" uses the AC rectangular, and so on for every formulation. Alternatively, the formulation type can directly be passed to the generic `run_mc_se` function:
```julia
run_mc_se(data, ACPPowerModel, with_optimizer(Ipopt.Optimizer))
```
It should be noted that not all solvers can handle all problem types. For example, to use the SDP formulation, you have to use a SDP-capable solver, such as the open-source solver SCS. Which solver to use left to the user's discretion and availability.

## Providing a Warm Start

Providing a (good) initial value to some or all optimization variables can reduce the number of solver iterations. PowerModelsDSSE provides the `assign_start_to_variables!` function.
- calling `assign_start_to_variables!(data)` takes the value of the measurement from the state estimation data dictionary and assigns them a starting value to their associated variable.
- calling `assign_start_to_variables!(data, other_dict)` assigns starting values to the problem variables based on a dictionary where they are collected: `other_dict`. NB: This dictionary must have a form similar to that of a powerflow solution dictionary, to make sure that the right starting value is associated to the right variable.
Alternatively, the user can directly assign a value or vector (depending on the dimensions of the variable) in the data dictionary, under the key `variablename_start`. The example below shows how to do it for the `vm` and `va` variables.
```julia
data = _PMD.parse_file("case3_unbalanced.dss"; data_model=MATHEMATICAL)
data["bus"]["2"]["vm_start"] = [0.996, 0.996, 0.996]
data["bus"]["2"]["va_start"] = [0.00, -2.0944, 2.0944]
```
It should be noted that providing a bad initial value might result in longer calculation times or convergence issues, so the start value assignment should be done cautiously.
If no initial value is provided, a flat start is assigned by default. The default initial value of each variable is indicated in the function where the variable is defined, as the last argument of the `comp_start_value` function (this is valid for both imported PowerModelsDistribution and original PowerModelsDSSE variables). In the case of `vm`, this is 1.0 (in per unit), as shown below:
```julia
vm = _PMD.var(pm, nw)[:vm] = Dict(i => JuMP.@variable(pm.model,
        [c in 1:ncnds], base_name="$(nw)_vm_$(i)",
        start = _PMD.comp_start_value(_PMD.ref(pm, nw, :bus, i), "vm_start", c, 1.0)
    ) for i in _PMD.ids(pm, nw, :bus)
)
```

## Providing Variable Bounds

In constrained optimization, reducing the search space might be an effective way to reduce solver time. Search space reduction can be done by assigning bounds to the variables.
This must also be done attentively, though, to make sure that the feasible space is not cut, i.e., that feasible solutions are not removed by this process.
This can be avoided if good knowledge of the system is available or if some variable have particularly obvious bounds, e.g., voltage magnitude cannot be negative, so its lower bound can be set to 0 without risks.
As when providing a warm start, it is to user discretion to assign meaningful and "safe" variable bounds.
PowerModelsDSSE has functions that allow to define bounds on voltage magnitude, power generation (active and reactive) or power demand (active and reactive):
`update_voltage_bounds!(data::Dict; v_min::Float64=0.0, v_max::Float64=Inf)`
`update_generator_bounds!(data::Dict; p_min::Float64=0.0, p_max::Float64=Inf, q_min::Float64=-Inf, q_max::Float64=Inf)`
`update_load_bounds!(data::Dict; p_min::Float64=0.0, p_max::Float64=Inf, q_min::Float64=-Inf, q_max::Float64=Inf)`
or, alternatively, all the above at once:
`update_all_bounds!(data::Dict; v_min::Float64=0.0, v_max::Float64=Inf, pg_min::Float64=0.0, pg_max::Float64=Inf, qg_min::Float64=-Inf, qg_max::Float64=Inf, pd_min::Float64=0.0, pd_max::Float64=Inf, qd_min::Float64=-Inf, qd_max::Float64=Inf)`
Bounds can also in general be added to any other variable which in its definition allows JuMP to set lower and/or upper bounds:
```julia
function variable_mc_load_active(pm::_PMs.AbstractPowerModel;
                                 nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    cnds = _PMD.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)

    pd = _PMD.var(pm, nw)[:pd] = Dict(i => JuMP.@variable(pm.model,
            [c in 1:ncnds], base_name="$(nw)_pd_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "pd_start",c, 0.0)
        ) for i in _PMD.ids(pm, nw, :load)
    )

    if bounded
        for (i,load) in _PMD.ref(pm, nw, :load)
            if haskey(load, "pmin")
                JuMP.set_lower_bound.(pd[i], load["pmin"])
            end
            if haskey(load, "pmax")
                JuMP.set_upper_bound.(pd[i], load["pmax"])
            end
        end
    end

    report && _IM.sol_component_value(pm, nw, :load, :pd, _PMD.ids(pm, nw, :load), pd)
end
```
In the example above, if the bounded argument is set as true in the problem definition (or wherever that variable is called), if the data dictionary for that variable features "pmin" or "pmax" entries, these are used as bound. Thus, similarly to the case of the starting value, the user can set:
```julia
data = _PMD.parse_file("case3_unbalanced.dss"; data_model=MATHEMATICAL)
data["load"]["1"]["pmax"] = [value, value, value]
data["load"]["1"]["pmin"] = [other_value, other_value, other_value]
```
