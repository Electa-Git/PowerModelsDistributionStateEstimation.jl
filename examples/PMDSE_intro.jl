### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ 88d07650-7a69-11eb-0a3c-4168940f5e2d
begin
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add([
			Pkg.PackageSpec(name="PowerModelsDistributionStateEstimation",   version="0.2.3"),
			Pkg.PackageSpec(name="PowerModelsDistribution", version="0.10.2"),
		Pkg.PackageSpec(name="Ipopt", version="0.6.5"),
			Pkg.PackageSpec(name="Plots"), Pkg.PackageSpec(name="CSV")])
	 Pkg.build("Plots")
	using PowerModelsDistributionStateEstimation
	using PowerModelsDistribution
	using Ipopt
	using Plots
	using CSV
	nothing
end

# ╔═╡ 39a2e490-25bf-11eb-2d3a-05fda8c6ecd4
hint(text) = Markdown.MD(Markdown.Admonition("hint", "Hint", [text]));

# ╔═╡ 84ed7c50-2270-11eb-035c-33bda27ed57e
md""" ## ⚡ Power System State Estimation ⚡    with _PowerModelsDistributionStateEstimation.jl_
"""

# ╔═╡ 44035512-2271-11eb-2ffb-2f3c2b8ea231
md"This tutorial is made with Pluto notebooks. You can find details on Pluto.jl (and hence on how to run this notebook) on its [github page](https://github.com/fonsp/Pluto.jl) or have a look at the [JuliaCon2020 presentation](https://www.youtube.com/watch?v=IAF8DjrQSSk&ab_channel=TheJuliaProgrammingLanguage). This notebook is available within the PowerModelsDistributionStateEstimation package, in the /example folder.  

⚠️⚠️ Warning! ⚠️⚠️ This notebook refers to version 0.2.3 of the package. The package is in active development. The idea is that we improve functionalities in the future, without breaking the old ones. But you never know..
"

# ╔═╡ 94c4f342-2277-11eb-2932-89244e8ce3c9
md"________________________________________________________________________________"

# ╔═╡ 9ef21550-2277-11eb-070f-af3e43b62fef
md"### Let's get started: install and call packages" 

# ╔═╡ fa6b2e80-226d-11eb-0500-b7b51a64a01b
md"The following packages are needed for your first state estimation script:   
1) PowerModelsDistributionStateEstimation.jl to build a state estimation model/problem,     
2) PowerModelsDistribution.jl, for power flow calculations and to parse network data, 
3) A solver (in this case Ipopt), to solve the state estimation problem,  
4) Plots.jl, because visuals can make things clearer, 
5) CSV.jl, to read CSV files, we need it towards the end of the notebook.
Note, the packages are installed in a temporary environment (see cell below). This might take a while to compile if it is the first time you run this notebook.
"

# ╔═╡ 7626c130-7a91-11eb-1f0a-a14118b621b4
PMDSE = PowerModelsDistributionStateEstimation

# ╔═╡ 1cffc500-258e-11eb-217b-053f1ced96ae
md"_________________________________________________________________________________  

### Let's get network and measurement data"

# ╔═╡ c8874710-258c-11eb-0447-49d7bc03eb39
md"Let's choose a simple network to design a state estimator for. There is one stored in PMDSE, in test/data/extra/network, we just need to find the path. PMDSE exports the 'BASE_DIR' constant, which allows you to figure out where your installation of the package is located. You can create a new cell and display the value of this variable. Otherwise, let's just define the network path:"

