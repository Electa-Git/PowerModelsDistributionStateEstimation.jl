#NB: wlav without relaxation virtually never converges not even with rescaler, 3 buses case and linear formulation. It is therefore not tested

@testset "test different estimation criteria" begin

    msr_path = joinpath(BASE_DIR, "test/data/extra/measurements/case3_meas.csv")
    data = _PMD.parse_file(joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss"); data_model=MATHEMATICAL)
    _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
    pf_result = _PMD.solve_mc_pf(data, _PMD.ACPUPowerModel, ipopt_solver)

    @testset "Equivalence of WLS-rWLS" begin

        rescaler = 1

        data["se_settings"] = Dict{String,Any}("criterion" => "rwls", "rescaler" => rescaler)
        se_result_rwls = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)

        data["se_settings"] = Dict{String,Any}("criterion" => "wls", "rescaler" => rescaler)
        se_result_wls = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)

        @test isapprox(se_result_rwls["objective"]-se_result_wls["objective"], 0.0; atol = 1e-5)

    end

    @testset "MLE with normal distr - no error" begin

        rescaler = 1

        data["se_settings"] = Dict{String,Any}("criterion" => "rwls", "rescaler" => rescaler)
        se_result_rwls = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)
        delta, max_err, avg = _PMDSE.calculate_voltage_magnitude_error(se_result_rwls, pf_result)

        data["se_settings"] = Dict{String,Any}("criterion" => "mle", "rescaler" => rescaler)
        se_result_mle = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)
        delta, max_err_mle, avg_mle = _PMDSE.calculate_voltage_magnitude_error(se_result_mle, pf_result)

        @test se_result_mle["termination_status"] ∈ [LOCALLY_SOLVED, ALMOST_LOCALLY_SOLVED]
        @test isapprox(se_result_mle["objective"], se_result_rwls["objective"]; atol = 2e-5)
        @test isapprox(abs(max_err-max_err_mle), 0.0; atol = 2e-5)
        @test isapprox(abs(avg-avg_mle), 0.0; atol = 1e-5)
    end

    @testset "Mixed mle/wls criterion - no error" begin

        rescaler = 1

        data["se_settings"] = Dict{String,Any}("criterion" => "rwls", "rescaler" => rescaler)
        se_result_rwls = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)
        delta, max_err, avg = _PMDSE.calculate_voltage_magnitude_error(se_result_rwls, pf_result)

        data["se_settings"] = Dict{String,Any}("rescaler" => rescaler)
        for (m, meas) in data["meas"]
            if meas["var"] ∈ [:pd, :qd]
               _PMDSE.assign_basic_individual_criteria!(data["meas"][m]; chosen_criterion="mle")
           else
               _PMDSE.assign_basic_individual_criteria!(data["meas"][m]; chosen_criterion="rwls")
           end
        end
        se_result_mixed = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)
        delta, max_err_mixed, avg_mixed = _PMDSE.calculate_voltage_magnitude_error(se_result_mixed, pf_result)

        @test se_result_mixed["termination_status"] ∈ [LOCALLY_SOLVED, ALMOST_LOCALLY_SOLVED]
        @test isapprox(se_result_mixed["objective"], se_result_rwls["objective"]; atol = 2e-5)
        @test isapprox(abs(max_err-max_err_mixed), 0.0; atol = 2e-5)
        @test isapprox(abs(avg-avg_mixed), 0.0; atol = 1e-5)
    end

    _PMDSE.add_measurements!(data, msr_path, actual_meas = false)
    pf_result= _PMD.solve_mc_pf(data, _PMD.ACPUPowerModel, ipopt_solver)
    rescaler = 1

    @testset "MLE with normal distr - with error" begin

        data["se_settings"] = Dict{String,Any}("criterion" => "rwls", "rescaler" => rescaler)
        se_result_rwls = _PMDSE.solve_acr_red_mc_se(data, ipopt_solver)
        delta, max_err, avg = _PMDSE.calculate_voltage_magnitude_error(se_result_rwls, pf_result)

        data["se_settings"] = Dict{String,Any}("criterion" => "mle", "rescaler" => rescaler)
        se_result_mle = _PMDSE.solve_acr_red_mc_se(data, ipopt_solver)
        delta, max_err_mle, avg_mle = _PMDSE.calculate_voltage_magnitude_error(se_result_mle, pf_result)

        @test se_result_mle["termination_status"] == LOCALLY_SOLVED
        @test isapprox(abs(max_err-max_err_mle), 0.0; atol = 1e-4)
        @test isapprox(abs(avg-avg_mle), 0.0; atol = 1e-5)
    end

    @testset "Mixed mle/rwlav criterion - with error" begin

        data["se_settings"] = Dict{String,Any}("criterion" => "rwls", "rescaler" => rescaler)
        se_result_rwls = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)
        delta, max_err, avg = _PMDSE.calculate_voltage_magnitude_error(se_result_rwls, pf_result)

        data["se_settings"] = Dict{String,Any}( "rescaler" => rescaler)
        for (m, meas) in data["meas"]
            if meas["var"] ∈ [:pd, :qd]
               _PMDSE.assign_basic_individual_criteria!(data["meas"][m]; chosen_criterion="mle")
           else
               _PMDSE.assign_basic_individual_criteria!(data["meas"][m]; chosen_criterion="rwls")
           end
        end
        se_result_mixed = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)
        delta, max_err_mixed, avg_mixed = _PMDSE.calculate_voltage_magnitude_error(se_result_mixed, pf_result)

        @test se_result_mixed["termination_status"] == LOCALLY_SOLVED
        @test isapprox(abs(max_err-max_err_mixed), 0.0; atol = 3e-4)
        @test isapprox(abs(avg-avg_mixed), 0.0; atol = 6e-5)
    end
end
