
@testset "Benchmark vs power flow" begin

    # set measurement path
    msr_path = joinpath(mktempdir(),"temp.csv")

    @testset "ACP-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMD.ACPUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vr","vi"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "ACP-WLS" begin
        # set model
        crit = "wls"
        model = _PMD.ACPUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rACP-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMDSE.ReducedACPPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path, exclude = ["vr","vi"])

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rACP-WLS" begin
        # set model
        crit = "wls"
        model = _PMDSE.ReducedACPPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "ACR-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMD.ACRUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "ACR-WLS" begin
        # set model
        crit = "wls"
        model = _PMD.ACRUPowerModel

        # solve the feeders
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rACR-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMDSE.ReducedACRPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, _PMD.ACRUPowerModel, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(_PMD.ACRUPowerModel, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rACR-WLS" begin
        # set model
        crit = "wls"
        model = _PMDSE.ReducedACRPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, _PMD.ACRUPowerModel, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(_PMD.ACRUPowerModel, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "IVR-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMD.IVRUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "IVR-WLS" begin
        # set model
        crit = "wls"
        model = _PMD.IVRUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rIVR-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMDSE.ReducedIVRPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, _PMD.IVRUPowerModel, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(_PMD.IVRUPowerModel, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rIVR-WLS" begin
        # set model
        crit = "wls"
        model = _PMDSE.ReducedIVRPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
        if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, _PMD.IVRUPowerModel, ipopt_solver)

        # write measurements based on power flow
        _PMDSE.write_measurements!(_PMD.IVRUPowerModel, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        _PMDSE.assign_start_to_variables!(data)
        _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
end
