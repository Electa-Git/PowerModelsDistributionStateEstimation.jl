using Ipopt
using PowerModels
using PowerModelsDistribution
using PowerModelsDSSE
using Distributions

const _PMs = PowerModels
const _PMD = PowerModelsDistribution
const _DST = Distributions

# Read-in network data
data = _PMD.parse_file("/Users/tvanacke/.julia/dev/PowerModelsDSSE/test/data/opendss/case3_unbalanced.dss")
# Set the setting dictionary
data["setting"] = Dict("estimation_criterion" => "wlav")
# Add measurements
data["meas"] = Dict{String,Any}()
data["meas"]["1"] = Dict{String,Any}(   "cmp" => :bus, "id"  => 1, "var" => :vm,
                                        "dst" => [_DST.Normal(1.0,0.0002),
                                                  _DST.Normal(1.0,0.0002),
                                                  _DST.Normal(1.0,0.0002)])
data["meas"]["2"] = Dict{String,Any}(   "cmp" => :bus, "id"  => 2, "var" => :vm,
                                        "dst" => [_DST.Normal(1.0,0.0002),
                                                  _DST.Normal(1.0,0.0002),
                                                  _DST.Normal(1.0,0.0002)])
data["meas"]["3"] = Dict{String,Any}(   "cmp" => :bus, "id"  => 3, "var" => :vm,
                                        "dst" => [_DST.Normal(1.0,0.0002),
                                                  _DST.Normal(1.0,0.0002),
                                                  _DST.Normal(1.0,0.0002)])
data["meas"]["4"] = Dict{String,Any}(   "cmp" => :bus, "id"  => 4, "var" => :vm,
                                        "dst" => [_DST.Normal(1.0,0.0002),
                                                  _DST.Normal(1.0,0.0002),
                                                  _DST.Normal(1.0,0.0002)])
data["meas"]["5"] = Dict{String,Any}(   "cmp" => :load, "id"  => 1, "var" => :pd,
                                        "dst" => [_DST.Normal(0.018,0.02),
                                                  nothing,
                                                  nothing])
data["meas"]["6"] = Dict{String,Any}(   "cmp" => :load, "id"  => 1, "var" => :qd,
                                        "dst" => [_DST.Normal(0.006,0.02),
                                                  nothing,
                                                  nothing])
data["meas"]["7"] = Dict{String,Any}(   "cmp" => :load, "id"  => 2, "var" => :pd,
                                        "dst" => [nothing,
                                                  _DST.Normal(0.012,0.02),
                                                  nothing])
data["meas"]["8"] = Dict{String,Any}(   "cmp" => :load, "id"  => 2, "var" => :qd,
                                        "dst" => [nothing,
                                                  _DST.Normal(0.006,0.02),
                                                  nothing])
data["meas"]["9"] = Dict{String,Any}(   "cmp" => :load, "id"  => 3, "var" => :pd,
                                        "dst" => [nothing,
                                                  nothing,
                                                  _DST.Normal(0.012,0.02)])
data["meas"]["10"] = Dict{String,Any}(  "cmp" => :load, "id"  => 3, "var" => :qd,
                                        "dst" => [nothing,
                                                  nothing,
                                                  _DST.Normal(0.006,0.02)])
data["meas"]["11"] = Dict{String,Any}(  "cmp" => :gen, "id"  => 1, "var" => :pg,
                                        "dst" => [_DST.Normal(0.018,0.02),
                                                  _DST.Normal(0.012,0.02),
                                                  _DST.Normal(0.012,0.02)])
data["meas"]["12"] = Dict{String,Any}(  "cmp" => :gen, "id"  => 1, "var" => :qg,
                                        "dst" => [_DST.Normal(0.006,0.02)
                                                  _DST.Normal(0.006,0.02)
                                                  _DST.Normal(0.006,0.02)])

result = PowerModelsDSSE.run_mc_se(data, _PMs.ACPPowerModel, with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0))
