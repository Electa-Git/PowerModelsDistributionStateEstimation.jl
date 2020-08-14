@testset "test variable conversions" begin
    #NB -> most cases don't solve to local optimiality. This test is just to see if the measurement conversions are done smoothly
    #      or an error occurs
    @testset "acp -> allACP wlav" begin
        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        pmd_data["setting"] = Dict{String, Any}("estimation_criterion" => "wlav")
        meas = "$(@__DIR__)/data/measurement_files/case3_allACP.csv"
        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)
        se_res = PowerModelsDSSE.run_acp_mc_se(pmd_data, ipopt_solver_se)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMs.ACPPowerModel, ipopt_solver_pf)
        vm_err_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "vm")
        va_err_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "va")
        @test isapprox(vm_err_max, 0.0012480769294694882; atol=1e-8)
        @test isapprox(vm_err_mean, 0.0009348496178256301; atol=1e-8)
        @test isapprox(va_err_max, 3.5694194496515425e-5; atol=1e-8)
        @test isapprox(va_err_mean, 8.910758438434961e-6; atol=1e-8)
    end
    @testset "ivr -> allIVR wlav" begin
        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        pmd_data["setting"] = Dict{String, Any}("estimation_criterion" => "wlav")
        meas = "$(@__DIR__)/data/measurement_files/case3_allIVR.csv"
        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)
        se_res = PowerModelsDSSE.run_ivr_mc_se(pmd_data, ipopt_solver_se)
        pf_res = _PMD.run_mc_pf(pmd_data, _PMs.IVRPowerModel, ipopt_solver_pf)
        vm_err_array,vm_err_max,vm_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "vm")
        va_err_array,va_err_max,va_err_mean = PowerModelsDSSE.calculate_error(se_res, pf_res; vm_or_va = "va")
        @test isapprox(vm_err_max, 0.0012480847927561767; atol=1e-8)
        @test isapprox(vm_err_mean, 0.0009348577131166047; atol=1e-8)
        @test isapprox(va_err_max, 3.5697705122062634e-5; atol=1e-8)
        @test isapprox(va_err_mean, 8.910928529895546e-6; atol=1e-8)
    end
    @testset "acr -> allACR wlav" begin
        data = _PMD.parse_file("$(@__DIR__)/data/opendss_feeders/case3_unbalanced.dss")
        pmd_data = _PMD.transform_data_model(data)
        pmd_data["setting"] = Dict{String,Any}("estimation_criterion" => "wlav")
        meas_acr = "$(@__DIR__)/data/measurement_files/case3_allACR.csv"
        PowerModelsDSSE.add_measurement_to_pmd_data!(pmd_data, meas_acr; actual_meas=false, seed=0)
        PowerModelsDSSE.assign_start_to_variables!(pmd_data)
        se_res_acr = PowerModelsDSSE.run_acr_mc_se(pmd_data, ipopt_solver_se)
        pf_res_acr = _PMD.run_mc_pf(pmd_data, _PMs.ACRPowerModel, ipopt_solver_pf)
        vm_error_array,vm_err_max_acr,vm_err_mean_acr = PowerModelsDSSE.calculate_error(se_res_acr, pf_res_acr; vm_or_va = "vm")
        va_error_array,va_err_max_acr,va_err_mean_acr = PowerModelsDSSE.calculate_error(se_res_acr, pf_res_acr; vm_or_va = "va")
        @test isapprox(vm_err_max_acr, 0.0012476940828828331; atol=1e-8)
        @test isapprox(vm_err_mean_acr, 0.0009345519350596835; atol=1e-8)
        @test isapprox(va_err_max_acr, 3.5687537372972034e-5; atol=1e-8)
        @test isapprox(va_err_mean_acr, 8.910865170338089e-6; atol=1e-8)
    end
end#@testset
