#!/home/adrian03/julia-1.2.0/bin/julia

cd("/home/adrian03/PowerModelsDSSE")

using Pkg
pkg"activate ."

# Load Pkgs
using Ipopt
using DataFrames, CSV
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
models = [_PMs.ACPPowerModel, _PMs.ACRPowerModel, _PMs.IVRPowerModel]

rm_transfo = false
rd_lines   = false
set_criterion = "wlav"
set_rescaler = 1

season = "summer"
time   = 144
elm    = ["load", "pv"]
pfs    = [0.95, 0.90]

################################################################################
# Set path
msr_path = joinpath(BASE_DIR,"test/data/enwl/measurements/temp.csv")

# Set solve
linear_solver = "ma27"
tolerance = 1e-5
solver = _JMP.optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>180.0,
                                                        "tol"=>tolerance,
                                                        "print_level"=>0,
                                                        "linear_solver"=>linear_solver)

display("You are launching a simulation with rm_transfo: $(string(rm_transfo)) and rd_lines: $(string(rd_lines)), criterion: $(set_criterion), rescaler: $set_rescaler, linear solver : $linear_solver")

df = _DF.DataFrame(ntw=Int64[], fdr=Int64[], solve_time=Float64[], n_bus=Int64[],
                   termination_status=String[], objective=Float64[], criterion=String[], rescaler = Float64[], eq_model = String[], linear_solver = String[], tol = Any[])

for mod in models

    short = string(mod)[1:3]
    sol_path = joinpath(BASE_DIR,"src/io/$(short)_rmtrf_$(string(rm_transfo))_rdlines_$(string(rd_lines)).csv")

    for ntw in 1:25 for fdr in 1:10

        data_path = _PMS.get_enwl_dss_path(ntw, fdr)
        if !isdir(dirname(data_path)) break end

        # Load the data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr),data_model=_PMD.ENGINEERING);
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # Insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # Transform data model
        data = _PMD.transform_data_model(data);

        # Solve the power flow
        pf_results = _PMD.run_mc_pf(data, _PMs.ACPPowerModel, solver)

        # Write measurements based on power flow
        _PMS.write_measurements!(_PMs.ACPPowerModel, data, pf_results, msr_path)

        # Read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # Set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => set_criterion,
                                           "rescaler" => set_rescaler)

        # Solve the state estimation
        se_results = _PMS.run_mc_se(data, mod, solver)

        # PRINT

        push!(df, [ntw, fdr, se_results["solve_time"], length(data["bus"]),
                   string(se_results["termination_status"]),
                   se_results["objective"], set_criterion, set_rescaler, short, linear_solver, tolerance])

    end end
    CSV.write(sol_path, df)
end #end models loop


# cnd = df.termination_status.=="LOCALLY_SOLVED"
# avg = round(sum(df.solve_time[cnd])/sum(cnd), digits=1)
# x_values = 1:length(df.ntw)
#
# scatter(x_values[cnd],df.solve_time[cnd],xlim=[0,130],
#                                          yaxis=:log10,ylim=[1e-1,1e3],
#                                          label="ACR (avg = $avg)")
