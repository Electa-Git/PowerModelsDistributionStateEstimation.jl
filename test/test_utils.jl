function run_en_model(dss_file_name, PF_msr_path_en, measures_type; σ_en=0.005)
    
    eng_en = _PMD.parse_file(joinpath(dirname(pathof(_PMD)),"..", "test", "data", "en_validation_case_data", dss_file_name))
    
    
    
    _PMD.transform_loops!(eng_en)
    _PMD.remove_all_bounds!(eng_en)
    math_en = _PMD.transform_data_model(eng_en, kron_reduce=false, phase_project=false)
    _PMD.add_start_vrvi!(math_en)
    PF_RES_en = _PMD.solve_mc_opf(math_en, _PMD.IVRENPowerModel, Ipopt.Optimizer)
    pf_sol_en = PF_RES_en["solution"]

    if measures_type == _PMD.IVRENPowerModel
        _PMDSE.write_measurements!(measures_type, math_en, PF_RES_en, PF_msr_path_en, σ=σ_en)
        _PMDSE.add_measurements!(math_en, PF_msr_path_en, actual_meas=true)
    elseif measures_type == _PMDSE.IndustrialENMeasurementsModel
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

        PF_msr_path_IndustrialENMeasurementsModel = joinpath(mktempdir(),"PF_msr_path_IndustrialENMeasurementsModel.csv")
        _PMDSE.write_measurements!(measures_type, math_meas, PF_RES_en, PF_msr_path_IndustrialENMeasurementsModel, σ=σ_en) 
        _PMDSE.add_measurements!(math_en, PF_msr_path_IndustrialENMeasurementsModel, actual_meas = true)  
    else
        error("Measures type $measures_type not recognized")
    end

    math_en["se_settings"] = Dict{String,Any}("criterion" => "rwlav", "rescaler" => 1)
    slv = _PMDSE.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-8, "print_level"=>5)
    SE_en = _PMDSE.solve_ivr_en_mc_se(math_en, slv)

    return SE_en
end