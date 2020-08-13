# Load Pkgs
using Ipopt
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

# Define Pkg cte
const _DST = Distributions
const _JMP = JuMP
const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _PMS = PowerModelsDSSE

# Set paths
model = _PMs.ACRPowerModel
ntw_path = "examples/data/network/case3.dss"
msr_path = "examples/data/measurements/case3.csv"

# Set solve
solver = _JMP.optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>180.0,
                                                        "tol"=>1e-4,
                                                        "print_level"=>3)

# Read-in network data
data = _PMD.transform_data_model(_PMD.parse_file(joinpath(BASE_DIR,ntw_path)))

# Solve the power flow
pf_results = _PMD.run_mc_pf(data, model, solver)

# Write measurements based on power flow
write_measurements!(model, data, pf_results, joinpath(BASE_DIR,msr_path))

# Read-in measurement data and set initial values
_PMS.add_measurement_to_pmd_data!(data, joinpath(BASE_DIR,msr_path),
                                        actual_meas = true)
_PMS.assign_start_to_variables!(data)

# Set se settings
data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav",
                                   "weight_rescaler" => 1)

# Solve the state estimation
se_results = _PMS.run_mc_se(data, model, solver)

## Post-processing
pf_sol = pf_results["solution"]
se_sol = se_results["solution"]

Phs = 1:3
Msr = keys(data["meas"])
MSR = ["$(data["meas"][msr]["var"]) on $(data["meas"][msr]["cmp"]) $(data["meas"][msr]["cmp_id"])" for msr in Msr]
idx = sortperm(MSR)
Msr, MSR = collect(Msr)[idx], MSR[idx]

# Plot the residuals
residual = [[se_sol["meas"][string(msr)]["res"][phs] for msr in Msr] for phs in Phs]
for phs in Phs residual[phs][residual[phs].==0.0] .= 1e-10 end

scatter(MSR, residual, yaxis = :log10, label = ["phase 1" "phase 2" "phase 3"])

# Plot the delta with respect to the power flow results
delta = Any[]
for phs in Phs
    push!(delta,Real[])
    for msr in Msr
    info = data["meas"][msr]
    id, cmp, var = string(info["cmp_id"]), string(info["cmp"]), string(info["var"])
    push!(delta[phs],abs(pf_sol[cmp][id][var][phs]-se_sol[cmp][id][var][phs]))
end end
for phs in Phs delta[phs][delta[phs].==0.0] .= 1e-10 end

scatter(MSR, delta, yaxis = :log10, label = ["phase 1" "phase 2" "phase 3"])
