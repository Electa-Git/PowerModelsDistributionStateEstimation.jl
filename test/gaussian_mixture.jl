@testset "Gaussian mixture models" begin

    msr_path = joinpath(mktempdir(),"temp.csv")

    model    = _PMs.ACPPowerModel #this is going to be used for the SE

    # load data
    data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
    if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
    if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

    # insert the load profiles
    _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

    @testset "Gaussian Mixture - no errors" begin

        data = _PMD.transform_data_model(data);

        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)
        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        for (m, meas) in data["meas"]
            if meas["var"] ∈ [:pd, :qd]
                meas["crit"] = "gmm"
             else
               meas["crit"] = "rwlav"
            end
        end

        data["se_settings"] = Dict{String,Any}("number_of_gaussian" => 5)

        # solve the state estimation
        se_result = _PMDSE.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 5e-5)
        @test isapprox(avg, 0.0; atol = 1e-7)

    end

    @testset "Gaussian Mixture - with errors" begin

        data = _PMD.transform_data_model(data);
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)
        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = false)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        for (m, meas) in data["meas"]
            if meas["var"] ∈ [:pd, :qd]
                meas["crit"] = "gmm"
             else
               meas["crit"] = "rwlav"
            end
        end

        # solve the state estimation
        se_result = _PMDSE.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.004; atol = 1e-3)
        @test isapprox(avg, 0.003; atol = 1e-3)
    end

    @testset "Gaussian Mixture VS MLE betas" begin

        data = _PMD.transform_data_model(data);
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)
        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        _PMDSE.assign_basic_individual_criteria!(data; chosen_criterion="rwlav")
        data["meas"]["21"]["crit"] = "mle"
        data["meas"]["22"]["crit"] = "mle"

        # solve the state estimation
        se_result_mle = _PMDSE.run_mc_se(data, model, ipopt_solver)
        delta_mle, max_mle, avg_mle = _PMDSE.calculate_voltage_magnitude_error(se_result_mle, pf_result)

        data["meas"]["21"]["crit"] = "gmm"
        data["meas"]["22"]["crit"] = "gmm"

        se_result_gmm = _PMDSE.run_mc_se(data, model, ipopt_solver)
        delta_gmm, max_gmm, avg_gmm = _PMDSE.calculate_voltage_magnitude_error(se_result_gmm, pf_result)
        # tests
        @test isapprox(max_mle-max_gmm, 0.000; atol = 1e-6)
        @test isapprox(avg_mle-avg_gmm, 0.000; atol = 1e-6)
    end
end
