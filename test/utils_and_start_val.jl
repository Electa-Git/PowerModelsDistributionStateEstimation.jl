## The scope of this test set is to check that the helper functions in core/utils.jl and core/start_values_methods.jl don't break

msr_path = joinpath(BASE_DIR, "test/data/extra/measurements/case3_meas.csv")
data = _PMD.parse_file(joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss"); data_model=MATHEMATICAL)
.add_measurements!(data, msr_path, actual_meas = true)
pf_result= _PMD.run_mc_pf(data, _PMD.ACPPowerModel, ipopt_solver)

@testset "utils" begin

    vn = 1.0
    pg = 1.0
    qg = 0.3*pg
    pd = 0.05
    qd = 0.3*pd

    update_all_bounds!(data; v_min=0.9*vn, v_max=1.1*vn, pg_min=-pg, pg_max=pg, qg_min=-qg, qg_max=qg, pd_min=-pd, pd_max=pd, qd_min=-qd, qd_max=qd)

    @test data["bus"]["1"]["vmin"][1] == data["bus"]["1"]["vmin"][2] == 0.9*vn
    @test data["bus"]["1"]["vmax"][1] == data["bus"]["1"]["vmax"][2] == 1.1*vn
    @test data["gen"]["1"]["pmin"][1] == data["gen"]["1"]["pmin"][2] == -pg
    @test data["gen"]["1"]["pmax"][1] == data["gen"]["1"]["pmax"][2] == pg
    @test data["load"]["1"]["pmin"][1] == data["load"]["1"]["pmin"][2] == -pd
    @test data["load"]["1"]["pmax"][1] == data["load"]["1"]["pmax"][2] == pd
    @test data["gen"]["1"]["qmin"][1] == data["gen"]["1"]["qmin"][2] == -qg
    @test data["gen"]["1"]["qmax"][1] == data["gen"]["1"]["qmax"][2] == qg
    @test data["load"]["1"]["qmin"][1] == data["load"]["1"]["qmin"][2] == -qd
    @test data["load"]["1"]["qmax"][1] == data["load"]["1"]["qmax"][2] == qd

    .assign_default_individual_criterion!(data; chosen_criterion="rwls")

    @test data["meas"]["2"]["crit"] == "rwls"
    @test data["meas"]["10"]["crit"] == "rwls"

    for (m, meas) in data["meas"]
        if meas["var"] ∈ [:pd, :qd]
           .assign_default_individual_criterion!(data["meas"][m]; chosen_criterion="mle")
       else
          .assign_default_individual_criterion!(data["meas"][m]; chosen_criterion="rwlav")
       end
    end

    @test data["meas"]["7"]["crit"] == "mle"
    @test data["meas"]["10"]["crit"] == "mle"
    @test data["meas"]["1"]["crit"] == "rwlav"
    @test data["meas"]["2"]["crit"] == "rwlav"
    @test data["meas"]["6"]["crit"] == "rwlav"

    assign_start_to_variables!(data)
    @test isapprox(data["bus"]["4"]["vm_start"][1], 0.9959; atol = 1e-7)
    @test isapprox(data["load"]["1"]["qd_start"][2], 0.006; atol = 1e-7)

    assign_start_to_variables!(data, pf_result)
    @test isapprox(data["bus"]["3"]["vm_start"][2], 0.981757; atol = 1e-7)
    @test isapprox(data["load"]["3"]["pd_start"][1], 0.018; atol = 1e-7)

    .assign_residual_ub!(data)
    @test data["meas"]["7"]["res_max"] == 100

    data["se_settings"] = Dict{String, Any}("rescaler" => 50)
    .assign_residual_ub!(data, chosen_upper_bound=10.0, rescale = true)
    @test data["meas"]["7"]["res_max"] == 500

end
