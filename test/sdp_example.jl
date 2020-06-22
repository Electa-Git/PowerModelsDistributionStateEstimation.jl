using SCS
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

data = _PMD.parse_file("test/data/opendss_feeders/case3_unbalanced.dss"; transformations=[make_lossless!])

data["settings"]["sbase_default"] = 0.001 * 1e3
merge!(data["voltage_source"]["source"], Dict{String,Any}(
    "cost_pg_parameters" => [0.0, 1000.0, 0.0],
    "pg_lb" => fill(  0.0, 3),
    "pg_ub" => fill( 10.0, 3),
    "qg_lb" => fill(-10.0, 3),
    "qg_ub" => fill( 10.0, 3)
))

for (_,line) in data["line"]
    line["sm_ub"] = fill(10.0, 3)
end

pmd_data = _PMD.transform_data_model(data) #NB the measurement dict needs to be passed to math model, passing it to the engineering data model won't work
meas_file = "C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\measurement_files\\case3_SDP.csv"
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)
PowerModelsDSSE.add_measurement_id_to_load!(pmd_data, meas_file)
PowerModelsDSSE.assign_start_to_variables!(pmd_data)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav",
                                        "rescale_weight" => 1)

for (_,bus) in pmd_data["bus"]
    if bus["name"] != "sourcebus"
        bus["vmin"] = fill(0.9, 3)
        bus["vmax"] = fill(1.1, 3)
        bus["vm"] = fill(1.0, 3)
        bus["va"] = deg2rad.([0., -120, 120])
    end
end

pf_result = _PMD.run_mc_pf(pmd_data, _PMD.SDPUBFPowerModel, optimizer_with_attributes(SCS.Optimizer, "max_iters"=>20000, "eps"=>1e-5, "alpha"=>0.4, "verbose"=>0))
se_result = PowerModelsDSSE.run_sdp_mc_se(pmd_data, optimizer_with_attributes(SCS.Optimizer, "max_iters"=>20000, "eps"=>1e-5, "alpha"=>0.4, "verbose"=>0))

vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error_SDP(se_result, pf_result)