# ╔═╡ 1863f5be-258e-11eb-3b21-1d852ef2601e
ntw_path = joinpath(PMDSE.BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss")

# ╔═╡ fcb32f32-258d-11eb-2d1b-d5a2629873cb
md"Similarly, you can access the measurement file relative to this network, in test/data/extra/measurements. The name of the file is `case3_meas.csv`. Call the path `msr_path`."

# ╔═╡ c0672120-258e-11eb-142c-b52038715ee9
msr_path = joinpath(PMDSE.BASE_DIR, "test/data/extra/measurements/case3_meas.csv")

# ╔═╡ cdaf7070-258f-11eb-0325-dfc2acfc139b
	md"Our network data is an OpenDSS file. Then, we can use the PowerModelsDistribution parser to obtain the data dictionary in the format required for our calculations. You should parse to a `MATHEMATICAL_MODEL`, because what we do next is adding the measurement data on top of the network data. This can't be done on the `ENGINEERING_MODEL`. Mathematical and Engineering models are standard input network data representations. If you are not familiar with them, you should probably read the relative documentation in PowerModelsDistribution, see [this](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/math-model/), and [this](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/eng-data-model/) and the sections thereafter."

# ╔═╡ fd38b2e2-258d-11eb-21b7-11f4d4d3d8bf
data = PowerModelsDistribution.parse_file(ntw_path; data_model=MATHEMATICAL)

# ╔═╡ 160082f0-2591-11eb-38f3-4b21df157408
md"Now we can add the measurement data to the data dictionary above. The information will be stored in `data[\"meas\"]`. The function we need is `add_measurements!()`. It takes as argument the network data dictionary `data`, the path to the measurement file `msr_path` and the parameter `actual_meas`. If the measurement data consists of actual meter measurements, set the latter as `true`. If they are not measurement data but, e.g, power flow results, set it to `false`. More details later :)."

# ╔═╡ fdb89140-258d-11eb-1299-f553c29a42b3
add_measurements!(data, msr_path, actual_meas = true)

# ╔═╡ 9378bcbe-25af-11eb-14c2-83e297d1ff10
md"Inspecting the data dictionary allows to see how the network looks like. Although a picture is handier:

![case3 unbalanced grid pic](https://raw.githubusercontent.com/Electa-Git/PowerModelsDistributionStateEstimation.jl/master/examples/assets/case3_pic.PNG)

We can see that the grid is unbalanced and has one three-phase generator, modelled like a slackbus.

"

# ╔═╡ 945f9c50-2599-11eb-385d-b16132a4fb00
md"_________________________________________________________________________________  
### Let's finalize and solve our SE problem"

# ╔═╡ 1dff2810-2598-11eb-07d6-89579af705b0
md"We are almost ready to run a state estimation, we just need to state what the criteria of the state estimation will be. [SE criteria](https://electa-git.github.io/PowerModelsDistributionStateEstimation.jl/dev/se_criteria/) are `wls`, `wlav`, `rwlav`, etc. Finally, we set a rescaler. Depending on the solver and on the problem case, the low/high weights of some measurements might cause convergence issues. You can set a rescaler that multiplies the weight of all measurements."

# ╔═╡ 1b210e60-2598-11eb-1e18-978f114b214b
data["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1)

# ╔═╡ b40a1b30-2598-11eb-1fef-3fc962eeb5e3
md"To solve the SE problem, we need a solver. We previously picked Ipopt, because it's free and can solve nonlinear problems. Let's call it and set some solver parameters:"

# ╔═╡ 0447f220-2599-11eb-043b-d33b03eec478
slv = PMDSE.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)

# ╔═╡ 115d6710-2599-11eb-1d41-2326cd36aa9f
md"Finally, the last thing to decide is the power flow formulation that describes our problem. Let's go for a classic 'AC' formulation in polar coordinates. It can be chosen it in two different ways: either calling the generic `solve_mc_se(data, model_type, solver)` and passing the formulation, e.g. `_PMD.ACPUPowerModel` as argument `model_type` or by calling the function that directly involves that formulation, as follows:"

# ╔═╡ 490720c0-2599-11eb-0282-67d4a9d8605f
se_result = solve_acp_mc_se(data, slv)

# ╔═╡ 83950ea0-2599-11eb-302d-2759e4f60de4
md"_________________________________________________________________________________  
### Is the estimation accurate?"

# ╔═╡ 71d07410-259a-11eb-16ed-01dc66e83598
md"Let's see what the load magnitudes are, according to the state estimator:"

# ╔═╡ bdf47d00-259a-11eb-2827-3d563dd59e37
se_result["solution"]["load"]

# ╔═╡ fd07f302-259a-11eb-1adf-237ce041edbd
md"Looking at the grid picture, this results seem perhaps even too accurate! Let's quickly have a look at the measurement data:"

# ╔═╡ 415489b0-259b-11eb-37b2-fd455d8aeb90
data["meas"]

# ╔═╡ 58065260-259b-11eb-3a8f-13216b7b7f1b
md"There's virtually no error on the loads! This makes me suspect that the those measurement data are actually not real measurement values, but just the results of a power flow. Let's run a power flow with the real loads and see what the voltage magnitude is, at each bus. We can run a three-phase unbalanced power flow using PowerModelsDistribution's function:"

# ╔═╡ 6ef98650-259a-11eb-3d7f-9dab68152f5d
begin 
	pf_results = PowerModelsDistribution.solve_mc_pf(data, PowerModelsDistribution.ACPUPowerModel, slv)
	pf_results["solution"]["bus"]
end

# ╔═╡ d38df080-259d-11eb-14c8-13bd1dbb8d52
md"It does look like they are the same.. An easier way to compare power flow results (or anything that has the same dictionary structure!) to the SE result is by using the `calculate_voltage_magnitude_error` function:"

# ╔═╡ c5588ca2-259d-11eb-0fbc-718d01b1448b
delta, max_err, avg = calculate_voltage_magnitude_error(se_result, pf_results)

# ╔═╡ ba998ac2-28d2-11eb-384a-e748590fb9f7
md"We can even plot it:"

# ╔═╡ c51ff062-28d2-11eb-2732-dd00cba047e3
scatter(delta, xlabel="Index [-]", ylabel="ϵ [p.u.]", ylims = [0, max_err*1.05], title="Absolute voltage difference ϵ", legend = false)

# ╔═╡ a7e4eaf0-259e-11eb-0797-6d7b6db230c3
md"There is basically no error. This is too good to be true. That measurement file must have been created artificially from power flow results! How and why are explained in the next section. 

⚠️**NB**⚠️: if it is the first time you run this and you get errors > e-7, you might want to manually re-run the cells above where ipopt is called and state estimation and power flow are run (you do this by clicking the triangle symbol at the bottom right of the cells). Sometimes something goes wrong in the solution process at the first go."

# ╔═╡ 8fa94df0-259e-11eb-1c60-8f8662091210
md"________________________________________________________________________________  
### Creating artificial measurement data"

# ╔═╡ 65dcb0e0-259c-11eb-0df5-9781707c96a9
md"Probably that simple small network doesn't really exist. Or maybe it exists but there are no measurements, but the user wanted to explore state estimation designs regardless, for a future installation. If this is also your case, you can provide realistic power values to your load (or generators if you have any, except for the slackbus), and run a power flow. We already did this above, and got `pf_results`. Now let's use that to build artificial measurements."

# ╔═╡ 8ee68da0-25b3-11eb-02f7-5b3909402ce9
begin
	different_msr_path = pwd()*"//tmp_meas.csv"
	write_measurements!(PowerModelsDistribution.ACPUPowerModel, data, pf_results, different_msr_path)
end

# ╔═╡ dbdb3790-25b4-11eb-36e2-a3b2074002f4
md"Let's have a look at the csv file we just created"

# ╔═╡ c3334430-25b4-11eb-1c17-bb32bd1dfe59
meas_df = CSV.read(different_msr_path)

# ╔═╡ fbbe5d30-25b4-11eb-1319-ddf94502c717
md"The function `write_measurements!` takes the power flow results and produces a CSV file. The generated measurements are the voltage magnitude at each bus with a load or a generator, and active and reactive power of each load and generator. If fewer measurements are wished for, the user can delete the csv/dataframe rows. If different or more data is wished for, a customized function needs to be written, or the measurement data needs to be imported/created somewhere else. In column `par_1` of the csv, the values of a given variable from the power flow results are stored. `par_2` gives information on the uncertainty of the \"fake\" or actual meter which is placed there. Our meters here are fake and their error is assumed to follow a gaussian distribution. `par_2` is the standard deviation of the fake meter, and serves two scopes:

1) the inverse of its square is the weight of that measurement,
2) if the `actual_meas` argument in `add_measurements!` is set to `false`, a fake measurement is generated, sampling from the gaussian distribution which has as sigma `par_2` and mu `par_1`. 
Let's see:
"

