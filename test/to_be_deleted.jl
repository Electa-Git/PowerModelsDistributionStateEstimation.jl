using Ipopt
using PowerModels
using PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("test/data/opendss/case3_unbalanced.dss")
pmd_data = _PMD.transform_data_model(data) #NB this is sadly necessary at the moment, otherwise meas dict is not passed to math model when converted from eng
meas_file = "C:\\Users\\mvanin\\.julia\\dev\\PowerModelsDSSE\\test\\data\\case3_input.csv"

PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_file, false, 0)
pmd_data["setting"] = Dict("estimation_criterion" => "wlav")
result = PowerModelsDSSE.run_acp_mc_se(pmd_data, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
