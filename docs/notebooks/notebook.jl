### A Pluto.jl notebook ###
# v0.11.14

using Markdown
using InteractiveUtils

# ╔═╡ f7e93fee-07ef-11eb-086e-b9bf474d3ed3
using DataFrames

# ╔═╡ 82a8eef6-07dc-11eb-362e-c5ad10e7219a
using Distributions

# ╔═╡ 5def25e0-07ea-11eb-1f7d-1d22b0ab8158
using Ipopt

# ╔═╡ 2f4f8a72-07ea-11eb-3f2f-0922fffe8de3
using JuMP

# ╔═╡ e9941b80-07dd-11eb-343e-9dbc8ffb00c1
using Plots, StatsPlots

# ╔═╡ c10ba066-07d8-11eb-2127-f9b41999b5f7
using PowerModelsDistribution, PowerModelsSE

# ╔═╡ 42dfb878-07e5-11eb-1207-718e519a9d44
## Loading the network data path
ntw_path = joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss");

# ╔═╡ 3bb9c3a4-07e5-11eb-0931-29f5376b6cac
## Loading network data
data = parse_file(ntw_path; data_model=MATHEMATICAL);

# ╔═╡ 225e91e6-07ea-11eb-2a32-f16b81606fd5
## Define the solver
solver = optimizer_with_attributes(	Ipopt.Optimizer, 
									"tol" => 1e-10, 
									"print_level" => 0);

# ╔═╡ 52b4f514-07e1-11eb-3efd-37d5c380c352
md"
# An Introduction to State Estimation

A state estimator determines the *most-likely* state of a low voltage distribution system using a set of (pseudo-)measurements. To illustrate the concept, the following three-node network is considered:

![tiger](https://upload.wikimedia.org/wikipedia/commons/5/56/Tiger.50.jpg)
"

# ╔═╡ f096624e-07e9-11eb-3c2e-d52071c61445
data["se_settings"] = Dict( "criterion" => "rwlav",
							"rescaler" => 1.0)

# ╔═╡ ca25545a-07db-11eb-2a34-95f8908ed247
## Create some dummy functionality to write measurents from an array of measurements
#                  var 	bus  cnd distr
meas = [(:vm,	1, 	1, 	Normal(1.0,0.1)),
		(:pd, 	1, 	1, 	Normal(9.9,0.2)),
		(:qd, 	1, 	1, 	Normal(2.0,0.2)),
		(:vm, 	2, 	3, 	Normal(1.0,0.1)),
		(:pd, 	2, 	3, 	Normal(9.9,0.2)),
		(:qd, 	2, 	3, 	Normal(2.0,0.2)),
		(:vm, 	3, 	2, 	Normal(1.0,0.1)),
		(:pd, 	3, 	2, 	Normal(9.9,0.2)),
		(:qd, 	3, 	2, 	Normal(2.0,0.2))];

# ╔═╡ d615ce5c-07dd-11eb-3158-ff5f0d1d6710
#add_measurements!(data, meas, actual_meas=true)

# ╔═╡ e316de5a-07dd-11eb-37cf-db21d64bef14
#sol = run_acp_mc_se(data, form, solver) 

# ╔═╡ 171f37c0-07f1-11eb-1dea-8ddb1beb0a21
begin
	dst = Normal(20.0,1.0)
	p1 = plot(dst,ylim=(0.0,0.5),grid=false,ylabel="Bus 1") # plot the uncertainty
	p1 = scatter!((dst.μ,pdf(dst,dst.μ)))					# plot the residual
	p2 = plot(dst,ylim=(0.0,0.5),grid=false)
	p2 = scatter!((dst.μ,pdf(dst,dst.μ)))
	p3 = plot(dst,ylim=(0.0,0.5),grid=false)
	p3 = scatter!((dst.μ,pdf(dst,dst.μ)))
	p4 = plot(dst,ylim=(0.0,0.5),grid=false,ylabel="Bus 2")
	p4 = scatter!((dst.μ,pdf(dst,dst.μ)))
	p5 = plot(dst,ylim=(0.0,0.5),grid=false)
	p5 = scatter!((dst.μ,pdf(dst,dst.μ)))
	p6 = plot(dst,ylim=(0.0,0.5),grid=false)
	p6 = scatter!((dst.μ,pdf(dst,dst.μ)))
	p7 = plot(dst,ylim=(0.0,0.5),grid=false,xlabel="Vm",ylabel="Bus 3")
	p7 = scatter!((dst.μ,pdf(dst,dst.μ)))
	p8 = plot(dst,ylim=(0.0,0.5),grid=false,xlabel="Pd")
	p8 = scatter!((dst.μ,pdf(dst,dst.μ)))
	p9 = plot(dst,ylim=(0.0,0.5),grid=false,xlabel="Qd")
	p9 = scatter!((dst.μ,pdf(dst,dst.μ)))
	plot(p1, p2, p3, p4, p5, p6, p7, p8, p9, layout=(3,3), legend=false)
end

# ╔═╡ Cell order:
# ╠═f7e93fee-07ef-11eb-086e-b9bf474d3ed3
# ╠═82a8eef6-07dc-11eb-362e-c5ad10e7219a
# ╠═5def25e0-07ea-11eb-1f7d-1d22b0ab8158
# ╠═2f4f8a72-07ea-11eb-3f2f-0922fffe8de3
# ╠═e9941b80-07dd-11eb-343e-9dbc8ffb00c1
# ╠═c10ba066-07d8-11eb-2127-f9b41999b5f7
# ╠═42dfb878-07e5-11eb-1207-718e519a9d44
# ╠═3bb9c3a4-07e5-11eb-0931-29f5376b6cac
# ╠═225e91e6-07ea-11eb-2a32-f16b81606fd5
# ╟─52b4f514-07e1-11eb-3efd-37d5c380c352
# ╠═f096624e-07e9-11eb-3c2e-d52071c61445
# ╠═ca25545a-07db-11eb-2a34-95f8908ed247
# ╠═d615ce5c-07dd-11eb-3158-ff5f0d1d6710
# ╠═e316de5a-07dd-11eb-37cf-db21d64bef14
# ╟─171f37c0-07f1-11eb-1dea-8ddb1beb0a21
