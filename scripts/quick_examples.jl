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
meas_file = "C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\measurement_files\\EULV_t1000_PQVm.csv"
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)

pf_result = _PMD.run_mc_pf(pmd_data, _PMs.ACRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "print_level"=>0))

PowerModelsDSSE.assign_start_to_variables!(pmd_data)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wls")

se_result = PowerModelsDSSE.run_acr_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4,"print_level"=>2))

vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "vm")
va_error_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "va")


#################################################################################
####### GET MEASUREMENTS KNOWING ORIGINAL BUS/BRANCH OF THE TEST FEEDER #########
#################################################################################


for i in pmd_data["map"]
    if haskey(i, "from")
        if i["from"] == string(26)
            display(i["to"])
        end
    end
end

for (_, branch) in pmd_data["branch"]
    if (branch["f_bus"] == 102 && branch["t_bus"] == 128) || (branch["f_bus"] == 128 && branch["t_bus"] == 102)
        display(branch["index"])
    end
end
