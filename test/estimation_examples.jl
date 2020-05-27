@testset "test state estimators" begin

    @testset "case3_unbalanced" begin

        meas_case3 = "test/data/case3_input.csv"
        data_case3 = _PMD.parse_file("test/data/opendss/case3_unbalanced.dss")
        pmd_data_case3 = _PMD.transform_data_model(data_case3)
        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data_case3, meas_case3, false, 0)
        PowerModelsDSSE.add_measurement_id_to_load!(pmd_data_case3, meas_case3)
        pmd_data["setting"] = Dict("weight_rescaler" => 100)

        @testset "simple acp case3 wlav se" begin
            pmd_data_case3["setting"] = Dict("estimation_criterion" => "wlav")
            se_res_case3 = PowerModelsDSSE.run_acp_mc_se(pmd_data_case3, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
            pf_res_case3 = _PMD.run_mc_opf(pmd_data_case3, _PMs.ACPPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
            vm_err_array_case3,err_max_case3,err_mean_case3 = PowerModelsDSSE.calculate_vm_error(se_res_case3, pf_res_case3)
            @test se_res_case3["termination_status"] == LOCALLY_SOLVED
            @test isapprox(se_res_case3["objective"], 12060.6; atol=1e-1)
            @test isapprox(err_max_case3, 0.001248076; atol=1e-8)
            @test isapprox(err_mean_case3, 0.0009348498; atol=1e-8)
        end

        @testset "simple acp case3 wls se" begin
            pmd_data_case3["setting"] = Dict("estimation_criterion" => "wls")
            se_res_case3 = PowerModelsDSSE.run_acp_mc_se(pmd_data_case3, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
            pf_res_case3 = _PMD.run_mc_opf(pmd_data_case3, _PMs.ACPPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
            vm_err_array_case3,err_max_case3,err_mean_case3 = PowerModelsDSSE.calculate_vm_error(se_res_case3, pf_res_case3)
            @test se_res_case3["termination_status"] == LOCALLY_SOLVED
            @test isapprox(se_res_case3["objective"], 4.093414; atol=1e-2)
            @test isapprox(err_max_case3, 0.001259760; atol=1e-8)
            @test isapprox(err_mean_case3, 0.000949073; atol=1e-8)
        end

        @testset "simple ivr case3 wlav se" begin
            pmd_data_case3["setting"] = Dict("estimation_criterion" => "wlav")
            se_res_case3 = PowerModelsDSSE.run_ivr_mc_se(pmd_data_case3, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
            pf_res_case3 = _PMD.run_mc_opf(pmd_data_case3, _PMs.IVRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
            vm_err_array_case3,err_max_case3,err_mean_case3 = PowerModelsDSSE.calculate_vm_error(se_res_case3, pf_res_case3)
            @test se_res_case3["termination_status"] == LOCALLY_SOLVED
            @test isapprox(se_res_case3["objective"], 13465.696; atol=1e-1)
            @test isapprox(err_max_case3, 0.00124807142; atol=1e-8)
            @test isapprox(err_mean_case3, 0.00093484531; atol=1e-8)
        end

        @testset "simple ivr case3 wls se" begin
            pmd_data_case3["setting"] = Dict("estimation_criterion" => "wls")
            se_res_case3 = PowerModelsDSSE.run_ivr_mc_se(pmd_data_case3, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
            pf_res_case3 = _PMD.run_mc_opf(pmd_data_case3, _PMs.IVRPowerModel, optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0))
            vm_err_array_case3,err_max_case3,err_mean_case3 = PowerModelsDSSE.calculate_vm_error(se_res_case3, pf_res_case3)
            @test se_res_case3["termination_status"] == LOCALLY_SOLVED
            @test isapprox(se_res_case3["objective"], 1.4563855499; atol=1e-2)
            @test isapprox(err_max_case3, 0.001259888; atol=1e-8)
            @test isapprox(err_mean_case3,0.0009490964; atol=1e-8)
        end
    end#case3_unabalanced
end#@testset
