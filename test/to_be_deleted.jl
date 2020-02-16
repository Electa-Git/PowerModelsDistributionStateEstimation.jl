using PowerModels
using PowerModelsDistribution
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("/Users/tvanacke/.julia/dev/PowerModelsDSSE/test/data/opendss/case3_unbalanced.dss")
# Set the setting dictionary
data["setting"] = Dict("estimation_criterion" => "wlav")
# Add bus uncertainties
for nb in keys(data["bus"]) data["bus"][nb]["dst"] = Dict{Symbol,Any}() end
data["bus"]["1"]["dst"][:vm] = MultiConductorVector([_DST.Normal(1.0,0.02),
                                                     _DST.Normal(1.0,0.02),
                                                     _DST.Normal(1.0,0.02)])
data["bus"]["2"]["dst"][:vm] = MultiConductorVector([_DST.Normal(1.0,0.02),
                                                     _DST.Normal(1.0,0.02),
                                                     _DST.Normal(1.0,0.02)])
data["bus"]["3"]["dst"][:vm] = MultiConductorVector([_DST.Normal(1.0,0.02),
                                                     _DST.Normal(1.0,0.02),
                                                     _DST.Normal(1.0,0.02)])
data["bus"]["4"]["dst"][:vm] = MultiConductorVector([_DST.Normal(1.0,0.02),
                                                     _DST.Normal(1.0,0.02),
                                                     _DST.Normal(1.0,0.02)])
# Add load uncertainties
for nl in keys(data["load"]) data["load"][nl]["dst"] = Dict{Symbol,Any}() end
data["load"]["1"]["dst"][:pd] = MultiConductorVector([_DST.Normal(0.018,0.02),
                                                      nothing,
                                                      nothing])
data["load"]["1"]["dst"][:qd] = MultiConductorVector([_DST.Normal(0.006,0.02),
                                                      nothing,
                                                      nothing])
data["load"]["2"]["dst"][:pd] = MultiConductorVector([nothing,
                                                      _DST.Normal(0.012,0.02),
                                                      nothing])
data["load"]["2"]["dst"][:qd] = MultiConductorVector([nothing,
                                                      _DST.Normal(0.006,0.02),
                                                      nothing])
data["load"]["3"]["dst"][:pd] = MultiConductorVector([nothing,
                                                      nothing,
                                                      _DST.Normal(0.012,0.02)])
data["load"]["3"]["dst"][:pd] = MultiConductorVector([nothing,
                                                      nothing,
                                                      _DST.Normal(0.006,0.02)])
# Add generator uncertainties
for ng in keys(data["gen"]) data["gen"][ng]["dst"] = Dict{Symbol,Any}() end
data["gen"]["1"]["dst"][:pg] = MultiConductorVector([_DST.Normal(0.018,0.02),
                                                     _DST.Normal(0.012,0.02),
                                                     _DST.Normal(0.012,0.02),])
data["gen"]["1"]["dst"][:qg] = MultiConductorVector([_DST.Normal(0.006,0.02),
                                                     _DST.Normal(0.006,0.02),
                                                     _DST.Normal(0.006,0.02),])
