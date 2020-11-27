@testset "Add pseudo+measurements, run mixed SE" begin

    # set measurement path
    msr_path = joinpath(mktempdir(),"temp.csv")
    pseudo_path = joinpath(BASE_DIR, "test/data/extra/measurements/distr_example.csv")

    crit = "mixed"
    model = _PMs.ACPPowerModel

    # load data
    data = _PMD.parse_file(.get_enwl_dss_path(ntw, fdr))
    if rm_transfo .rm_enwl_transformer!(data) end
    if rd_lines   .reduce_enwl_lines_eng!(data) end

    # insert the load profiles
    .insert_profiles!(data, season, elm, pfs, t = time)

    # transform data model
    data = _PMD.transform_data_model(data);

    # solve the power flow
    pf_result = _PMD.run_mc_pf(data, _PMs.ACPPowerModel, ipopt_solver)
    pseudo_loads = [3, 11, 7, 16]
    cluster_list = [1, 2, 1, 3]
    .assign_load_pseudo_measurement_info!(data, pseudo_loads, cluster_list; time_step=1, day=1)

    # write measurements based on power flow
    .write_measurements_and_pseudo!(_PMs.ACPPowerModel, data, pf_result, msr_path, distribution_info=pseudo_path, σ = 0.005)

    # read-in measurement data and set initial values
    .add_measurements!(data, msr_path, actual_meas = true)
    .assign_default_individual_criterion!(data; chosen_criterion="rwlav")
    data["meas"]["21"]["crit"] = "mle"
    data["meas"]["22"]["crit"] = "mle"
    .assign_start_to_variables!(data)
    .update_all_bounds!(data; v_min = 0.8, v_max = 1.2, pg_min=-1.0, pg_max = 1.0, qg_min=-1.0, qg_max=1.0, pd_min=-1.0, pd_max=1.0, qd_min=-1.0, qd_max=1.0 )

    for (m, meas) in data["meas"]
        if meas["cmp"] == :load && m ∉ ["21", "22"]
            for phase in 1:length(meas["dst"])
                if typeof(meas["dst"][phase]) == _DST.Normal{Float64}
                    @test mean(meas["dst"][phase]) == data["load"]["$(meas["cmp_id"])"][string(meas["var"])][phase]
                end
            end
        end
    end

    # set se settings
    data["se_settings"] = Dict{String,Any}("criterion" => crit,
                                       "rescaler" => 1)

    # solve the state estimation
    se_result = .run_mc_se(data, _PMs.ACPPowerModel, ipopt_solver)
    @test se_result["termination_status"] == LOCALLY_SOLVED
    @test isapprox( se_result["objective"], 0.215375; atol = 1e-6)
end
