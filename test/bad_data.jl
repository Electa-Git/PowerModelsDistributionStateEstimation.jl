@testset "chi-square-analysis" begin

    msr_path = joinpath(mktempdir(),"temp.csv")

    data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
    if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
    if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

    # insert the load profiles
    _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

    # transform data model
    data = _PMD.transform_data_model(data);
    _PMDSE.reduce_single_phase_loadbuses!(data)

    # solve the power flow
    pf_result = _PMD.solve_mc_pf(data, _PMD.ACPUPowerModel, ipopt_solver)

    key = "1" # or "sourcebus"
    v_pu = data["settings"]["vbases_default"][key]* data["settings"]["voltage_scale_factor"] # divider [V] to get the voltage in per units.
    v_max_err = 1.15 # maximum error of voltage measurement = 0.5% or 1.15 V
    σ_v = 1/3*v_max_err/v_pu

    p_pu = data["settings"]["sbase"] # divider [kW] to get the power in per units.
    p_max_err = 0.01 # maximum error of power measurement = 10W, or 0.01 kW
    σ_p = 1/3*p_max_err/p_pu

    # sigma_dict
    σ_dict = Dict("load" => Dict("load" => σ_p,
                                "bus"   => σ_v),
                "gen"  => Dict("gen" => σ_p,
                                "bus" => σ_v)
                )

    # write measurements based on power flow
    _PMDSE.write_measurements!(_PMD.ACPUPowerModel, data, pf_result, msr_path, exclude = ["vi","vr"], σ = σ_dict)

    # read-in measurement data and set initial values
    _PMDSE.add_measurements!(data, msr_path, actual_meas = false)

    rsc = 100
    crit = "rwls"

    data["se_settings"] = Dict{String,Any}("criterion" => crit, "rescaler" => rsc)
    se_result = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)

    @test _PMDSE.get_degrees_of_freedom(data) == 34
    
    chi_result = _PMDSE.exceeds_chi_squares_threshold(se_result, data; prob_false=0.05, criterion=crit, rescaler = rsc)
    @test isapprox(se_result["objective"], 0.120618, atol=1e-4)
    @test chi_result[1] == false
    @test isapprox(chi_result[2], 12.06, atol = 1e-2)
    @test isapprox(chi_result[3], 48.60, atol = 1e-2)
end