# ╔═╡ 97d180ce-25b5-11eb-1ae4-4f6681b31964
begin 
	add_measurements!(data, msr_path, actual_meas = false)
	data["meas"]["5"]
end

# ╔═╡ 22f33860-25b7-11eb-201b-07199a206651
meas_df[5, :]

# ╔═╡ 406b0350-25b7-11eb-181b-b1af1beb6c5a
md"
____________________________________________________________________________________  
### Exercise

It is left as excercise to the reader to see that the SE results with the new measurement data, which contain errors, is less accurate than the case in which there was no error on the measurements.
"

# ╔═╡ e2c20b70-25b8-11eb-1f8a-492df3e740b0
md"
__________________________________________________________________________________    
### Is this it?
"

# ╔═╡ 260632d0-25b9-11eb-121c-b32d4595a5b1
md"No, but is the core of the package. All in all, there are a already quite some things mentioned above that you can play with, to design your estimator:
1) Choice of criterion
2) Choice of power flow equations
3) Choice of measurements, that can be \"built\" with the help of the shown functionalities
4) Rescaler

More information on the offered criteria and power flow equations can be found in the documentation. 
Let's conclude with a bunch of additional handy functions:
`update_all_bounds!()` allows to add bounds on loads, generators, and buses. To have a subset, the following also exist: `update_load_bounds!()`, `update_generator_bounds!()`, `update_voltage_bounds!()`.

`convert_rectangular_to_polar!()` in postprocessing, to convert results/entries in rectangular coordinates, into polar coordinates.  

