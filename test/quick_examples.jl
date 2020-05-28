using Ipopt
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("test/data/opendss/ieee123_pmd.dss")
pmd_data = _PMD.transform_data_model(data) #NB this is sadly necessary at the moment, otherwise meas dict is not passed to math model when converted from eng
meas_file = "C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\ieee123_input.csv"
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)
PowerModelsDSSE.add_measurement_id_to_load!(pmd_data, meas_file)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav",
                                        "rescale_weight" => 100)
se_result = PowerModelsDSSE.run_ivr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>0))
pf_result = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>0))
vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "vm")
va_error_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "va")