@testset "h_functions" begin

    # NB: the length (in terms of lines of code) of this sub-test could/should be significantly result but have no time now

    msr_path = joinpath(mktempdir(),"temp.csv")
    data = _PMD.parse_file(joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss"); data_model=MATHEMATICAL)
    #reduce grid
    [delete!(data["load"], l) for (l, load) in data["load"] if l!="1"]
    _PMDSE.reduce_single_phase_loadbuses!(data) 
    pf_result = _PMD.solve_mc_pf(data, _PMD.ACPUPowerModel, ipopt_solver)
    _PMDSE.write_measurements!(_PMD.ACPUPowerModel, data, pf_result, msr_path, exclude = ["vr","vi"])
    _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
    
    # state is the result of the power flow
    vv = pf_result["solution"]["bus"]
    state = [ vv["4"]["vm"][1], vv["4"]["vm"][2], vv["4"]["vm"][3], vv["1"]["vm"][1], vv["1"]["vm"][2], vv["1"]["vm"][3], vv["2"]["vm"][1], vv["2"]["vm"][2], vv["2"]["vm"][3], vv["3"]["vm"][1], 
             vv["1"]["va"][1], vv["1"]["va"][2], vv["1"]["va"][3], vv["2"]["va"][1], vv["2"]["va"][2], vv["2"]["va"][3], vv["3"]["va"][1] ]

    variable_dict = _PMDSE.build_variable_dictionary(data)
    state_array = _PMDSE.build_state_array(pf_result, variable_dict)
    @test state_array == state

    # push h functions
    functions = []
    ref_bus = 4
    _PMDSE.add_h_function!(:pd, "4", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:qd, "5", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:pg, "1", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:qg, "2", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:vm, "3", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:vm, "6", data, ref_bus, variable_dict, functions)

    @test isapprox( functions[1](state), -_DST.mean(data["meas"]["4"]["dst"][1]) ) #pd
    @test isapprox( functions[2](state), -_DST.mean(data["meas"]["5"]["dst"][1]) ) # qd
    @test isapprox( functions[3](state), pf_result["solution"]["gen"]["1"]["pg"][1], atol=1e-8 )
    @test isapprox( functions[4](state), pf_result["solution"]["gen"]["1"]["pg"][2], atol=1e-8 )
    @test isapprox( functions[5](state), pf_result["solution"]["gen"]["1"]["pg"][3], atol=1e-8 )
    @test isapprox( functions[6](state), pf_result["solution"]["gen"]["1"]["qg"][1], atol=1e-8  )
    @test isapprox( functions[7](state), pf_result["solution"]["gen"]["1"]["qg"][2], atol=1e-8  )
    @test isapprox( functions[8](state), pf_result["solution"]["gen"]["1"]["qg"][3], atol=1e-8  )
    @test isapprox( functions[9](state), pf_result["solution"]["bus"]["4"]["vm"][1] )
    @test isapprox( functions[10](state), pf_result["solution"]["bus"]["4"]["vm"][2] )
    @test isapprox( functions[11](state), pf_result["solution"]["bus"]["4"]["vm"][3] )
    @test isapprox( functions[12](state), pf_result["solution"]["bus"]["3"]["vm"][1] )

    _PMDSE.add_measurement!(data, :p, :branch, 1, pf_result["solution"]["branch"]["1"]["pt"], [0.0003])
    _PMDSE.add_measurement!(data, :q, :branch, 3, pf_result["solution"]["branch"]["3"]["qf"], [0.0003, 0.0003, 0.0003])
    _PMDSE.add_measurement!(data, :q, :branch, 1, pf_result["solution"]["branch"]["1"]["qf"], [0.0003])

    _PMDSE.add_h_function!(:p, "7", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:q, "8", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:q, "9", data, ref_bus, variable_dict, functions)

    cm3 = sqrt.(pf_result["solution"]["branch"]["3"]["pf"].^2+pf_result["solution"]["branch"]["3"]["qf"].^2)./(pf_result["solution"]["bus"]["4"]["vm"])
    cm1 = sqrt(pf_result["solution"]["branch"]["1"]["pf"][1]^2+pf_result["solution"]["branch"]["1"]["qf"][1]^2)/(pf_result["solution"]["bus"]["1"]["vm"][2])

    _PMDSE.add_measurement!(data, :cm, :branch, 3, cm3, [0.0003, 0.0003, 0.0003])
    _PMDSE.add_measurement!(data, :cm, :branch, 1, [cm1], [0.0003])
    _PMDSE.add_measurement!(data, :va, :bus, 2, pf_result["solution"]["bus"]["2"]["va"], [0.0003, 0.0003, 0.0003])
    _PMDSE.add_h_function!(:cm, "10", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:cm, "11", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:va, "12", data, ref_bus, variable_dict, functions)
    
    @test isapprox( functions[13](state), pf_result["solution"]["branch"]["1"]["pf"][1] )
    @test isapprox( functions[14](state), pf_result["solution"]["branch"]["3"]["qf"][1], atol=1e-8 )
    @test isapprox( functions[15](state), pf_result["solution"]["branch"]["3"]["qf"][2], atol=1e-8 )
    @test isapprox( functions[16](state), pf_result["solution"]["branch"]["3"]["qf"][3], atol=1e-8 )
    @test isapprox( functions[17](state), pf_result["solution"]["branch"]["1"]["qf"][1] )
    @test isapprox( functions[18](state), cm3[1] , atol=1e-8)
    @test isapprox( functions[19](state), cm3[2] , atol=1e-8)
    @test isapprox( functions[20](state), cm3[3], atol=1e-8 )
    @test isapprox( functions[21](state), cm1 )
    @test isapprox( functions[22](state), pf_result["solution"]["bus"]["2"]["va"][1])
    @test isapprox( functions[23](state), pf_result["solution"]["bus"]["2"]["va"][2])
    @test isapprox( functions[24](state), pf_result["solution"]["bus"]["2"]["va"][3])

    pf_result_ivr = _PMD.solve_mc_pf(data, _PMD.IVRUPowerModel, ipopt_solver)
    _PMDSE.add_measurement!(data, :cr, :branch, 3, pf_result_ivr["solution"]["branch"]["3"]["cr_fr"], [0.0003, 0.0003, 0.0003])
    _PMDSE.add_measurement!(data, :ci, :branch, 3, pf_result_ivr["solution"]["branch"]["3"]["ci_fr"], [0.0003, 0.0003, 0.0003])
    _PMDSE.add_measurement!(data, :crd, :branch, 1, pf_result_ivr["solution"]["load"]["1"]["crd_bus"], [0.0003])
    _PMDSE.add_measurement!(data, :cid, :branch, 1, pf_result_ivr["solution"]["load"]["1"]["cid_bus"], [0.0003])

    _PMDSE.add_h_function!(:cr, "13", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:ci, "14", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:crd, "15", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:cid, "16", data, ref_bus, variable_dict, functions)

    @test isapprox( functions[25](state), pf_result_ivr["solution"]["branch"]["3"]["cr_fr"][1], atol=1e-8)
    @test isapprox( functions[26](state), pf_result_ivr["solution"]["branch"]["3"]["cr_fr"][2], atol=4e-5)
    @test isapprox( functions[27](state), pf_result_ivr["solution"]["branch"]["3"]["cr_fr"][3], atol=1e-8)
    @test isapprox( functions[28](state), pf_result_ivr["solution"]["branch"]["3"]["ci_fr"][1], atol=1e-5)
    @test isapprox( functions[29](state), pf_result_ivr["solution"]["branch"]["3"]["ci_fr"][2], atol=2e-5)
    @test isapprox( functions[30](state), pf_result_ivr["solution"]["branch"]["3"]["ci_fr"][3], atol=2e-5)
    @test isapprox( functions[31](state), -pf_result_ivr["solution"]["load"]["1"]["crd_bus"][1], atol=2e-4)
    @test isapprox( functions[32](state), -pf_result_ivr["solution"]["load"]["1"]["cid_bus"][1], atol=2e-4)    

    _PMDSE.add_measurement!(data, :p, :branch, 2, pf_result["solution"]["branch"]["2"]["pf"], [0.0003, 0.0003, 0.0003])
    _PMDSE.add_measurement!(data, :q, :branch, 2, pf_result["solution"]["branch"]["2"]["qf"], [0.0003, 0.0003, 0.0003])
    _PMDSE.add_measurement!(data, :cr, :branch, 2, pf_result_ivr["solution"]["branch"]["2"]["cr_fr"], [0.0003, 0.0003, 0.0003])
    _PMDSE.add_measurement!(data, :ci, :branch, 2, pf_result_ivr["solution"]["branch"]["2"]["ci_fr"], [0.0003, 0.0003, 0.0003])
    cmfr = sqrt.(pf_result_ivr["solution"]["branch"]["2"]["cr_fr"].^2 + pf_result_ivr["solution"]["branch"]["2"]["ci_fr"].^2)
    _PMDSE.add_measurement!(data, :cm, :branch, 2, cmfr, [0.0003, 0.0003, 0.0003])

    _PMDSE.add_h_function!(:p, "17", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:q, "18", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:cr, "19", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:ci, "20", data, ref_bus, variable_dict, functions)
    _PMDSE.add_h_function!(:cm, "21", data, ref_bus, variable_dict, functions)

    @test isapprox( functions[33](state), pf_result["solution"]["branch"]["2"]["pf"][1], atol=1e-8)
    @test isapprox( functions[34](state), pf_result["solution"]["branch"]["2"]["pf"][2], atol=1e-8)
    @test isapprox( functions[35](state), pf_result["solution"]["branch"]["2"]["pf"][3], atol=1e-8)
    @test isapprox( functions[36](state), pf_result["solution"]["branch"]["2"]["qf"][1], atol=1e-8)
    @test isapprox( functions[37](state), pf_result["solution"]["branch"]["2"]["qf"][2], atol=1e-8)
    @test isapprox( functions[38](state), pf_result["solution"]["branch"]["2"]["qf"][3], atol=1e-8)
    @test isapprox( functions[39](state), pf_result_ivr["solution"]["branch"]["2"]["cr_fr"][1], atol=1e-4)
    @test isapprox( functions[40](state), pf_result_ivr["solution"]["branch"]["2"]["cr_fr"][2], atol=1e-4)    
    @test isapprox( functions[41](state), pf_result_ivr["solution"]["branch"]["2"]["cr_fr"][3], atol=1e-4)
    @test isapprox( functions[42](state), pf_result_ivr["solution"]["branch"]["2"]["ci_fr"][1], atol=1e-4)
    @test isapprox( functions[43](state), pf_result_ivr["solution"]["branch"]["2"]["ci_fr"][2], atol=1e-4)
    @test isapprox( functions[44](state), pf_result_ivr["solution"]["branch"]["2"]["ci_fr"][3], atol=1e-4)
    @test isapprox( functions[45](state), cmfr[1], atol=1e-6)
    @test isapprox( functions[46](state), cmfr[2], atol=1e-6)
    @test isapprox( functions[47](state), cmfr[3], atol=1e-6)

end

@testset "BadData_matrices_and_LNR" begin

    msr_path = joinpath(mktempdir(),"temp.csv")
    data = _PMD.parse_file(joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss"); data_model=MATHEMATICAL)
    #reduce grid
    [delete!(data["load"], l) for (l, load) in data["load"] if l!="1"]
    _PMDSE.reduce_single_phase_loadbuses!(data) 
    pf_result = _PMD.solve_mc_pf(data, _PMD.ACPUPowerModel, ipopt_solver)
    _PMDSE.write_measurements!(_PMD.ACPUPowerModel, data, pf_result, msr_path, exclude = ["vr","vi"])
    _PMDSE.add_measurements!(data, msr_path, actual_meas = true)

    data["se_settings"] = Dict{String,Any}("criterion" => "wls", "rescaler" => 1)
    se_result = _PMDSE.solve_acp_red_mc_se(data, ipopt_solver)
    
    _PMDSE.add_zib_virtual_meas!(data, 0.000001, exclude = [2])
    _PMDSE.add_zib_virtual_residuals!(se_result, data)

    variable_dict = _PMDSE.build_variable_dictionary(data)
    h_array = _PMDSE.build_measurement_function_array(data, variable_dict)
    state_array = _PMDSE.build_state_array(pf_result, variable_dict)

    stored_H_matrix = h5open(joinpath(BASE_DIR, "test/data/H_matrix.h5"), "r") do file
        read(file, "H")
    end

    stored_G_matrix = h5open(joinpath(BASE_DIR, "test/data/G_matrix.h5"), "r") do file
        read(file, "G")
    end

    stored_R_matrix = h5open(joinpath(BASE_DIR, "test/data/R_matrix.h5"), "r") do file
        read(file, "R")
    end

    stored_Ω_matrix = h5open(joinpath(BASE_DIR, "test\\data\\Ω_matrix.h5"), "r") do file
        read(file, "Ω")
    end

    H = _PMDSE.build_H_matrix(h_array, state_array)
    R = _PMDSE.build_R_matrix(data)
    G = _PMDSE.build_G_matrix(stored_H_matrix, R)
    Ω = _PMDSE.build_omega_matrix(R, stored_H_matrix, G)

    @test all(isapprox.(H, stored_H_matrix, atol=1))
    @test all(isapprox.(R, stored_R_matrix, atol=1))
    @test all(isapprox.(G, stored_G_matrix, atol=1))
    @test all(isapprox.(Ω, stored_Ω_matrix, atol=1))

    id_val, exc = _PMDSE.normalized_residuals(se_result, Ω)
    @test !exc
    @test id_val[1] == "3"
    @test isapprox(id_val[2], 0.11035175, atol=1e-8)

    _PMDSE.simple_normalized_residuals(data, se_result, "wls")
    @test haskey(se_result["solution"]["meas"]["5"], "norm_res")
end