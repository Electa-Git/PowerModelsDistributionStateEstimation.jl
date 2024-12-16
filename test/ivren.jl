

function run_en_model(dss_file_name, PF_msr_path_en, measures_type; σ_en=0.005)
    eng_en = _PMD.parse_file(joinpath(_PMDSE.BASE_DIR, "test", "data", "three-bus-en-models", dss_file_name))
    _PMD.transform_loops!(eng_en)
    _PMD.remove_all_bounds!(eng_en)
    math_en = _PMD.transform_data_model(eng_en, kron_reduce=false, phase_project=false)
    _PMD.add_start_vrvi!(math_en)
    PF_RES_en = _PMD.solve_mc_opf(math_en, _PMD.IVRENPowerModel, Ipopt.Optimizer)
    pf_sol_en = PF_RES_en["solution"]

    if measures_type == _PMD.IVRENPowerModel
        _PMDSE.write_measurements!(measures_type, math_en, PF_RES_en, PF_msr_path_en, σ=σ_en)
        _PMDSE.add_measurements!(math_en, PF_msr_path_en, actual_meas=true)
    elseif measures_type == _PMDSE.SM_ind_en_Models
        math_meas = deepcopy(math_en)

        for (b,bus) in pf_sol_en["bus"]
            bus["vmn2"] = []
            for t in setdiff(math_en["bus"][b]["terminals"],[4])
                push!(bus["vmn2"], (bus["vr"][t] - bus["vr"][4])^2 + (bus["vi"][t] - bus["vi"][4])^2)
            end
            bus["vmn"] = sqrt.(bus["vmn2"])
        math_meas["bus"][b]["terminals"] = setdiff(math_en["bus"][b]["terminals"], 4)
        end 

        for (l, load) in math_en["load"]
        if load["configuration"] == _PMD.DELTA
            pf_sol_en["load"][l]["ptot"] = [sum(pf_sol_en["load"][l]["pd"])]
            pf_sol_en["load"][l]["qtot"] = [sum(pf_sol_en["load"][l]["qd"])]

            load_bus = pf_sol_en["bus"][string(load["load_bus"])]
            load_bus["vll"] = sqrt.([ (load_bus["vr"][x] - load_bus["vr"][y] )^2 + (load_bus["vi"][x] - load_bus["vi"][y] )^2 for (x,y) in [(1,2), (2,3), (3,1)]])
            end
        end

        PF_msr_path_SM_ind_en_Models = joinpath(mktempdir(),"PF_msr_path_SM_ind_en_Models.csv")
        _PMDSE.write_measurements!(measures_type, math_meas, PF_RES_en, PF_msr_path_SM_ind_en_Models, σ=σ_en) 
        _PMDSE.add_measurements!(math_en, PF_msr_path_SM_ind_en_Models, actual_meas = true)  
    else
        error("Measures type $measures_type not recognized")
    end

    math_en["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1)
    slv = _PMDSE.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-8, "print_level"=>5)
    #SE_en = _PMDSE.solve_mc_se(math_en, _PMD.IVRENPowerModel, slv)
    SE_en = _PMDSE.solve_ivr_en_mc_se(math_en, slv)

    return SE_en
end



@testset "IVR three-wire model" begin    
    #3 WIRES MODEL to check nothing broke there when implementing four-wire models
    PF_msr_path = joinpath(mktempdir(),"PF_msr_path.csv")
    σ_3w = 0.05
    dss_file_name = "3bus_3wire.dss"      

    eng = _PMD.parse_file(joinpath(_PMDSE.BASE_DIR, "test", "data", "three-bus-en-models", dss_file_name))
    #eng = _PMD.parse_file("3bus_3wire_delta_single.dss")
    _PMD.remove_all_bounds!(eng)
    math = _PMD.transform_data_model(eng)
    _PMD.add_start_vrvi!(math)

    # math["bus"]["3"]["vamax"] = deg2rad.([0.0, -119, 119.15])
    # math["bus"]["3"]["vamin"] = deg2rad.([0.0, -120.55, 119.0])

    #PF_RES = solve_mc_pf(math, PowerModelsDistribution.IVRUPowerModel, Ipopt.Optimizer)
    PF_RES = _PMD.solve_mc_opf(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
    pf_sol = PF_RES["solution"]


    _PMDSE.write_measurements!(_PMD.IVRUPowerModel, math, PF_RES, PF_msr_path, σ= σ_3w)
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

    PF_RES = _PMD.solve_mc_opf(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
    pf_sol = PF_RES["solution"]

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

    PF_msr_path_SM_ind_Models = joinpath(mktempdir(),"PF_msr_path_SM_ind_en_Models.csv")
    _PMDSE.write_measurements!(_PMDSE.SM_ind_en_Models, math, PF_RES, PF_msr_path_SM_ind_Models, σ=0.005) 
    _PMDSE.add_measurements!(math, PF_msr_path_SM_ind_Models, actual_meas = true)    

    math["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1);
    SE= _PMDSE.solve_mc_se(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
    se_sol = SE["solution"]

    @test isapprox(SE["objective"], 0.0; atol = 1e-4)

end




@testset "Explicit Neutral Models" begin
    
    PF_msr_path_en = joinpath(mktempdir(),"PF_msr_path_en.csv")

    @testset "IVR measurements - Single Phase Y Load - Constant Power" begin
        dss_file_name = "3bus_4wire.dss"      
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMD.IVRENPowerModel) 
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    @testset "IVR measurements - Single Phase Δ Load - Constant Power" begin
        dss_file_name = "3bus_4wire_delta_cp.dss"
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
        dss_file_name = "3bus_4wire.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMDSE.SM_ind_en_Models)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    @testset "SM_ind_en measurements - Single Phase Δ Load - Constant Power" begin
        dss_file_name = "3bus_4wire_delta_cp.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMDSE.SM_ind_en_Models)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end
    
    @testset "SM_ind_en measurements - Single Phase Y Load - Constant Impedance" begin
        dss_file_name = "test_load_3ph_delta_cz.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMDSE.SM_ind_en_Models)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    @testset "SM_ind_en measurements - Three Phase Δ Load - Constant Power" begin
        dss_file_name = "test_load_3ph_delta_cp.dss"
        SE_en = run_en_model(dss_file_name, PF_msr_path_en,_PMDSE.SM_ind_en_Models)
        @test isapprox(SE_en["objective"], 0.0; atol = 1e-4)
        @test SE_en["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end

    

end
