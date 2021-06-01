ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>300.0,
                                                              "tol"=>1e-8,
                                                              "print_level"=>0)

ntw, fdr = 4, 2

season     = "summer"
time_step  = 144
elm        = ["load", "pv"]
pfs        = [0.95, 0.90]
rm_transfo = true
rd_lines   = true

msr_path = joinpath(mktempdir(),"temp.csv")

include(raw"C:\Users\mvanin\.julia\dev\PowerModelsDistributionStateEstimation\src\bad_data\chi_squares_test.jl")

data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

# insert the load profiles
_PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

# transform data model
data = _PMD.transform_data_model(data);
_PMDSE.reduce_single_phase_loadbuses!(data)

# solve the power flow
pf_result = _PMD.solve_mc_pf(data, _PMD.ACPUPowerModel, ipopt_solver)

# write measurements based on power flow
_PMDSE.write_measurements!(_PMD.ACPUPowerModel, data, pf_result, msr_path, exclude = ["vr","vi"])

key = "1" # or "sourcebus"
v_pu = data["settings"]["vbases_default"][key]* data["settings"]["voltage_scale_factor"] # divider [V] to get the voltage in per units.
v_max_err = 1.15 # maximum error of voltage measurement = 0.5% or 1.15 V
σ_v = 1/3*v_max_err/v_pu

p_pu = data["settings"]["sbase"] # divider [kW] to get the power in per units.
p_max_err = 0.01 # maximum error of power measurement = 10W, or 0.01 kW
σ_p = 1/3*p_max_err/p_pu

# sigma_dict
σ_dict = Dict("load" => Dict("load" => σ_p,
                            "bus"   => σ_v),
              "gen"  => Dict("gen" => σ_p,
                            "bus" => σ_v)
              )

# write measurements based on power flow
_PMDSE.write_measurements!(_PMD.ACPUPowerModel, data, pf_result, msr_path, exclude = ["vi","vr"], σ = σ_dict)

# read-in measurement data and set initial values
_PMDSE.add_measurements!(data, msr_path, actual_meas = false)

rsc = 100
crit = "rwls"

data["se_settings"] = Dict{String,Any}("criterion" => crit, "rescaler" => rsc)
se_result = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)

exceeds_chi_squares_threshold(se_result, data; prob_false=0.05, criterion=crit, rescaler = rsc)