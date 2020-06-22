using Ipopt
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("test/data/opendss_feeders/case3_unbalanced.dss")
pmd_data = _PMD.transform_data_model(data) #NB the measurement dict needs to be passed to math model, passing it to the engineering data model won't work
meas_file = "C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\measurement_files\\case3_PQViVr.csv"#_ivr_conv.csv"#ieee123_input.csv"
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)
PowerModelsDSSE.add_measurement_id_to_load!(pmd_data, meas_file)
PowerModelsDSSE.assign_start_to_variables!(pmd_data)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wls")

se_result = PowerModelsDSSE.run_acr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "hessian_approximation"=>"limited-memory","print_level"=>2))

pf_result = _PMD.run_mc_pf(pmd_data, _PMs.ACRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>0))
#pf_result = _PMD.run_mc_pf(pmd_data, _PMD.SDPUBFPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>0))
vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "vm")
va_error_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "va")
