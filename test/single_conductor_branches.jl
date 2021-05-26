@testset "test cases where some connections have less than 3 conductors" begin

    @testset "single_conductor_network_matpower" begin

        model = _PMD.ACPUPowerModel
        msr_path = joinpath(mktempdir(),"temp.csv")
        pm_path = joinpath(dirname(pathof(PowerModels)), "..")
        case5 = PowerModels.parse_file("$(pm_path)/test/data/matpower/case5.m"); _PMD.make_multiconductor!(case5, 1)
        
        # case5 below is simplified for ease of debugging and because the data contains indications that lead to 
        # sophisticated power flow calculations, whose results cannot be translated into a digestible state estimation
        # input with the current default measurement parser

        for (g, gen) in case5["gen"]
            if g ∉ ["4"] #this is the generator at the reference bus. allow just one generator to avoid the `bus = 2` inconvenient, at the moment
                delete!(case5["gen"], g) 
            else
                gen["pmax"] = [Inf]
                gen["qmax"] = [Inf]
                gen["pmin"] = [-Inf]
                gen["qmin"] = [-Inf]
            end
        end
        
        for (b, bus) in case5["bus"]
            if bus["bus_type"] == 2
                bus["bus_type"] = 1
            end
            bus["vmin"] = [0.0]
            bus["vmax"] = [Inf]
        end
        
        for (b, branch) in case5["branch"]
            branch["rate_a"] = branch["rate_b"] = branch["rate_c"] = [Inf] 
            if b ∈ ["5", "6"] 
                delete!(case5["branch"], b) 
            end 
        end
        
        pf_result = _PMD.run_mc_pf(case5, model, ipopt_solver)
        _PMDSE.write_measurements!(_PMD.ACPUPowerModel, case5, pf_result, msr_path, exclude = ["vi","vr"])
        _PMDSE.add_measurements!(case5, msr_path, actual_meas = true)
        _PMDSE.add_voltage_measurement!(case5, pf_result, 0.0005)
        
        case5["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1)
        
        # solve the state estimation
        se_result = _PMDSE.solve_mc_se(case5, model, ipopt_solver)

        @test pf_result["termination_status"] == LOCALLY_SOLVED
        @test se_result["termination_status"] == LOCALLY_SOLVED
        @test isapprox(se_result["objective"], 0.0; atol = 2e-7)
        
    end #testset

    @testset "three-phase_network_reduced" begin

        data = _PMD.parse_file(joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss"); data_model=MATHEMATICAL)
        delete!(data["load"], "2")
        delete!(data["load"], "3")
        reduce_single_phase_loadbuses!(data, exclude = []) #after this, all buses have 3 terminals except bus 3. All branches have 3 connections except branch 1. Thus, dimensions are reduced.
        pf_result= _PMD.run_mc_pf(data, _PMD.ACPUPowerModel, ipopt_solver)
        msr_path = joinpath(mktempdir(),"temp.csv")
        _PMDSE.write_measurements!(_PMD.ACPUPowerModel, data, pf_result, msr_path, exclude = ["vr","vi"])
        _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
        data["se_settings"] = Dict{String,Any}("criterion" => "rwlav",
                                "rescaler" => 1)
        se_result = _PMDSE.solve_mc_se(data, _PMD.ACPUPowerModel, ipopt_solver)
        delta, max, avg = _PMDSE.calculate_voltage_magnitude_error(se_result, pf_result)
        @test isapprox(max, 0.0; atol = 1e-6)
        @test isapprox(avg, 0.0; atol = 1e-8)

    end

end