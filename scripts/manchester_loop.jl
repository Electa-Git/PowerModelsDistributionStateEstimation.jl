# Load Pkgs
using Ipopt
using DataFrames
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE

# Define Pkg cte
const _DF  = DataFrames
const _JMP = JuMP
const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _PMS = PowerModelsDSSE

################################################################################
# Input data
model = _PMs.ACPPowerModel
short = "ACP"

rm_transfo = false
rd_lines   = false

season = "summer"
time   = 144
elm    = ["load", "pv"]
pfs    = [0.95, 0.90]

const BASE_DIR = dirname(@__DIR__)
################################################################################
# Set path
ntw_path = joinpath(BASE_DIR,"examples/data/enwl")
msr_path = joinpath(BASE_DIR,"examples/data/measurements/measurement.csv")
sol_path = joinpath(BASE_DIR,"examples/sol/$(short).csv")

# Set solve
solver = _JMP.optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>180.0,
                                                        "tol"=>1e-10,
                                                        "print_level"=>0)

# Include the necessary functions to load the data
include("$ntw_path/load_enwl.jl")
include("$ntw_path/mod_enwl.jl")

df = _DF.DataFrame(ntw=Int64[], fdr=Int64[], solve_time=Float64[], n_bus=Int64[],
                   termination_status=String[], objective=Float64[])

for ntw in 1:25 for fdr in 1:10
    data_path = get_enwl_dss_path(ntw, fdr)
    if !isdir(dirname(data_path)) break end

    # PRINT
    println((ntw,fdr))

    # Load the data
    data = _PMD.parse_file(get_enwl_dss_path(ntw, fdr),data_model=_PMD.ENGINEERING);
    if rm_transfo rm_enwl_transformer!(data) end
    if rd_lines   reduce_lines_eng!(data) end

    # Insert the load profiles
    insert_profiles!(data, season, elm, pfs, t = time)

    # Transform data model
    data = _PMD.transform_data_model(data);

    # Solve the power flow
    pf_results = _PMD.run_mc_pf(data, model, solver)

    # Write measurements based on power flow
    write_measurements!(model, data, pf_results, msr_path)

    # Read-in measurement data and set initial values
    _PMS.add_measurement_to_pmd_data!(data, msr_path, actual_meas = true)
    _PMS.assign_start_to_variables!(data)

    # Set se settings
    data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav",
                                       "weight_rescaler" => 1)

    # Solve the state estimation
    se_results = _PMS.run_mc_se(data, model, solver)

    # PRINT
    push!(df, [ntw, fdr, se_results["solve_time"], length(data["bus"]),
               string(se_results["termination_status"]),
               se_results["objective"]])
end end

CSV.write(sol_path, df)

# cnd = df.termination_status.=="LOCALLY_SOLVED"
# avg = round(sum(df.solve_time[cnd])/sum(cnd), digits=1)
# x_values = 1:length(df.ntw)
#
# scatter(x_values[cnd],df.solve_time[cnd],xlim=[0,130],
#                                          yaxis=:log10,ylim=[1e-1,1e3],
#                                          label="ACR (avg = $avg)")
