using Ipopt
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
pmd_data = _PMD.transform_data_model( _PMD.parse_file(joinpath(dirname(@__DIR__), "test/data/opendss_feeders/lvtestcase_pmd_t1000.dss"))) #NB the measurement dict needs to be passed to math model, passing it to the engineering data model won't work
meas_file = joinpath(dirname(@__DIR__), "test\\data\\measurement_files\\EULV_t1000_PQVm.csv")
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=true, seed=0)

pf_result_ivr = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "max_cpu_time"=>180.0, "print_level"=>0))
pf_result_acr = _PMD.run_mc_pf(pmd_data, _PMs.ACRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "max_cpu_time"=>180.0, "print_level"=>0))

display("There is a result difference in pg gen between ACR and IvR powerflow, that amounts to: $(pf_result_ivr["solution"]["gen"]["1"]["pg"] - pf_result_acr["solution"]["gen"]["1"]["pg"])")

PowerModelsDSSE.assign_start_to_variables!(pmd_data)

pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav", "weight_rescaler" => 1)
se_result_acr = PowerModelsDSSE.run_acr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-4,"print_level"=>2))
se_result_ivr = PowerModelsDSSE.run_ivr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-4,"print_level"=>2))
se_result_acp = PowerModelsDSSE.run_acp_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-4,"print_level"=>2))

display("There is a result difference in pg gen between ACR and IvR SE, that amounts to: $(pf_result_ivr["solution"]["gen"]["1"]["pg"] - pf_result_acr["solution"]["gen"]["1"]["pg"])")

vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_result_acp, pf_result; vm_or_va = "vm")
va_error_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_result_acp, pf_result; vm_or_va = "va")

#################################################################################
####### TRY WITHOUT TRANSFORMER ################################
#################################################################################

function remove_transformer!(pmd_data)
    buses_to_delete = [621, 911, 910, 908, 909]
    branches_to_delete = [908, 907, 906]
    for b in buses_to_delete
        delete!(pmd_data["bus"], "$b")
    end
    for br in branches_to_delete
        delete!(pmd_data["branch"], "$br")
    end
    pmd_data["branch"]["909"]["t_bus"] = 1
    pmd_data["transformer"] = Dict{String, Any}()
    #pmd_data["bus"]["1"]["bus_type"] = 3
    pmd_data["bus"]["912"]["vm"] = [1.04844, 1.04849, 1.04871]
    pmd_data["bus"]["912"]["va"] = [-0.526719, -2.62081, 1.56822]

end
