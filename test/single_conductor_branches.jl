@testset "single_conductor_network" begin
    model = _PMD.ACPUPowerModel
    msr_path = joinpath(mktempdir(),"temp.csv")
    pm_path = joinpath(dirname(pathof(PowerModels)), "..")
    case5 = PowerModels.parse_file("$(pm_path)/test/data/matpower/case5.m"); _PMD.make_multiconductor!(case5, 3)
    
    for (g, gen) in case5["gen"]
        if g != "4" #this is the generator at the reference bus 
            delete!(case5["gen"], g) 
        end 
    end
    
    for (b, bus) in case5["bus"]
        if b ∉ ["4", "10"] 
            delete!(case5["bus"], b) 
        end 
    end
    
    for (b, branch) in case5["branch"]
        if b != "7" 
            delete!(case5["branch"], b) 
        end 
    end
    
    case5["bus"]["10"]["bus_type"] = 1
    case5["load"]["3"]["load_bus"] = 10
    
    for (l, load) in case5["load"]
        if l != "3" 
            delete!(case5["load"], l) 
        end 
    end
    
    case5["branch"]["7"]["b_to"] = case5["branch"]["7"]["b_fr"] = reshape(repeat([0.0], 9), 3, 3) 
    case5["load"]["3"]["connections"] = [1]
    case5["load"]["3"]["pd"] = [3.0]
    case5["load"]["3"]["qd"] = [1.3147]

    pf_result = _PMD.run_mc_pf(case5, model, ipopt_solver)
    _PMDSE.write_measurements!(_PMD.ACPUPowerModel, case5, pf_result, msr_path, exclude = ["vi","vr"])
    _PMDSE.add_measurements!(case5, msr_path, actual_meas = true)
    _PMDSE.add_voltage_measurement!(case5, pf_result, 0.0005)
    
    case5["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1)
    
    # solve the state estimation
    se_result = _PMDSE.solve_mc_se(case5, model, ipopt_solver)
    
end #testset