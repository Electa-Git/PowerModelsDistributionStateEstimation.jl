using PowerModels
using PowerModelsDistribution
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("/Users/tvanacke/.julia/dev/PowerModelsDSSE/test/data/opendss/case3_unbalanced.dss")
# Set the setting dictionary
data["setting"] = Dict("res" => "wls")
# Add uncertainty - bus 1
data["bus"]["1"]["dst_vm"]    = MultiConductorVector([_DST.Normal(1.0,0.02),
                                                    _DST.Normal(1.0,0.02),
                                                    _DST.Normal(1.0,0.02)])
data["bus"]["1"]["dst_p"]     = MultiConductorVector([_DST.Normal(-0.018,0.02),
                                                    nothing,
                                                    nothing])
data["bus"]["1"]["dst_q"]     = MultiConductorVector([_DST.Normal(-0.006,0.02),
                                                    nothing,
                                                    nothing])
# Add uncertainty - bus 2
data["bus"]["2"]["dst_vm"]    = MultiConductorVector([_DST.Normal(1.0,0.02),
                                                    _DST.Normal(1.0,0.02),
                                                    _DST.Normal(1.0,0.02)])
data["bus"]["2"]["dst_p"]     = MultiConductorVector([nothing,
                                                    _DST.Normal(-0.012,0.02),
                                                    nothing])
data["bus"]["2"]["dst_q"]     = MultiConductorVector([nothing,
                                                    _DST.Normal(-0.006,0.02),
                                                    nothing])
# Add uncertainty - bus 3
data["bus"]["3"]["dst_vm"]    = MultiConductorVector([_DST.Normal(1.0,0.02),
                                                    _DST.Normal(1.0,0.02),
                                                    _DST.Normal(1.0,0.02)])
data["bus"]["3"]["dst_p"]     = MultiConductorVector([nothing,
                                                    nothing,
                                                    _DST.Normal(-0.012,0.02)])
data["bus"]["3"]["dst_q"]     = MultiConductorVector([nothing,
                                                    nothing,
                                                    _DST.Normal(-0.006,0.02)])
# Add uncertainty - bus 3
data["bus"]["4"]["dst_vm"]    = MultiConductorVector([_DST.Normal(1.0,0.02),
                                                    _DST.Normal(1.0,0.02),
                                                    _DST.Normal(1.0,0.02)])
data["bus"]["4"]["dst_p"]     = MultiConductorVector([_DST.Normal(0.018,0.01),
                                                    _DST.Normal(0.012,0.01),
                                                    _DST.Normal(0.012,0.01)])
data["bus"]["4"]["dst_q"]     = MultiConductorVector([_DST.Normal(0.006,0.01),
                                                    _DST.Normal(0.006,0.01),
                                                    _DST.Normal(0.006,0.01)])

result = run_mc_se(data, PMs.ACPPowerModel, ipopt_solver)
