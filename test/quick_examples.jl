using Ipopt
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("test/data/opendss_feeders/ieee123_pmd.dss")
pmd_data = _PMD.transform_data_model(data) #NB the measurement dict needs to be passed to math model, passing it to the engineering data model won't work
meas_file = "C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\measurement_files\\ieee123_PQVm.csv"
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)

pf_result = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "print_level"=>0))

PowerModelsDSSE.assign_start_to_variables!(pmd_data)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav")

se_result = PowerModelsDSSE.run_ivr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4,"print_level"=>2))

vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "vm")
va_error_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "va")
