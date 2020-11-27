################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
"""
    get_cmp_id(pm, nw, i)
Retrieves the id of component i. This is a tuple if the component is a branch. Otherwise, it is a singleton.
"""
function get_cmp_id(pm, nw, i)
    if  _PMD.ref(pm, nw, :meas, i, "cmp") == :branch
        branch_id = _PMs.ref(pm, nw, :meas, i, "cmp_id")
        cmp_id = (branch_id, _PMD.ref(pm,nw,:branch, branch_id)["f_bus"], _PMD.ref(pm,nw,:branch,branch_id)["t_bus"])
    else
        cmp_id = _PMs.ref(pm, nw, :meas, i, "cmp_id")
    end
    return cmp_id
end
"""
    update_voltage_bounds!(data; v_min, v_max)
Function that allows to automatically set upper (v_max) and lower (v_min) voltage bounds for all buses.
"""
function update_voltage_bounds!(data::Dict; v_min::Float64=0.0, v_max::Float64=Inf)
    for (_,bus) in data["bus"]
        bus["vmin"] = [v_min, v_min, v_min]
        bus["vmax"] = [v_max, v_max, v_max]
    end
end
"""
    update_generator_bounds!(data; p_min, p_max, q_min, q_max)
Function that allows to automatically set upper (p_max, q_max) and lower (p_min, q_min) active and reactive power bounds for all generators.
"""
function update_generator_bounds!(data::Dict; p_min::Float64=0.0, p_max::Float64=Inf, q_min::Float64=-Inf, q_max::Float64=Inf)
    for (_,gen) in data["gen"]
        gen["pmin"] = [p_min, p_min, p_min]
        gen["pmax"] = [p_max, p_max, p_max]
        gen["qmin"] = [q_min, q_min, q_min]
        gen["qmax"] = [q_max, q_max, q_max]
    end
end
"""
    update_load_bounds!(data; p_min, p_max, q_min, q_max)
Function that allows to automatically set upper (p_max, q_max) and lower (p_min, q_min) active and reactive power bounds for all loads.
"""
function update_load_bounds!(data::Dict; p_min::Float64=0.0, p_max::Float64=Inf, q_min::Float64=-Inf, q_max::Float64=Inf)
    for (_,load) in data["load"]
        load["pmin"] = [p_min, p_min, p_min]
        load["pmax"] = [p_max, p_max, p_max]
        load["qmin"] = [q_min, q_min, q_min]
        load["qmax"] = [q_max, q_max, q_max]
    end
end
"""
    update_all_bounds!(data; v_min, v_max, pg_min, pg_max, qg_min, qg_max, pd_min, pd_max, qd_min, qd_max)
Function that combines `update_voltage_bounds!`, `update_generator_bounds!` and `update_load_bounds!` and assigns bounds to all bus voltages and load and generator power.
"""
function update_all_bounds!(data::Dict; v_min::Float64=0.0, v_max::Float64=Inf, pg_min::Float64=0.0, pg_max::Float64=Inf, qg_min::Float64=-Inf, qg_max::Float64=Inf, pd_min::Float64=0.0, pd_max::Float64=Inf, qd_min::Float64=-Inf, qd_max::Float64=Inf)
    update_voltage_bounds!(data; v_min=v_min, v_max=v_max)
    update_generator_bounds!(data; p_min=pg_min, p_max=pg_max, q_min=qg_min, q_max=qg_max)
    update_load_bounds!(data; p_min=pd_min, p_max=pd_max, q_min=qd_min, q_max=qd_max)
end
"""
    assign_individual_measurement_criterion!(data::Dict; chosen_criterion::String="rwlav")
Basic function that assigns a chosen criterion to individual measurements to perform a 'mixed' state estimation.
If the distribution type of at least one of the measured phases is normal, the criterion defaults to the chosen_criterion. Otherwise,
it is assigned the 'mle' criterion.
The function takes as input either a single measurement dictionary, e.g., data["meas"]["1"]
or the full ENGINEERING data model of the feeder.
"""
function assign_default_individual_criterion!(data::Dict; chosen_criterion::String="rwlav")
    if haskey(data, "meas")
        for (_, meas) in data["meas"]
            dst_type = [typeof(i) for i in meas["dst"]]
            if any(x->x==Distributions.Normal{Float64}, dst_type)
                meas["crit"] = chosen_criterion
            else
                meas["crit"] = "mle"
            end
        end
    elseif haskey(data, "dst")
        dst_type = [typeof(i) for i in data["dst"]]
        if any(x->x==Distributions.Normal{Float64}, dst_type)
            data["crit"] = chosen_criterion
        else
            data["crit"] = "mle"
        end
    else
        Memento.error(_LOGGER, "Unrecognized data input.")
    end
