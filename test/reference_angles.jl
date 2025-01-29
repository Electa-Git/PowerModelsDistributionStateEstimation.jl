@testset "Angular Reference Models" begin

    # set measurement path
    msr_path = joinpath(mktempdir(),"temp.csv")

    @testset "ACP-rwlav" begin
            
        # set model
        crit = "rwlav"
        model = _PMD.ACPUPowerModel

        # load data
        data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
        if rm_transfo _PMDSE.rm_enwl_transformer!(data) end


        # insert the load profiles
        #_PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

        # transform data model
        data = _PMD.transform_data_model(data);
        pf_result = _PMD.solve_mc_pf(data, model, ipopt_solver)
        _PMDSE.write_measurements!(model, data, pf_result, msr_path)
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)

        datarm = deepcopy(data)
        (virtual_bus, r_new) = _PMDSE.remove_virtual_bus!(datarm) # doesn't remove, but just returns the ids needed later


        for (m, meas) in data["meas"]
            if  meas["cmp"] == :bus && meas["cmp_id"] == parse(Int, virtual_bus) 
                meas["cmp_id"] = r_new 
                if meas["var"] == :vm
                    meas["dst"] = [_DST.Normal(vm_i, 0.00166667) for vm_i  in pf_result["solution"]["bus"]["$(r_new)"]["vm"]]
                end
            end
        end


        _PMDSE.assign_start_to_variables!(data)
        #_PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )
            
        # set se settings
        data["se_settings"] = Dict{String,Any}("criterion" => crit, "rescaler" => 100)


        # Test 1: State Estimation Approaches Feasibility and Low Objective 
        # Approach A

        math_a = deepcopy(data)
        (virtual_bus, r_new) = _PMDSE.remove_virtual_bus!(math_a) 
        math_a["bus"]["$(r_new)"]["va"] = deg2rad.([0, -120, 120])
        math_a["bus"]["$(r_new)"]["bus_type"] = 3
        SE_a = _PMDSE.solve_mc_se(math_a, model, ipopt_solver)
        
        @testset "State Estimation Approach A" begin
            @test isapprox(SE_a["objective"], 0.0; atol = 1e-4)
            @test SE_a["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
        end

        # Approach B
        math_b = deepcopy(data)
        (virtual_bus, r_new) = _PMDSE.remove_virtual_bus!(math_b) 
        Angles_bound = Inf 
        math_b["bus"]["$(r_new)"]["bus_type"] = 3
        math_b["bus"]["$(r_new)"]["vamax"] = deg2rad.([0.0, -120+Angles_bound, 120+Angles_bound])
        math_b["bus"]["$(r_new)"]["vamin"] = deg2rad.([0.0, -120-Angles_bound, 120-Angles_bound])
        SE_b = _PMDSE.solve_mc_se(math_b, model, ipopt_solver)

        @testset "State Estimation Approach B" begin
            @test isapprox(SE_b["objective"], 0.0; atol = 1e-6)
            @test SE_b["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
        end
    
        # Approach C
        math_c = deepcopy(data)
        SE_c = _PMDSE.solve_mc_se(math_c, model, ipopt_solver)
        
        @testset "State Estimation Approach C" begin
            @test isapprox(SE_c["objective"], 0.0; atol = 1e-6)
            @test SE_c["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
            delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(SE_c, pf_result)
            @test isapprox(max, 0.0; atol = 1e-6)
            @test isapprox(avg, 0.0; atol = 1e-8)
        end
   end


    @testset "IVR-rwlav" begin

        #3 WIRES
        PF_msr_path = joinpath(mktempdir(),"PF_msr_path.csv")
        σ_3w = 0.05
        dss_file_name = "3bus_3wire.dss"      
        
        eng = _PMD.parse_file(joinpath(_PMDSE.BASE_DIR, "test", "data", "three-bus-en-models", dss_file_name))
        _PMD.remove_all_bounds!(eng)
        math = _PMD.transform_data_model(eng)
        _PMD.add_start_vrvi!(math)
        
        #PF_RES = solve_mc_pf(math, PowerModelsDistribution.IVRUPowerModel, Ipopt.Optimizer)
        PF_RES = _PMD.solve_mc_opf(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
        pf_sol = PF_RES["solution"]
        
        _PMDSE.write_measurements!(_PMD.IVRUPowerModel, math, PF_RES, PF_msr_path, σ= σ_3w)
        _PMDSE.add_measurements!(math, PF_msr_path, actual_meas = true)   
        
        math["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1);
        SE= _PMDSE.solve_mc_se(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
        se_sol = SE["solution"]
        
        
        @test SE["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
        @test isapprox( atan.(pf_sol["bus"]["3"]["vi"],pf_sol["bus"]["3"]["vr"]), atan.(se_sol["bus"]["3"]["vi"],se_sol["bus"]["3"]["vr"])  ;atol= 1e-4)
        
        
        
        eng = _PMD.parse_file(joinpath(_PMDSE.BASE_DIR, "test", "data", "three-bus-en-models", dss_file_name))
        _PMD.remove_all_bounds!(eng)
        math = _PMD.transform_data_model(eng)
        _PMD.add_start_vrvi!(math)
        
        math["bus"]["3"]["vamax"] = deg2rad.([0.0, -119, 119.15])
        math["bus"]["3"]["vamin"] =  deg2rad.([0.0, -120.3833, 119.15])
        
        #PF_RES = solve_mc_pf(math, PowerModelsDistribution.IVRUPowerModel, Ipopt.Optimizer)
        PF_RES = _PMD.solve_mc_opf(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
        pf_sol = PF_RES["solution"]
        
        _PMDSE.write_measurements!(_PMD.IVRUPowerModel, math, PF_RES, PF_msr_path, σ= σ_3w)
        _PMDSE.add_measurements!(math, PF_msr_path, actual_meas = true)   
        
        math["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1);
        SE= _PMDSE.solve_mc_se(math, _PMD.IVRUPowerModel, Ipopt.Optimizer)
        se_sol = SE["solution"]
        
        atan.(pf_sol["bus"]["3"]["vi"],pf_sol["bus"]["3"]["vr"])
        

        @test isapprox(atan.(se_sol["bus"]["3"]["vi"],se_sol["bus"]["3"]["vr"]), deg2rad.([0.0, -120.3833, 119.15])  ;atol= 1e-4)
        
        @test SE["termination_status"] ∈ [_PMDSE.LOCALLY_SOLVED, _PMDSE.ALMOST_LOCALLY_SOLVED]
    end
        



end


