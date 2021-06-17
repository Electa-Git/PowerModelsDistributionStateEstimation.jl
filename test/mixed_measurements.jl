@testset "Mixed measurements (vs pf)" begin

    # set measurement path
    msr_path = joinpath(mktempdir(),"temp.csv")

    @testset "ACP-rwlav" begin
        # set model
        crit     = "rwlav"
        model    = _PMD.ACPUPowerModel #this is going to be used for the SE

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
         data = _PMD.transform_data_model(data);

        for data_model in [_PMD.ACRUPowerModel,_PMD.IVRUPowerModel]
            # solve the power flow
            pf_result = _PMD.solve_mc_pf(data, data_model, ipopt_solver)

            # write measurements based on power flow
            _PMDSE.write_measurements!(data_model, data, pf_result, msr_path, exclude = ["vi","vr"])

            # read-in measurement data and set initial values
            _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
            _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
            _PMDSE.assign_start_to_variables!(data)
            _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
            # set se settings
            data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                               "rescaler" => 1)

            # solve the state estimation
            se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 5e-5)
            @test isapprox(avg, 0.0; atol = 1e-7)
        end
    end
    @testset "ACP-WLS" begin
        # set model
        crit     = "wls"
        model    = _PMD.ACPUPowerModel
        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        for data_model in [_PMD.ACRUPowerModel,_PMD.IVRUPowerModel]
            # solve the power flow
            pf_result = _PMD.solve_mc_pf(data, data_model, ipopt_solver)

            # write measurements based on power flow
            _PMDSE.write_measurements!(data_model, data, pf_result, msr_path, exclude = ["vi","vr"])

            # read-in measurement data and set initial values
            _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
            _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
            _PMDSE.assign_start_to_variables!(data)
            _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
            # set se settings
            data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                               "rescaler" => 1)

            # solve the state estimation
            se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 5e-5)
            @test isapprox(avg, 0.0; atol = 2e-6)
        end
    end
    @testset "ACR-rwlav" begin
        # set model
        crit     = "rwlav"
        model    = _PMD.ACRUPowerModel
        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        for data_model in [_PMD.ACPUPowerModel,_PMD.IVRUPowerModel]
            # solve the power flow
            pf_result = _PMD.solve_mc_pf(data, data_model, ipopt_solver)

            # write measurements based on power flow
            _PMDSE.write_measurements!(data_model, data, pf_result, msr_path)

            # read-in measurement data and set initial values
            _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
            _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
            _PMDSE.assign_start_to_variables!(data)
            _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

            # set se settings
            data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                               "rescaler" => 1)

            # solve the state estimation
            se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 5e-5)
            @test isapprox(avg, 0.0; atol = 1e-7)
        end
    end
    @testset "ACR-WLS" begin
        # set model
        crit     = "wls"
        model    = _PMD.ACRUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        for data_model in [_PMD.ACPUPowerModel,_PMD.IVRUPowerModel]
            # solve the power flow
            pf_result = _PMD.solve_mc_pf(data, data_model, ipopt_solver)

            # write measurements based on power flow
            _PMDSE.write_measurements!(data_model, data, pf_result, msr_path)

            # read-in measurement data and set initial values
            _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
            _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
            _PMDSE.assign_start_to_variables!(data)
            _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
            # set se settings
            data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                               "rescaler" => 1)

            # solve the state estimation
            se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 5e-5)
            @test isapprox(avg, 0.0; atol = 1e-7)
        end
    end
    @testset "IVR-rwlav" begin
        # set model
        crit     = "rwlav"
        model    = _PMD.IVRUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        for data_model in [_PMD.ACPUPowerModel,_PMD.ACRUPowerModel]
            # solve the power flow
            pf_result = _PMD.solve_mc_pf(data, data_model, ipopt_solver)

            # write measurements based on power flow
            _PMDSE.write_measurements!(data_model, data, pf_result, msr_path)

            # read-in measurement data and set initial values
            _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
            _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
            _PMDSE.assign_start_to_variables!(data)
            _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
            # set se settings
            data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                               "rescaler" => 1)

            # solve the state estimation
            se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 5e-5)
            @test isapprox(avg, 0.0; atol = 1e-7)
        end
    end
    @testset "IVR-WLS" begin
        # set model
        crit     = "wls"
        model    = _PMD.IVRUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        for data_model in [_PMD.ACPUPowerModel,_PMD.ACRUPowerModel]
            # solve the power flow
            pf_result = _PMD.solve_mc_pf(data, data_model, ipopt_solver)

            # write measurements based on power flow
            _PMDSE.write_measurements!(data_model, data, pf_result, msr_path)

            # read-in measurement data and set initial values
            _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
            _PMDSE.add_voltage_measurement!(data, pf_result, 0.005)
            _PMDSE.assign_start_to_variables!(data)
            _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
            # set se settings
            data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                               "rescaler" => 1)

            # solve the state estimation
            se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 5e-5)
            @test isapprox(avg, 0.0; atol = 4e-7)
        end
    end
end
