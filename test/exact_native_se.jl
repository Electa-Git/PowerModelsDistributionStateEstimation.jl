@testset "test exact state estimators" begin

    @testset "acp native measurements wlav" begin
        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        pmd_data["setting"] = Dict{String, Any}("estimation_criterion" => "wlav")
        meas = "test/data/measurement_files/case3_PQVm.csv"

        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)

        se_res = PowerModelsDSSE.run_acp_mc_se(pmd_data, ipopt_solver_se)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMs.ACPPowerModel, ipopt_solver_pf)

        vm_err_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "vm")
        va_err_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "va")
        @test se_res["termination_status"] == LOCALLY_SOLVED
        @test isapprox(se_res["objective"], 11.346120608883727; atol=1e-1)
        @test isapprox(vm_err_max, 0.0012480757685496835; atol=1e-8)
        @test isapprox(vm_err_mean, 0.0009348494757068412; atol=1e-8)
        @test isapprox(va_err_max, 3.5695211922443654e-5; atol=1e-8)
        @test isapprox(va_err_mean, 8.91060807917249e-6; atol=1e-8)

    end

    @testset "acp native measurements wls" begin

        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        pmd_data["setting"] = Dict{String, Any}("estimation_criterion" => "wls")
        meas = "test/data/measurement_files/case3_PQVm.csv"

        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)

        se_res = PowerModelsDSSE.run_acp_mc_se(pmd_data, ipopt_solver_se)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMs.ACPPowerModel, ipopt_solver_pf)

        vm_err_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "vm")
        va_err_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "va")
        @test se_res["termination_status"] == LOCALLY_SOLVED
        @test isapprox(se_res["objective"], 22.68931852607559; atol=1e-1)
        @test isapprox(vm_err_max, 0.0012725979304710755; atol=1e-8)
        @test isapprox(vm_err_mean, 0.0009481459679652471; atol=1e-8)
        @test isapprox(va_err_max, 3.627765086626489e-5; atol=1e-8)
        @test isapprox(va_err_mean, 9.035606838595754e-6; atol=1e-8)

    end

    @testset "ivr native measurements wlav" begin
        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        pmd_data["setting"] = Dict{String, Any}("estimation_criterion" => "wlav")
        meas = "test/data/measurement_files/case3_CiCrViVr.csv"

        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)

        se_res = PowerModelsDSSE.run_ivr_mc_se(pmd_data, ipopt_solver_se)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, ipopt_solver_pf)

        vm_err_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "vm")
        va_err_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "va")
        @test se_res["termination_status"] == LOCALLY_SOLVED
        @test isapprox(se_res["objective"], 33.85535790233594; atol=1e-1)
        @test isapprox(vm_err_max, 0.0014890577477693068; atol=1e-8)
        @test isapprox(vm_err_mean, 0.0010830620018673447; atol=1e-8)
        @test isapprox(va_err_max, 6.454176738175665e-6; atol=1e-8)
        @test isapprox(va_err_mean, 1.4955652456526462e-6; atol=1e-8)

    end

    @testset "ivr native measurements wls" begin

        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        pmd_data["setting"] = Dict{String, Any}("estimation_criterion" => "wls")
        meas = "test/data/measurement_files/case3_CiCrViVr.csv"

        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)

        se_res = PowerModelsDSSE.run_ivr_mc_se(pmd_data, ipopt_solver_se)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, ipopt_solver_pf)

        vm_err_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "vm")
        va_err_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "va")
        @test se_res["termination_status"] == LOCALLY_SOLVED
        @test isapprox(se_res["objective"], 65.84465128020393; atol=1e-1)
        @test isapprox(vm_err_max, 0.0017386299992961929; atol=1e-8)
        @test isapprox(vm_err_mean, 0.0008983202704361815; atol=1e-8)
        @test isapprox(va_err_max, 1.464165507458759e-5; atol=1e-8)
        @test isapprox(va_err_mean, 3.2300384147285405e-6; atol=1e-8)
    end

    @testset "acr native measurements wlav" begin

        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        meas = "test/data/measurement_files/case3_PQViVr.csv"
        pmd_data["setting"] = Dict{String, Any}("estimation_criterion" => "wlav")

        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)

        se_res = PowerModelsDSSE.run_acr_mc_se(pmd_data, ipopt_solver_se)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMs.ACRPowerModel, ipopt_solver_pf)

        vm_err_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "vm")
        va_err_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "va")
        @test se_res["termination_status"] == LOCALLY_SOLVED
        @test isapprox(se_res["objective"], 32.85844621654043; atol=1e-1)
        @test isapprox(vm_err_max, 0.0014894416712223357; atol=1e-8)
        @test isapprox(vm_err_mean, 0.0010828901893370029; atol=1e-8)
        @test isapprox(va_err_max, 6.446233461436177e-6; atol=1e-8)
        @test isapprox(va_err_mean, 1.493639504599938e-6; atol=1e-8)

    end

    @testset "acr native measurements wls" begin

        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        meas = "test/data/measurement_files/case3_PQViVr.csv"

        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)
        pmd_data["setting"] = Dict{String, Any}("estimation_criterion" => "wls")

        se_res = PowerModelsDSSE.run_acr_mc_se(pmd_data, ipopt_solver_se)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMs.ACRPowerModel, ipopt_solver_pf)

        vm_err_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "vm")
        va_err_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "va")
        @test se_res["termination_status"] == LOCALLY_SOLVED
        @test isapprox(se_res["objective"], 64.09906429526002; atol=1e-1)
        @test isapprox(vm_err_max, 0.001742997087828102; atol=1e-8)
        @test isapprox(vm_err_mean, 0.0009006521474933712; atol=1e-8)
        @test isapprox(va_err_max, 1.402253635074402e-5; atol=1e-8)
        @test isapprox(va_err_mean, 3.2331677195485425e-6; atol=1e-8)
    end

end#@testset
