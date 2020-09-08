##NB scaling tips: https://projects.coin-or.org/Ipopt/wiki/HintsAndTricks#Scalingoftheoptimizationproblem
##NB scaling tips: https://www.gams.com/latest/docs/S_CONOPT.html#CONOPT_SCALING


using PowerModelsDSSE, PowerModelsDistribution, Ipopt
using PowerModels, JuMP

using SCS

_PMD = PowerModelsDistribution
_PMs = PowerModels
_PMS = PowerModelsDSSE

################################################################################
# Input data
ntw, fdr  = 1,1
rm_transfo = true
rd_lines   = true

season = "summer"
time   = 228
elm    = ["load", "pv"]
pfs    = [0.95, 0.90]

################################################################################
# Set measurement path
msr_path = joinpath(BASE_DIR,"test/data/enwl/measurements/temp.csv")

# Set solve
solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>180.0,
                                                        "tol"=>1e-5,
                                                        "print_level"=>3,
                                                        "fixed_variable_treatment"=>"make_constraint")

# Load the data
data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr),data_model=_PMD.ENGINEERING);
if rm_transfo _PMS.rm_enwl_transformer!(data) end
if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

# Insert the ENWL load profiles
_PMS.insert_profiles!(data, season, elm, pfs, t = time)

# Transform data model
#data = _PMD.parse_file("C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\extra\\networks\\case3_unbalanced.dss")
data = _PMD.transform_data_model(data)

data_model = _PMs.ACPPowerModel
pf_result = _PMD.run_mc_pf(data, data_model, solver)

_PMS.write_measurements!(data_model, data, pf_result, msr_path, exclude = ["vi","vr"])

# read-in measurement data and set initial values
_PMS.add_measurements!(data, msr_path, actual_meas = true)
_PMS.add_voltage_measurement!(data, pf_result, 0.005)
_PMS.assign_start_to_variables!(data)
_PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

# Solve the power flow
data["setting"] = Dict{String,Any}("estimation_criterion" => "mle", "weight_rescaler" => [1000, 1])
se_result_acr = PowerModelsDSSE.run_acr_mc_se(data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-8))#, "fixed_variable_treatment"=>"make_parameter"))
delta, max_err, avg = _PMS.calculate_voltage_magnitude_error(se_result_acr, pf_result)

se_result_ivr = PowerModelsDSSE.run_ivr_mc_se(data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-8, "fixed_variable_treatment"=>"make_constraint"))
delta, max_err, avg = _PMS.calculate_voltage_magnitude_error(se_result_ivr, pf_result)

se_result_acp = PowerModelsDSSE.run_acp_red_mc_se(data, optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>180.0, "tol"=>1e-8))#, "fixed_variable_treatment"=>"make_parameter"))
delta, max_err, avg = _PMS.calculate_voltage_magnitude_error(se_result_acp, pf_result)

data = _PMD.parse_file("C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\extra\\networks\\case3_unbalanced.dss"; transformations = [make_lossless!])
data["settings"]["sbase_default"] = 0.001 * 1e3
merge!(data["voltage_source"]["source"], Dict{String,Any}(
    "cost_pg_parameters" => [0.0, 1000.0, 0.0],
    "pg_lb" => fill(  0.0, 3),
    "pg_ub" => fill( 10.0, 3),
    "qg_lb" => fill(-10.0, 3),
    "qg_ub" => fill( 10.0, 3),
    )
)

for (_,line) in data["line"]
    line["sm_ub"] = fill(10.0, 3)
end

sdp_data = transform_data_model(data)

for (_,bus) in sdp_data["bus"]
    if bus["name"] != "sourcebus"
        bus["vmin"] = fill(0.9, 3)
        bus["vmax"] = fill(1.1, 3)
    end
end

scs_solver = with_optimizer(SCS.Optimizer, max_iters=20000, eps=1e-5, alpha=0.4, verbose=0)
pf_result = _PMD.run_mc_pf(sdp_data, _PMD.SDPUBFPowerModel, scs_solver)
_PMS.write_measurements!(_PMD.SDPUBFPowerModel, sdp_data, pf_result, msr_path, exclude = ["vi","vr"])
_PMS.add_measurements!(sdp_data, msr_path, actual_meas = true)
_PMS.assign_start_to_variables!(sdp_data)
PowerModelsDSSE.vm_to_w_conversion!(sdp_data)
_PMS.update_voltage_bounds!(data; v_min = 0.9, v_max = 1.0)#, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

sdp_data["setting"] = Dict{String,Any}("estimation_criterion" => "rwls", "weight_rescaler" => 100000)
se_result_sdp = PowerModelsDSSE.run_sdp_mc_se(sdp_data, scs_solver)#, "fixed_variable_treatment"=>"make_parameter"))
delta, max_err, avg = _PMS.calculate_voltage_magnitude_error(se_result_sdp, pf_result)
