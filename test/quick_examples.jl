using Ipopt
using JuMP, PowerModels, PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("test/data/opendss/case3_unbalanced.dss")#("test/data/opendss/ieee123_pmd.dss")
pmd_data = _PMD.transform_data_model(data) #NB this is sadly necessary at the moment, otherwise meas dict is not passed to math model when converted from eng
meas_file = "C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\case3_input.csv"#_ivr_conv.csv"#ieee123_input.csv"
PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file; actual_meas=false, seed=0)
PowerModelsDSSE.add_measurement_id_to_load!(pmd_data, meas_file)
pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav",
                                        "rescale_weight" => 1)

se_result = PowerModelsDSSE.run_acp_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>2))

pf_result = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>0))
#pf_result = _PMD.run_mc_pf(pmd_data, _PMD.SDPUBFPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-5, "print_level"=>0))
vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "vm")
va_error_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_result, pf_result; vm_or_va = "va")

form = "SDP"
if form == "SDP"

    data = _PMD.parse_file("test/data/opendss/case3_unbalanced.dss"; transformations=[make_lossless!])

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

    data = _PMD.transform_data_model(data)

    for (_,bus) in data["bus"]
        if bus["name"] != "sourcebus"
            bus["vmin"] = fill(0.9, 3)
            bus["vmax"] = fill(1.1, 3)
        end
    end
    pf_result = _PMD.run_mc_pf(data, _PMD.SDPUBFPowerModel, scs_solver)
end#if form
