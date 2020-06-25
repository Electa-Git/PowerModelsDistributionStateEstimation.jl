using Ipopt
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("test/data/opendss_feeders/lvtestcase_pmd_t1000.dss")
pmd_data = _PMD.transform_data_model(data) #NB the measurement dict needs to be passed to math model, passing it to the engineering data model won't work
meas_file = "C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\measurement_files\\EULV_verylowsigma.csv"
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)

pf_result = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "print_level"=>0))

PowerModelsDSSE.assign_start_to_variables!(pmd_data)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wls", "weight_rescaler" => 1000)
se_result = PowerModelsDSSE.run_ivr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "max_cpu_time"=>180.0, "tol"=>1e-4,"print_level"=>2))

vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "vm")
va_error_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "va")


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
