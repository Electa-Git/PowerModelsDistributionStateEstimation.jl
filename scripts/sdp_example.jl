using SCS
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

data_path = joinpath(BASE_DIR,"test/data/opendss_feeders/lvtestcase_pmd_t1000.dss")
meas_path = joinpath(BASE_DIR,"test/data/measurement_files/EULV_t1000_PQw.csv")
data = _PMD.parse_file(data_path; transformations=[make_lossless!])

data["settings"]["sbase_default"] = 0.001 * 1e3
# merge!(data["voltage_source"]["source"], Dict{String,Any}(
#     "cost_pg_parameters" => [0.0, 1000.0, 0.0],
#     "pg_lb" => fill(  0.0, 3),
#     "pg_ub" => fill( 10.0, 3),
#     "qg_lb" => fill(-10.0, 3),
#     "qg_ub" => fill( 10.0, 3)
# ))
#
for (_,line) in data["line"]
    line["sm_ub"] = fill(10.0, 3)
end

pmd_data = _PMD.transform_data_model(data) #NB the measurement dict needs to be passed to math model, passing it to the engineering data model won't work
for (_,bus) in pmd_data["bus"]
    if bus["name"] != "sourcebus"
        bus["vmin"] = fill(0.8, 3)
        bus["vmax"] = fill(1.2, 3)
        bus["vm"] = fill(1.0, 3)
        bus["va"] = deg2rad.([0., -120, 120])
    end
end

PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_path; actual_meas=false, seed=0)

PowerModelsDSSE.assign_start_to_variables!(pmd_data)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav")

pf_result = _PMD.run_mc_pf(pmd_data, _PMD.SDPUBFPowerModel, optimizer_with_attributes(SCS.Optimizer, "max_iters"=>20000, "eps"=>1e-5, "alpha"=>0.4, "verbose"=>0))
se_result = PowerModelsDSSE.run_sdp_mc_se(pmd_data, optimizer_with_attributes(SCS.Optimizer, "max_iters"=>20000, "eps"=>1e-5, "alpha"=>0.4, "verbose"=>0))

vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error_SDP(se_result, pf_result)
