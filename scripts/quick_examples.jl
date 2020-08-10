using Ipopt
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
pmd_data = _PMD.transform_data_model(_PMD.parse_file(joinpath(dirname(@__DIR__), "test/data/opendss_feeders/case3_unbalanced.dss"))) #NB the measurement dict needs to be passed to math model, passing it to the engineering data model won't work
meas_file = joinpath(dirname(@__DIR__), "test/data/measurement_files/case3_ivrnative.csv")
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=true, seed=0)

pf_result_ivr = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "max_cpu_time"=>180.0, "print_level"=>0))
pf_result_acr = _PMD.run_mc_pf(pmd_data, _PMs.ACRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "max_cpu_time"=>180.0, "print_level"=>0))
pf_result_acp = _PMD.run_mc_pf(pmd_data, _PMs.ACPPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "max_cpu_time"=>180.0, "print_level"=>0))

display("There is a result difference in pg gen between ACR and IvR powerflow, that amounts to: $(pf_result_ivr["solution"]["gen"]["1"]["pg"] - pf_result_acr["solution"]["gen"]["1"]["pg"])")

PowerModelsDSSE.assign_start_to_variables!(pmd_data)
PowerModelsDSSE.update_all_bounds!(pmd_data; v_min = 0.8, v_max = 1.2, pg_min=0.0, pg_max = 2.0, qg_min=0.0, qg_max=2.0, pd_min=0.0, pd_max=1.0, qd_min=0.0, qd_max=1.0 )
#PowerModelsDSSE.update_load_bounds!(pmd_data; p_min = 0.0, p_max = 1.0, q_min = 0.0, q_max = 1.0)
#PowerModelsDSSE.update_generator_bounds!(pmd_data; p_min = 0.0, p_max = 0.1, q_min = 0.0, q_max = 0.1)
#PowerModelsDSSE.update_voltage_bounds!(pmd_data; v_min = 0.8, v_max = 1.2)

pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav", "weight_rescaler" => 10000000)
se_result_acr = PowerModelsDSSE.run_acr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-4))#,"hessian_approximation"=>"exact"))
se_result_ivr = PowerModelsDSSE.run_ivr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-4))
se_result_acp = PowerModelsDSSE.run_acp_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-4)) #,"mumps_pivtol"=>0.0))#,

display("There is a result difference in pg gen between ACR and IvR SE, that amounts to: $(pf_result_acp["solution"]["gen"]["1"]["pg"] - pf_result_ivr["solution"]["gen"]["1"]["pg"])")

vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_result_ivr, pf_result_ivr; vm_or_va = "vm")
va_error_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_result_acp, pf_result_acp; vm_or_va = "va")

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
