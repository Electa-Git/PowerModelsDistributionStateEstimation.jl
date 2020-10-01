################################################################################
#  Copyright 2020, Tom Van Acker, Marta Vanin                                  #
################################################################################
# PowerModelsDSSE.jl                                                           #
# An extention package of PowerModelsDistribution.jl for Static Distribution   #
# System State Estimation.                                                     #
# See http://github.com/timmyfaraday/PowerModelsDSSE.jl                        #
################################################################################

@testset "Benchmark vs power flow" begin
    season     = "summer"
    time       = 144
    elm        = ["load", "pv"]
    pfs        = [0.95, 0.90]
    rm_transfo = true
    rd_lines   = true

    # set measurement path
    msr_path = joinpath(_PMS.BASE_DIR,"test/data/enwl/measurements/temp.csv")

    @testset "ACP-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMs.ACPPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(model, data, pf_result, msr_path, exclude = ["vr","vi"])

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "ACP-WLS" begin
        # set model
        crit = "wls"
        model = _PMs.ACPPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rACP-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMS.ReducedACPPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(model, data, pf_result, msr_path, exclude = ["vr","vi"])

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rACP-WLS" begin
        # set model
        crit = "wls"
        model = _PMS.ReducedACPPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "ACR-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMs.ACRPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "ACR-WLS" begin
        # set model
        crit = "wls"
        model = _PMs.ACRPowerModel

        # solve the feeders
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rACR-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMS.ReducedACRPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, _PMs.ACRPowerModel, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(_PMs.ACRPowerModel, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rACR-WLS" begin
        # set model
        crit = "wls"
        model = _PMS.ReducedACRPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, _PMs.ACRPowerModel, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(_PMs.ACRPowerModel, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "IVR-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMs.IVRPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "IVR-WLS" begin
        # set model
        crit = "wls"
        model = _PMs.IVRPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(model, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rIVR-rwlav" begin
        # set model
        crit = "rwlav"
        model = _PMS.ReducedIVRPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, _PMs.IVRPowerModel, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(_PMs.IVRPowerModel, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
    @testset "rIVR-WLS" begin
        # set model
        crit = "wls"
        model = _PMS.ReducedIVRPowerModel

        # load data
        data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMS.rm_enwl_transformer!(data) end
        if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end

        # insert the load profiles
        _PMS.insert_profiles!(data, season, elm, pfs, t = time)

        # transform data model
        data = _PMD.transform_data_model(data);

        # solve the power flow
        pf_result = _PMD.run_mc_pf(data, _PMs.IVRPowerModel, ipopt_solver)

        # write measurements based on power flow
        _PMS.write_measurements!(_PMs.IVRPowerModel, data, pf_result, msr_path)

        # read-in measurement data and set initial values
        _PMS.add_measurements!(data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(data)
        _PMS.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                           "rescaler" => 100)

        # solve the state estimation
        se_result = _PMS.run_mc_se(data, model, ipopt_solver)

        # tests
        delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)
    end
end
