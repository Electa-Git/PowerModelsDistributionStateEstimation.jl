################################################################################
#  Copyright 2020, Tom Van Acker, Marta Vanin                                  #
################################################################################
# PowerModelsDSSE.jl                                                           #
# An extention package of PowerModelsDistribution.jl for Static Distribution   #
# System State Estimation.                                                     #
# See http://github.com/timmyfaraday/PowerModelsDSSE.jl                        #
################################################################################

@testset "Benchmark vs pf (max(ΔU)<1e-6,avg(ΔU)<1e-8)" begin
    season     = "summer"
    time       = 144
    elm        = ["load", "pv"]
    pfs        = [0.95, 0.90]
    rm_transfo = true
    rd_lines   = true

    # set measurement path
    msr_path = joinpath(_PMS.BASE_DIR,"test/data/enwl/measurements/temp.csv")

    @testset "ACP-WLAV" begin
        # set model
        crit = "wlav"
        model = _PMs.ACPPowerModel

        # solve the feeders
        for (ntw,fdr) in [(1,2),(4,2),(10,3),(15,7),(20,4)]
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

            # set se settings
            data["setting"] = Dict{String,Any}("estimation_criterion" => crit,
                                               "weight_rescaler" => 1e5)

            # solve the state estimation
            se_result = _PMS.run_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 1e-6)
            @test isapprox(avg, 0.0; atol = 1e-8)
        end
    end
    @testset "ACP-WLS" begin
        # set model
        crit = "wls"
        model = _PMs.ACPPowerModel

        # solve the feeders
        for (ntw,fdr) in [(1,2),(4,2),(10,3),(15,7),(20,4)]
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

            # set se settings
            data["setting"] = Dict{String,Any}("estimation_criterion" => crit,
                                               "weight_rescaler" => 1e5)

            # solve the state estimation
            se_result = _PMS.run_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 1e-6)
            @test isapprox(avg, 0.0; atol = 1e-8)
        end
    end
    @testset "ACR-WLAV" begin
        # set model
        crit = "wlav"
        model = _PMs.ACRPowerModel

        # solve the feeders
        for (ntw,fdr) in [(2,5),(7,3),(11,4),(17,3),(23,1)]
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

            # set se settings
            data["setting"] = Dict{String,Any}("estimation_criterion" => crit,
                                               "weight_rescaler" => 1e5)

            # solve the state estimation
            se_result = _PMS.run_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 1e-6)
            @test isapprox(avg, 0.0; atol = 1e-8)
        end
    end
    @testset "ACR-WLS" begin
        # set model
        crit = "wls"
        model = _PMs.ACRPowerModel

        # solve the feeders
        for (ntw,fdr) in  [(2,5),(7,3),(11,4),(17,3),(23,1)]
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

            # set se settings
            data["setting"] = Dict{String,Any}("estimation_criterion" => crit,
                                               "weight_rescaler" => 1e5)

            # solve the state estimation
            se_result = _PMS.run_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 1e-6)
            @test isapprox(avg, 0.0; atol = 1e-8)
        end
    end
    @testset "IVR-WLAV" begin
        # set model
        crit = "wlav"
        model = _PMs.IVRPowerModel

        # solve the feeders
        for (ntw,fdr) in [(4,4),(9,1),(12,3),(19,5),(25,2)]
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

            # set se settings
            data["setting"] = Dict{String,Any}("estimation_criterion" => crit,
                                               "weight_rescaler" => 1e5)

            # solve the state estimation
            se_result = _PMS.run_mc_se(data, model, ipopt_solver)

            # tests
            delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
            @test isapprox(max, 0.0; atol = 1e-6)
            @test isapprox(avg, 0.0; atol = 1e-8)
        end
    end
    # @testset "IVR-WLS" begin
    #     # set model
    #     crit = "wls"
    #     model = _PMs.IVRPowerModel
    #
    #     # solve the feeders
    #     for (ntw,fdr) in [(4,4),(9,1),(12,3),(19,5),(25,2)]
    #         # load data
    #         data = _PMD.parse_file(_PMS.get_enwl_dss_path(ntw, fdr))
    #         if rm_transfo _PMS.rm_enwl_transformer!(data) end
    #         if rd_lines   _PMS.reduce_enwl_lines_eng!(data) end
    #
    #         # insert the load profiles
    #         _PMS.insert_profiles!(data, season, elm, pfs, t = time)
    #
    #         # transform data model
    #         data = _PMD.transform_data_model(data);
    #
    #         # solve the power flow
    #         pf_result = _PMD.run_mc_pf(data, model, ipopt_solver)
    #
    #         # write measurements based on power flow
    #         _PMS.write_measurements!(model, data, pf_result, msr_path)
    #
    #         # read-in measurement data and set initial values
    #         _PMS.add_measurements!(data, msr_path, actual_meas = true)
    #         _PMS.assign_start_to_variables!(data)
    #
    #         # set se settings
    #         data["setting"] = Dict{String,Any}("estimation_criterion" => crit,
    #                                            "weight_rescaler" => 1e5)
    #
    #         # solve the state estimation
    #         se_result = _PMS.run_mc_se(data, model, ipopt_solver)
    #
    #         # tests
    #         delta, max, avg = _PMS.calculate_voltage_magnitude_error(se_result, pf_result)
    #         @test isapprox(max, 0.0; atol = 1e-6)
    #         @test isapprox(avg, 0.0; atol = 1e-8)
    #     end
    # end

end
