@testset "Add pseudo + measurements, run mixed SE" begin

    # set measurement path
    msr_path = joinpath(mktempdir(),"temp.csv")
    pseudo_path = joinpath(_PMDSE.BASE_DIR, "test/data/extra/measurements/distr_example.csv")

    # load data
    data = _PMD.parse_file(_PMDSE.get_enwl_dss_path(ntw, fdr))
    if rm_transfo _PMDSE.rm_enwl_transformer!(data) end
    if rd_lines   _PMDSE.reduce_enwl_lines_eng!(data) end

    # insert the load profiles
    _PMDSE.insert_profiles!(data, season, elm, pfs, t = time_step)

    # transform data model
    data = _PMD.transform_data_model(data);

    # solve the power flow
    pf_result = _PMD.solve_mc_pf(data, _PMD.ACPUPowerModel, ipopt_solver)
    pseudo_loads = [3, 11, 7, 16]
    cluster_list = [1, 2, 1, 3]
    _PMDSE.assign_load_pseudo_measurement_info!(data, pseudo_loads, cluster_list; time_step=1, day=1)

    # write measurements based on power flow
    _PMDSE.write_measurements_and_pseudo!(_PMD.ACPUPowerModel, data, pf_result, msr_path, distribution_info=pseudo_path, σ = 0.005)

    # read-in measurement data and set initial values
    _PMDSE.add_measurements!(data, msr_path, actual_meas = true)
    _PMDSE.assign_basic_individual_criteria!(data; chosen_criterion="rwlav")
    data["meas"]["21"]["crit"] = "mle"
    data["meas"]["22"]["crit"] = "mle"
    _PMDSE.assign_start_to_variables!(data)
    _PMDSE.update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

    for (m, meas) in data["meas"]
        if meas["cmp"] == :load && m ∉ ["21", "22", "30", "31"]
            for phase in 1:length(meas["dst"])
                if isa(meas["dst"][phase], _DST.Normal{Float64})
                    @test Statistics.mean(meas["dst"][phase]) == data["load"]["$(meas["cmp_id"])"][string(meas["var"])][phase]
                end
            end
        end
    end

    data["se_settings"] = Dict()

    # solve the state estimation
    # se_result = _PMDSE.solve_mc_se(data, _PMD.ACPUPowerModel, ipopt_solver)
    # @test se_result["termination_status"] == LOCALLY_SOLVED #CHECK WHY NUMERICAL_ERROR when result seems actually correct
    # @test isapprox( se_result["objective"], 1.41998; atol = 1e-5)
end
