################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsSE.jl                                                             #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

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
