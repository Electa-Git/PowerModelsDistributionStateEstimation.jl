
#The scope of this test set is to check if all formulations provide the same result
#if errors are added on the measurements. We only try the full formulations, not
#the reduced ones, as they would be redundant given their presence in other tests.

@testset "Measurements with errors - comparison between formulations" begin

    # set measurement path
    msr_path = joinpath(mktempdir(),"temp.csv")
    data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
    if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
    if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

    # insert the load profiles
    _PMDSE.insert_profiles!(data, season, elm, pfs, t = time)

    # transform data model
    data = _PMD.transform_data_model(data);

    @testset "ACP input-rwlav" begin
        # set model
        crit     = "rwlav"
        model    = _PMs.ACPPowerModel #this is going to be used for the SE

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        original_se_result = _PMDSE.run_mc_se(data, model, ipopt_solver)
        delta_ref, max_ref, avg_ref = _PMDSE.calculate_voltage_magnitude_error(original_se_result, pf_result)
        for data_model in [_PMs.ACRPowerModel,_PMs.IVRPowerModel]

            # solve the state estimation
            se_result = _PMDSE.run_mc_se(data, data_model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max-max_ref, 0.0; atol = 1e-5)
            @test isapprox(avg-avg_ref, 0.0; atol = 1e-5)
        end
    end
    @testset "ACP input-WLS" begin
        # set model
        crit     = "wls"
        model    = _PMs.ACPPowerModel #this is going to be used for the SE

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 10000)

        # solve the state estimation
        original_se_result = _PMDSE.run_mc_se(data, model, ipopt_solver)
        delta_ref, max_ref, avg_ref = _PMDSE.calculate_voltage_magnitude_error(original_se_result, pf_result)
        for data_model in [_PMs.ACRPowerModel,_PMs.IVRPowerModel]

            # solve the state estimation
            se_result = _PMDSE.run_mc_se(data, data_model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max-max_ref, 0.0; atol = 1e-5)
            @test isapprox(avg-avg_ref, 0.0; atol = 1e-5)
        end
    end
    @testset "ACR input-rwlav" begin
        # set model
        crit     = "rwlav"
        model    = _PMs.ACRPowerModel #this is going to be used for the SE

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        original_se_result = _PMDSE.run_mc_se(data, model, ipopt_solver)
        delta_ref, max_ref, avg_ref = _PMDSE.calculate_voltage_magnitude_error(original_se_result, pf_result)
        for data_model in [_PMs.ACPPowerModel,_PMs.IVRPowerModel]

            # solve the state estimation
            se_result = _PMDSE.run_mc_se(data, data_model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max-max_ref, 0.0; atol = 1e-5)
            @test isapprox(avg-avg_ref, 0.0; atol = 1e-5)
        end
    end
    @testset "ACR input-WLS" begin
        # set model
        crit     = "wls"
        model    = _PMs.ACRPowerModel #this is going to be used for the SE

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        original_se_result = _PMDSE.run_mc_se(data, model, ipopt_solver)
        delta_ref, max_ref, avg_ref = _PMDSE.calculate_voltage_magnitude_error(original_se_result, pf_result)
        for data_model in [_PMs.ACPPowerModel,_PMs.IVRPowerModel]

            # solve the state estimation
            se_result = _PMDSE.run_mc_se(data, data_model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max-max_ref, 0.0; atol = 1e-5)
            @test isapprox(avg-avg_ref, 0.0; atol = 1e-5)
        end
    end
    @testset "IVR input-rwlav" begin
        # set model
        crit     = "rwlav"
        model    = _PMs.IVRPowerModel #this is going to be used for the SE

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        original_se_result = _PMDSE.run_mc_se(data, model, ipopt_solver)
        delta_ref, max_ref, avg_ref = _PMDSE.calculate_voltage_magnitude_error(original_se_result, pf_result)
        for data_model in [_PMs.ACPPowerModel,_PMs.ACRPowerModel]

            # solve the state estimation
            se_result = _PMDSE.run_mc_se(data, data_model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max-max_ref, 0.0; atol = 1e-5)
            @test isapprox(avg-avg_ref, 0.0; atol = 1e-5)
        end
    end
    @testset "IVR input-WLS" begin
        # set model
        crit     = "wls"
        model    = _PMs.IVRPowerModel #this is going to be used for the SE

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vi","vr"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        original_se_result = _PMDSE.run_mc_se(data, model, ipopt_solver)
        delta_ref, max_ref, avg_ref = _PMDSE.calculate_voltage_magnitude_error(original_se_result, pf_result)
        for data_model in [_PMs.ACPPowerModel,_PMs.ACRPowerModel]

            # solve the state estimation
            se_result = _PMDSE.run_mc_se(data, data_model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max-max_ref, 0.0; atol = 1e-5)
            @test isapprox(avg-avg_ref, 0.0; atol = 1e-5)
        end
    end
end