`assign_start_to_variables!()` to give the solver an initial value.

"

# ╔═╡ 04839890-25ba-11eb-2ef5-13c22aa3e9a0
begin 
   update_all_bounds!(data; v_min = 0.85, v_max = 1.15, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
   assign_start_to_variables!(data)
	data["bus"]
end

# ╔═╡ 1b5fe1c0-25bc-11eb-0a5a-d33b22f94dc4
md" Finally, PowerModelsDistributionStateEstimation is designed to be flexible and easy to expand. So, once you are familiar with the package, you can look into the optimization problem itself and add your own constraints, objectives, variables, functions.. 🚀🌕"

# ╔═╡ Cell order:
# ╟─39a2e490-25bf-11eb-2d3a-05fda8c6ecd4
# ╟─84ed7c50-2270-11eb-035c-33bda27ed57e
# ╟─44035512-2271-11eb-2ffb-2f3c2b8ea231
# ╟─94c4f342-2277-11eb-2932-89244e8ce3c9
# ╟─9ef21550-2277-11eb-070f-af3e43b62fef
# ╟─fa6b2e80-226d-11eb-0500-b7b51a64a01b
# ╠═88d07650-7a69-11eb-0a3c-4168940f5e2d
# ╟─7626c130-7a91-11eb-1f0a-a14118b621b4
# ╟─1cffc500-258e-11eb-217b-053f1ced96ae
# ╟─c8874710-258c-11eb-0447-49d7bc03eb39
# ╠═1863f5be-258e-11eb-3b21-1d852ef2601e
# ╟─fcb32f32-258d-11eb-2d1b-d5a2629873cb
# ╠═c0672120-258e-11eb-142c-b52038715ee9
# ╟─cdaf7070-258f-11eb-0325-dfc2acfc139b
# ╠═fd38b2e2-258d-11eb-21b7-11f4d4d3d8bf
# ╟─160082f0-2591-11eb-38f3-4b21df157408
# ╠═fdb89140-258d-11eb-1299-f553c29a42b3
# ╟─9378bcbe-25af-11eb-14c2-83e297d1ff10
# ╟─945f9c50-2599-11eb-385d-b16132a4fb00
# ╟─1dff2810-2598-11eb-07d6-89579af705b0
# ╠═1b210e60-2598-11eb-1e18-978f114b214b
# ╟─b40a1b30-2598-11eb-1fef-3fc962eeb5e3
# ╠═0447f220-2599-11eb-043b-d33b03eec478
# ╟─115d6710-2599-11eb-1d41-2326cd36aa9f
# ╠═490720c0-2599-11eb-0282-67d4a9d8605f
# ╟─83950ea0-2599-11eb-302d-2759e4f60de4
# ╟─71d07410-259a-11eb-16ed-01dc66e83598
# ╠═bdf47d00-259a-11eb-2827-3d563dd59e37
# ╟─fd07f302-259a-11eb-1adf-237ce041edbd
# ╠═415489b0-259b-11eb-37b2-fd455d8aeb90
# ╟─58065260-259b-11eb-3a8f-13216b7b7f1b
# ╠═6ef98650-259a-11eb-3d7f-9dab68152f5d
# ╟─d38df080-259d-11eb-14c8-13bd1dbb8d52
# ╠═c5588ca2-259d-11eb-0fbc-718d01b1448b
# ╟─ba998ac2-28d2-11eb-384a-e748590fb9f7
# ╟─c51ff062-28d2-11eb-2732-dd00cba047e3
# ╟─a7e4eaf0-259e-11eb-0797-6d7b6db230c3
# ╟─8fa94df0-259e-11eb-1c60-8f8662091210
# ╟─65dcb0e0-259c-11eb-0df5-9781707c96a9
# ╠═8ee68da0-25b3-11eb-02f7-5b3909402ce9
# ╟─dbdb3790-25b4-11eb-36e2-a3b2074002f4
# ╠═c3334430-25b4-11eb-1c17-bb32bd1dfe59
# ╟─fbbe5d30-25b4-11eb-1319-ddf94502c717
# ╠═97d180ce-25b5-11eb-1ae4-4f6681b31964
# ╠═22f33860-25b7-11eb-201b-07199a206651
# ╟─406b0350-25b7-11eb-181b-b1af1beb6c5a
# ╟─e2c20b70-25b8-11eb-1f8a-492df3e740b0
# ╟─260632d0-25b9-11eb-121c-b32d4595a5b1
# ╠═04839890-25ba-11eb-2ef5-13c22aa3e9a0
# ╟─1b5fe1c0-25bc-11eb-0a5a-d33b22f94dc4