end
"""
    assign_residual_ub!(data::Dict; chosen_upper_bound::Float64=100, rescale::Bool=false)
Basic function that assigns upper bounds to the residual variables, by adding a `"res_max"` entry to the measurement dictionary.
The function takes as input either a single measurement dictionary, e.g., `data["meas"]["1"]` or the full measurement dictionary, `data["meas]`.
    # Arguments
    - data: `ENGINEERING` data model of the feeder, or dictionary corresponding to a single measurement
    - chosen_upper_bound: finite upper bound, defaults to 100 if no indication provided
    - rescale: `false` by default. If `true`, the `chosen_upper_bound` is multiplied by the value of `data["se_settings"]["rescaler"]`
               and their product is used as the upper bound. Otherwise,
"""
function assign_residual_ub!(data::Dict; chosen_upper_bound::Float64=100.0, rescale::Bool=false)
    rescale ? upp_bound = chosen_upper_bound*data["se_settings"]["rescaler"] : upp_bound = chosen_upper_bound
    if haskey(data, "meas")
        for (_, meas) in data["meas"]
            meas["res_max"] = upp_bound
        end
    elseif haskey(data, "dst")
        data["res_max"] = upp_bound
    else
        Memento.error(_LOGGER, "Unrecognized data input.")
    end
end
"""
    vm_to_w_conversion!(data::Dict)

This function should be called after measurements are added to the data dictionary. It converts voltage magnitude
    measurements into their square, so :vm is transformed into :w. It is useful when using the LinDist3Flow or SDP formulation.
    The conversion is exact if applied to a Normal distribution, while does not necessarily apply to other distributions.
    In the SDP case, :vm is currently not supported as input measurement, so this is necessary.
    In the LinDist3Flow it allows to ignore the square vm conversion constraint.
"""
function vm_to_w_conversion!(data::Dict)
    for (m,meas) in data["meas"]
        if meas["var"] == :vm
            for c in 1:length(meas["dst"])
                if meas["dst"][c] != 0.0
                    @assert (typeof(meas["dst"][c]) == Distributions.Normal{Float64}) "vm_to_w conversion only available for the Normal distribution"
                    current_μ = _DST.mean(meas["dst"][c])
                    current_σ = _DST.std(meas["dst"][c])
                    data["meas"][m]["dst"][c] = _DST.Normal(current_μ^2, current_σ)
                end
            end
            data["meas"][m]["var"] = :w
        end
    end
end
"""
    assign_load_pseudo_measurement_info!(data::Dict, pseudo_load_list::Array, cluster_list::Array, csv_path::String; time_step::Int64=1, day::Int64=1)

This function is a helper function to associate pseudo measurement information to a list of loads.
    #Arguments:
    - data: `ENGINEERING` data model of the feeder, or dictionary corresponding to a single measurement
    - pseudo_load_list: list of loads that are described by pseudo measurements
    - cluster_list: list of clusters to be associated one-on-one with the pseudo_load_list
    - csv_path: path to csv file with cluster/pseudo measurement probability information
    - time_step: time step to extract the probability distribuion function for, if applicable
    - day: day to extract the probability distribuion function for, if applicable
"""
function assign_load_pseudo_measurement_info!(data::Dict, pseudo_load_list::Array, cluster_list::Array, csv_path::String; time_step::Int64=1, day::Int64=1)
    cluster_df = CSV.read(csv_path)
    for idx in 1:length(pseudo_load_list)
        data["load"]["$(pseudo_load_list[idx])"]["pseudo"] = Dict{String, Any}("day" => day,
                                                                               "time_step" => time_step,
                                                                               "cluster" => cluster_list[idx]
                                                                               )
    end
end
