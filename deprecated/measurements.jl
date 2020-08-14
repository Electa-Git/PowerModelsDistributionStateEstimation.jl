using DataFrames

"""
    init_measurements()

This function initializes an empty dataframe for measurements, with the following
attributes
    * meas_id [`Int`]: unique id of the measurement.
    * cmp_type [`String`]: type of the measured component, e.g., "bus", "load", etc.
    * cmp_id [`Int`]: unique id of the measured component.
    * meas_type [`String`]:
    * meas_var [`String`]: measured variable, e.g., "vm", "pd", etc.
    * phase [`String`]: measured phases.
    * dst [`String`]: type of distribution, e.g., "Normal".
    * val [`String`]: the measured value.
    * sigma [`String`]: the variance of the measurement.
"""
repeated_measurement(df::DataFrame, cmp_id::String, cmp_type::String, phases) =
    sum(.&(df[!,:cmp_id].==cmp_id,df[!,:cmp_type].==cmp_type,df[!,:phase].==string(phases))) > 0
function get_phases(cmp_type::String, cmp_data::Dict{String,Any})
    if cmp_type == "gen"  return [1, 2, 3] end
    if cmp_type == "load"
        phases = [1, 2, 3][.&(cmp_data["pd"] .!= 0,cmp_data["qd"] .!= 0)]
        return length(phases) == 1 ? phases[1] : phases ;
    end
end
function get_measures(model::DataType, cmp_type::String)
    if model <: _PMs.AbstractACPModel
        if cmp_type == "bus"  return ["vm"] end
        if cmp_type == "gen"  return ["pg","qg"] end
        if cmp_type == "load" return ["pd","qd"] end
    elseif model <: _PMs.AbstractACRModel
        if cmp_type == "bus"  return ["vr","vi"] end
        if cmp_type == "gen"  return ["pg","qg"] end
        if cmp_type == "load" return ["pd","qd"] end
    elseif model  <: _PMs.AbstractIVRModel
        if cmp_type == "bus"  return ["vr","vi"] end
        if cmp_type == "gen"  return ["crg","cig"] end
        if cmp_type == "load" return ["crd_bus","cid_bus"] end
    end
    return []
end
function reduce_name(meas_var::String)
    if meas_var == "crd_bus" return "crd" end
    if meas_var == "cid_bus" return "cid" end
    return meas_var
end
function get_sigma(meas_var::String,phases)
    sigma = meas_var == "vm" ? 0.005 : 0.001 ;
    return length(phases) == 1 ? sigma : sigma.*ones(length(phases)) ;
end
get_configuration(cmp_type::String, cmp_data::Dict{String,Any}) = "G"
init_measurements() =
    DataFrames.DataFrame(meas_id=Int64[], cmp_type=String[], cmp_id=String[],
                         meas_type=String[], meas_var=String[], phase=String[],
                         dst=String[], val=String[], sigma=String[] )
function write_cmp_measurement!(df::DataFrame, model::Type, cmp_id::String,
                                cmp_type::String, cmp_data::Dict{String,Any},
                                cmp_res::Dict{String,Any}, phases)
    if !repeated_measurement(df, cmp_id, cmp_type, phases)
        config = get_configuration(cmp_type, cmp_data)
        for meas_var in get_measures(model, cmp_type)
            push!(df, [length(df.meas_id)+1,                # meas_id
                       cmp_type,                            # cmp_type
                       cmp_id,                              # cmp_id
                       config,                              # meas_id
                       reduce_name(meas_var),               # meas_var
                       string(phases),                      # phase
                       "Normal",                            # dst
                       string(cmp_res[meas_var][phases]),   # val
                       string(get_sigma(meas_var,phases))]) # sigma
    end end
end
function write_cmp_measurements!(df::DataFrame, model::Type, cmp_type::String,
                                 data::Dict{String,Any}, pf_results::Dict{String,Any})
    for (cmp_id, cmp_res) in pf_results["solution"][cmp_type]
        # write the properties for the component
        cmp_data = data[cmp_type][cmp_id]
        phases = get_phases(cmp_type,cmp_data)
        write_cmp_measurement!(df, model, cmp_id, cmp_type, cmp_data, cmp_res, phases)
        # write the properties for its bus
        cmp_id = string(cmp_data["$(cmp_type)_bus"])
        cmp_data = data["bus"][cmp_id]
        cmp_res = pf_results["solution"]["bus"][cmp_id]
        write_cmp_measurement!(df, model, cmp_id, "bus", cmp_data, cmp_res, [1, 2, 3])
    end
end
function write_measurements!(model::Type, data::Dict{String,Any}, pf_results::Dict{String,Any}, path::String)
    df = init_measurements()
    for cmp_type in ["gen", "load"]
        write_cmp_measurements!(df, model, cmp_type, data, pf_results)
    end
    CSV.write(path, df)
end
