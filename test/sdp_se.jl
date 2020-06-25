@testset "test sdp estimation" begin

    data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss"; transformations=[make_lossless!])
    data["settings"]["sbase_default"] = 0.001 * 1e3
    merge!(data["voltage_source"]["source"], Dict{String,Any}(
        "cost_pg_parameters" => [0.0, 1000.0, 0.0],
        "pg_lb" => fill(  0.0, 3),
        "pg_ub" => fill( 10.0, 3),
        "qg_lb" => fill(-10.0, 3),
        "qg_ub" => fill( 10.0, 3)
    ))

    for (_,line) in data["line"]
        line["sm_ub"] = fill(10.0, 3)
    end

    pmd_data = _PMD.transform_data_model(data) #NB the measurement dict needs to be passed to math model, passing it to the engineering data model won't work

    for (_,bus) in pmd_data["bus"]
        if bus["name"] != "sourcebus"
            bus["vmin"] = fill(0.9, 3)
            bus["vmax"] = fill(1.1, 3)
            bus["vm"] = fill(1.0, 3)
            bus["va"] = deg2rad.([0., -120, 120])
        end
    end

    meas = "$(@__DIR__)/data/measurement_files/case3_SDP.csv"

    PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
    PowerModelsDSSE.assign_start_to_variables!(pmd_data)

    @testset "sdp with wlav" begin

        pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav")

        se_res = PowerModelsDSSE.run_sdp_mc_se(pmd_data, scs_solver)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMD.SDPUBFPowerModel, scs_solver)

        vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error_SDP(se_res, pf_res)

        @test se_res["termination_status"] == ALMOST_OPTIMAL
        @test isapprox(se_res["objective"], 29.088641229631477; atol=1e-1)
        @test isapprox(vm_err_max, 0.0006670287380932116; atol=1e-8)
        @test isapprox(vm_err_mean, 0.00040251513738677317; atol=1e-8)

    end

    @testset "sdp with wls" begin

        pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wls")

        se_res = PowerModelsDSSE.run_sdp_mc_se(pmd_data, scs_solver)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMD.SDPUBFPowerModel, scs_solver)

        vm_error_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error_SDP(se_res, pf_res)

        @test se_res["termination_status"] == ALMOST_OPTIMAL
        @test isapprox(se_res["objective"], 0.008889675818438202; atol=1e-5)
        @test isapprox(vm_err_max, 0.0011589776358038595; atol=1e-8)
        @test isapprox(vm_err_mean, 0.00040544136727201546; atol=1e-8)

    end

end
