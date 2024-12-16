# Explicit Neutral Models for DSSE

As of version 0.8.0, PMDSE support the explicit neutral models of PowerModelsDistribution.jl in the `IVRUPowerModel` formulation. This feature is crucial for the state estimation of low voltage networks when the neutral wire is not solidly grounded at the load side, which is usually the case for European low voltage feeders. 

## Background

A generic three-phase low voltage model would have 4 wires: three wires for the three-phase lines (L1, L2, L3), one wire for the neutral (N).

In a typical low voltage installation, the neutral wire is connected to the ground at the transformer secondary, and depending on the load earthing scheme the neutral wire might be connected to the ground at the load side or not. In the first case, where the neutral is grounded at both the transformer secondary and at the load side, then the neutral voltage at both ends is equal at 0 volts (ground voltage) and hence no current flows through the neutral wire. In that case, kron reduction is an exact approximation for the three-phase network analysis. 


![Four-wire-grounded-at-load](GroundedKronRed.svg)

However, in the case where the neutral is not grounded at the load side, then the neutral voltage at the load side is not equal to the ground voltage and hence a current flows through the neutral wire. And it is necessary for the neutral voltages and current flows to be considered in the network three-phases analysis. In this case, the Kron reduction affects results accuracy of the state estimation.

![Four-wire-not-grounded-at-load](UngroundedNotKron.svg) [^1]

[^1]: Figures adapted from S. Claeys and G. Deconinck, “Distribution Network Modeling: From Simulation Towards Optimization,” 2021. PhD Thesis, KU Leuven.


## Usage
The function `solve_ivr_en_mc_se()` is added to the API to perform state estimation with the explicit neutral models in the IVR formulation. a typical usage for an explicit neutral MATHEMATICAL PowerMdoelsDistribution.jl model is as follows:

```julia
using PowerModelsDistribution
using PowerModelsDistributionStateEstimation
PMD = PowerModelsDistribution
PMDSE = PowerModelsDistributionStateEstimation

eng_en = PMD.parse_file(joinpath(PMDSE.BASE_DIR, "test", "data", "three-bus-en-models", "3bus_4wire.dss"))
msr_path = joinpath(mktempdir(),"temp_msr.csv")

eng_en = PowerModelsDistribution.parse_file(ntw_path)
PMD.transform_loops!(eng_en)
PMD.remove_all_bounds!(eng_en)

math_en = PMD.transform_data_model(eng_en, kron_reduce=false, phase_project=false)

pf_result = PMD.solve_mc_pf(data, model, ipopt_solver)
write_measurements!(model, data, pf_result, msr_path)
add_measurements!(data, msr_path, actual_meas = true)

data["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1)
SE = PMDSE.solve_ivr_en_mc_se(data, Ipopt.Optimizer)
```


as it can be seen other than having a 4-wire network model, the rest of the state estimation process is similar to the one used for the 3-wire network model, just a matter of using the new function.

