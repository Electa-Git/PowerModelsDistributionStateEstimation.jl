@testset "test SDP and LinDist3Flow" begin
    ##################
    ######  The test provided for the SDP formulation is limited to one small example. This is due to two reasons:
    ######  1) the effectiveness of the formulation depends on the presence of rescaling, variable bounds and in general requires attentive, case-oriented user supervision
    ######  2) the outcome of the free solver SCS is extremely sensitive to the value of alpha and eps parameters. For real use, a different solver is advised (e.g. Mosek)
    ######  Therefore, the example below is just a basic error check.
    ##################

    # set measurement path for all cases
    msr_path = joinpath(mktempdir(),"temp.csv")

    @testset "SDP with rwlav and rwls" begin

        sdp_data = _PMD.parse_file(joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss"); transformations = [make_lossless!])
        sdp_data["settings"]["sbase_default"] = 0.001 * 1e3
        merge!(sdp_data["voltage_source"]["source"], Dict{String,Any}(
            "cost_pg_parameters" => [0.0, 1000.0, 0.0],
            "pg_lb" => fill(  0.0, 3),
            "pg_ub" => fill( 10.0, 3),
            "qg_lb" => fill(-10.0, 3),
            "qg_ub" => fill( 10.0, 3),
            )
        )

        for (_,line) in sdp_data["line"]
            line["sm_ub"] = fill(10.0, 3)
        end

        sdp_data = transform_data_model(sdp_data)

        for (_,bus) in sdp_data["bus"]
            if bus["name"] != "sourcebus"
                bus["vmin"] = fill(0.9, 3)
                bus["vmax"] = fill(1.1, 3)
            end
        end

        pf_result = _PMD.run_mc_pf(sdp_data, _PMD.SDPUBFPowerModel, scs_solver)
        _PMS.write_measurements!(_PMD.SDPUBFPowerModel, sdp_data, pf_result, msr_path, exclude = ["vi","vr"])
        _PMS.add_measurements!(sdp_data, msr_path, actual_meas = true)
        _PMS.assign_start_to_variables!(sdp_data)
        PowerModelsDistributionStateEstimation.vm_to_w_conversion!(sdp_data)
        _PMS.update_voltage_bounds!(data; v_min = 0.9, v_max = 1.0)

        sdp_data["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1)
        se_result_sdp_wlav = PowerModelsDistributionStateEstimation.run_sdp_mc_se(sdp_data, scs_solver)

        sdp_data["se_settings"] = Dict{String,Any}("criterion" => "rwls", "rescaler" => 1)
        se_result_sdp_wls = PowerModelsDistributionStateEstimation.run_sdp_mc_se(sdp_data, scs_solver)

        #delta_wlav, max_err_wlav, avg_wlav = _PMS.calculate_voltage_magnitude_error(se_result_sdp_wlav, pf_result)
        delta_wls, max_err_wls, avg_wls = _PMS.calculate_voltage_magnitude_error(se_result_sdp_wls, pf_result)

        @test se_result_sdp_wlav["termination_status"] == ALMOST_OPTIMAL
        @test se_result_sdp_wls["termination_status"] == OPTIMAL
        @test isapprox(max_err_wls, 0.000767; atol=1e-2)
        @test isapprox(avg_wls, 0.000344; atol=1e-2)
        @test isapprox(se_result_sdp_wls["objective"], 1.56e-5; atol=1e-3)
        #@test isapprox(max_err_wlav, 0.046954; atol=2e-1)
        #@test isapprox(avg_wlav, 0.012229; atol=1e-1)
        #@test isapprox(se_result_sdp_wlav["objective"], 0.00732792; atol=1e-2)
    end

    season     = "summer"
    time       = 144
    elm        = ["load", "pv"]
    pfs        = [0.95, 0.90]
    rm_transfo = true
    rd_lines   = true

    @testset "LinDist3Flow - rwlav" begin
        crit = "rwlav"
        model = _PMD.LPUBFDiagPowerModel

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

    @testset "LinDist3Flow - wls" begin
        crit = "wls"
        model = _PMD.LPUBFDiagPowerModel

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
    @testset "LinDist3Flow - rwlav" begin
        crit = "rwlav"
        model = _PMD.LPUBFDiagPowerModel

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
end
