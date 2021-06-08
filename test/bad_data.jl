const stored_H_matrix = [0.0             0.0            0.0        0.0  -0.664049  0.0        0.0              0.0              0.0       0.651214  0.0  -0.371397  0.0       0.0             0.0             0.0         0.371397;
0.0             0.0            0.0        0.0  -0.378661  0.0        0.0              0.0              0.0       0.373093  0.0   0.65131   0.0       0.0             0.0             0.0        -0.65131;
177199.0         -3615.93      -12555.6        0.0   0.0       0.0  -177199.0           3615.93         12555.6       0.0       0.0   0.0       0.0      -6.36329e5  -16517.6         11377.4         0.0;
-12555.6        177199.0        -3615.93       0.0   0.0       0.0    12555.6        -177199.0           3615.93      0.0       0.0   0.0       0.0   11377.4            -6.36329e5  -16517.6         0.0;
-3615.93       -12555.6       177199.0        0.0   0.0       0.0     3615.93         12555.6        -177199.0       0.0       0.0   0.0       0.0  -16517.6         11377.4            -6.36329e5   0.0;
6.38949e5   16585.6       -11424.2        0.0   0.0       0.0       -6.38949e5   -16585.6          11424.3       0.0       0.0   0.0       0.0       1.76472e5   -3601.11       -12504.1         0.0;
-11424.2             6.3895e5   16585.6        0.0   0.0       0.0    11424.2             -6.38948e5   -16585.6       0.0       0.0   0.0       0.0  -12504.2             1.76476e5   -3601.02        0.0;
16585.6        -11424.4            6.38948e5  0.0   0.0       0.0   -16585.6          11424.3             -6.3895e5  0.0       0.0   0.0       0.0   -3601.19       -12504.0             1.76469e5   0.0;
1.0             0.0            0.0        0.0   0.0       0.0        0.0              0.0              0.0       0.0       0.0   0.0       0.0       0.0             0.0             0.0         0.0;
0.0             1.0            0.0        0.0   0.0       0.0        0.0              0.0              0.0       0.0       0.0   0.0       0.0       0.0             0.0             0.0         0.0;
0.0             0.0            1.0        0.0   0.0       0.0        0.0              0.0              0.0       0.0       0.0   0.0       0.0       0.0             0.0             0.0         0.0;
0.0             0.0            0.0        0.0   0.0       0.0        0.0              0.0              0.0       1.0       0.0   0.0       0.0       0.0             0.0             0.0         0.0]





ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer,"max_cpu_time"=>300.0,
                                                              "tol"=>1e-8,
                                                              "print_level"=>0)

ntw, fdr = 4, 2

season     = "summer"
time_step  = 144
elm        = ["load", "pv"]
pfs        = [0.95, 0.90]
rm_transfo = true
rd_lines   = true

msr_path = joinpath(mktempdir(),"temp.csv")

include(raw"C:\Users\mvanin\.julia\dev\PowerModelsDistributionStateEstimation\src\bad_data\chi_squares_test.jl")

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

# write measurements based on power flow
_PMDSE.write_measurements!(_PMD.ACPUPowerModel, data, pf_result, msr_path, exclude = ["vr","vi"])

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

exceeds_chi_squares_threshold(se_result, data; prob_false=0.05, criterion=crit, rescaler = rsc)

@testset "h_function" begin

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
    # push h functions
    functions = []
    variable_dict = build_variable_dictionary(data)
    ref_bus = 4
    add_h_function!(:pd, "4", data, ref_bus, variable_dict, functions)
    add_h_function!(:qd, "5", data, ref_bus, variable_dict, functions)
    add_h_function!(:pg, "1", data, ref_bus, variable_dict, functions)
    add_h_function!(:qg, "2", data, ref_bus, variable_dict, functions)
    add_h_function!(:vm, "3", data, ref_bus, variable_dict, functions)
    add_h_function!(:vm, "6", data, ref_bus, variable_dict, functions)

    @test isapprox( functions[1](state), -_DST.mean(data["meas"]["4"]["dst"][1]) )
    @test isapprox( functions[2](state), -_DST.mean(data["meas"]["5"]["dst"][1]) )
    @test isapprox( functions[3](state), pf_result["solution"]["gen"]["1"]["pg"][1], atol=1e-8 )
    @test isapprox( functions[4](state), pf_result["solution"]["gen"]["1"]["pg"][2] )
    @test isapprox( functions[5](state), pf_result["solution"]["gen"]["1"]["pg"][3] )
    @test isapprox( functions[6](state), pf_result["solution"]["gen"]["1"]["qg"][1] )
    @test isapprox( functions[7](state), pf_result["solution"]["gen"]["1"]["qg"][2] )
    @test isapprox( functions[8](state), pf_result["solution"]["gen"]["1"]["qg"][3] )
    @test isapprox( functions[9](state), pf_result["solution"]["bus"]["4"]["vm"][1] )
    @test isapprox( functions[10](state), pf_result["solution"]["bus"]["4"]["vm"][2] )
    @test isapprox( functions[11](state), pf_result["solution"]["bus"]["4"]["vm"][3] )
    @test isapprox( functions[12](state), pf_result["solution"]["bus"]["3"]["vm"][1] )

    H = build_H_matrix(functions, state)
    @test all(isapprox.(H, stored_H_matrix, atol=1)

    add_measurement!(data, :p, :branch, 1, pf_result["solution"]["branch"]["1"]["pt"], [0.0003])
    add_measurement!(data, :q, :branch, 3, pf_result["solution"]["branch"]["3"]["qf"], [0.0003, 0.0003, 0.0003])
    add_h_function!(:p, "7", data, ref_bus, variable_dict, functions)
    add_h_function!(:q, "8", data, ref_bus, variable_dict, functions)
    
    @test( isapprox(functions[13](state)), pf_result["solution"]["branch"]["1"]["pt"][1])
    @test( isapprox(functions[14](state)), pf_result["solution"]["branch"]["3"]["qf"][1])
    @test( isapprox(functions[15](state)), pf_result["solution"]["branch"]["3"]["qf"][2])
    @test( isapprox(functions[16](state)), pf_result["solution"]["branch"]["3"]["qf"][3])
end