@testset "IVR three-wire model" begin    
    #3 WIRES MODEL to check nothing broke there when implementing four-wire models
    PF_msr_path = joinpath(mktempdir(),"PF_msr_path.csv")
    σ_3w = 0.05
    dss_file_name = "3bus_3wire.dss"      

    eng = _PMD.parse_file(joinpath(_PMDSE.BASE_DIR, "test", "data", "three-bus-en-models", dss_file_name))
    _PMD.remove_all_bounds!(eng)
    math = _PMD.transform_data_model(eng)
    _PMD.add_start_vrvi!(math)
    pf_res = _PMD.solve_mc_opf(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
    pf_sol = pf_res["solution"]


    _PMDSE.write_measurements!(_PMD.IVRUPowerModel, math, pf_res, PF_msr_path, σ= σ_3w)
    _PMDSE.add_measurements!(math, PF_msr_path, actual_meas = true)   

    math["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1);
    SE= _PMDSE.solve_mc_se(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
    se_sol = SE["solution"]
    @test isapprox(SE["objective"], 0.0; atol = 1e-4)
end


@testset "IVR three-wire - SM_ind measurements  " begin    
    #3 WIRES MODEL to check nothing broke there when implementing four-wire models
    PF_msr_path = joinpath(mktempdir(),"PF_msr_path.csv")
    σ_3w = 0.05
    dss_file_name = "3bus_3wire_delta_single.dss"      
    eng = _PMD.parse_file(joinpath(_PMDSE.BASE_DIR, "test", "data", "three-bus-en-models", dss_file_name))
    _PMD.remove_all_bounds!(eng)
    math = _PMD.transform_data_model(eng)
    _PMD.add_start_vrvi!(math)

    pf_res = _PMD.solve_mc_opf(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
    pf_sol = pf_res["solution"]

    for (b,bus) in pf_sol["bus"]
        bus["vmn2"] = []
        for t in math["bus"][b]["terminals"]
            push!(bus["vmn2"], (bus["vr"][t])^2 + (bus["vi"][t])^2)
        end
        bus["vmn"] = sqrt.(bus["vmn2"])
    end 

    for (l, load) in math["load"]
    if load["configuration"] == _PMD.DELTA
        pf_sol["load"][l]["ptot"] = [sum(pf_sol["load"][l]["pd"])]
        pf_sol["load"][l]["qtot"] = [sum(pf_sol["load"][l]["qd"])]

        load_bus = pf_sol["bus"][string(load["load_bus"])]
        load_bus["vll"] = sqrt.([ (load_bus["vr"][x] - load_bus["vr"][y] )^2 + (load_bus["vi"][x] - load_bus["vi"][y] )^2 for (x,y) in [(1,2), (2,3), (3,1)]])
        end
    end

    PF_msr_path_SM_ind_Models = joinpath(mktempdir(),"PF_msr_path_IndustrialENMeasurementsModel.csv")
    _PMDSE.write_measurements!(_PMDSE.IndustrialENMeasurementsModel, math, pf_res, PF_msr_path_SM_ind_Models, σ=0.005) 
    _PMDSE.add_measurements!(math, PF_msr_path_SM_ind_Models, actual_meas = true)    

    math["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1);
    SE= _PMDSE.solve_mc_se(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
    se_sol = SE["solution"]

    @test isapprox(SE["objective"], 0.0; atol = 1e-4)

end




@testset "Explicit Neutral Models" begin
    
    PF_msr_path_en = joinpath(mktempdir(),"PF_msr_path_en.csv")

    @testset "IVR measurements - Single Phase Y Load - Constant Power" begin
       # dss_file_name = "3bus_4wire.dss"      
        dss_file_name = "test_load_3ph_wye_cp.dss"      
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMD.IVRENPowerModel) 
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    @testset "IVR measurements - Single Phase Δ Load - Constant Power" begin
        dss_file_name = "test_load_1ph_delta_cp.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMD.IVRENPowerModel)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end
    
    @testset "IVR measurements - Single Phase Y Load - Constant Impedance" begin
        dss_file_name = "test_load_3ph_delta_cz.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMD.IVRENPowerModel)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    @testset "SM_ind_en measurements - Single Phase Y Load - Constant Power" begin
        dss_file_name = "test_load_1ph_wye_cp.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMDSE.IndustrialENMeasurementsModel)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    @testset "SM_ind_en measurements - Single Phase Δ Load - Constant Power" begin
        dss_file_name = "test_load_1ph_delta_cp.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMDSE.IndustrialENMeasurementsModel)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    @testset "SM_ind_en measurements - Three Phase Δ Load - Constant Power" begin
        dss_file_name = "test_load_3ph_delta_cp.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMDSE.IndustrialENMeasurementsModel)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    

end


