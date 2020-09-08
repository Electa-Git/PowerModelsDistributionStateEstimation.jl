################################################################################
#  Copyright 2020, Tom Van Acker, Marta Vanin                                  #
################################################################################
# PowerModelsDSSE.jl                                                           #
# An extention package of PowerModelsDistribution.jl for Static Distribution   #
# System State Estimation.                                                     #
# See http://github.com/timmyfaraday/PowerModelsDSSE.jl                        #
################################################################################

## CSV to measurement parser
function dataString_to_array(input::String)::Array
    if size(split(input, ","))[1] > 1
        rm_brackets = input[2:(end-1)]
        raw_string = split(rm_brackets, ",")
        float_array = [parse(Float64, ss) for ss in raw_string]
    else
        float_array = [parse(Float64, input)]
    end
    return float_array
end

function read_measurement!(data::Dict, meas_row::_DFS.DataFrameRow, actual_meas, seed)::Dict
    meas_val = dataString_to_array(meas_row[:val])
    σ = dataString_to_array(meas_row[:sigma])
    if actual_meas
        data["dst"] = [_DST.Normal(meas_val[i], σ[i]) for i in 1:length(meas_val)]
    else #if it is not a real measurement
        distr = [_DST.Normal(meas_val[i], σ[i]) for i in 1:length(meas_val)]
        randRNG = [_RAN.seed!(seed+i) for i in 1:length(meas_val)]
        fake_meas = [_RAN.rand(randRNG[i], distr[i]) for i in 1:length(meas_val)]
        data["dst"] = [_DST.Normal(fake_meas[i], σ[i]) for i in 1:length(meas_val)]
    end
    if length(meas_row[:phase]) ==1
        save_dst = data["dst"][1]
        data["dst"] = Any[0.0, 0.0, 0.0]
        data["dst"][parse(Int64,meas_row[:phase])] = save_dst
    end

    return data
end
"""
    add_measurements!(data::Dict, meas_file::String; actual_meas::Bool = false, seed::Int=0)

Add measurement data from separate CSV file to the PowerModelsDistribution data
dictionary.
# Arguments
-   `data`: data dictionary in a format usable with PowerModelsDistribution
-   `meas_file`: path to and name of file with measurement data
-   `actual_meas`: default is false.
    *   `false`: the "val" in meas_file are not actual measurements, e.g.,
        error-free powerflow results. In this case, a fake measurement is built,
        extracting a value from the given distribution.
    *   `true`: the "val" column in meas_file are actual measurement values,
        i.e., with an error. No other processing is required.
-   `seed`: random seed value to make the results reproducible. It is an argument
    and not a fixed value inside the function to allow, e.g., the exploration of
    different MonteCarlo scenarios
"""
function add_measurements!(data::Dict, meas_file::String; actual_meas::Bool=false, seed::Int = 0 )::Dict
    meas_df = _CSV.read(meas_file)
    data["meas"] = Dict{String, Any}()
    [data["meas"]["$m_id"] = Dict{String,Any}() for m_id in meas_df[!,:meas_id]]
    for row in 1:size(meas_df)[1]
        @assert meas_df[row,:dst] == "Normal" "Currently only normal distributions supported"
        data["meas"]["$(meas_df[row,:meas_id])"] = Dict{String,Any}()
        data["meas"]["$(meas_df[row,:meas_id])"]["cmp"] = Symbol(meas_df[row,:cmp_type])
        data["meas"]["$(meas_df[row,:meas_id])"]["cmp_id"] = meas_df[row,:cmp_id]
        data["meas"]["$(meas_df[row,:meas_id])"]["var"] = Symbol(meas_df[row,:meas_var])
        read_measurement!(data["meas"]["$(meas_df[row,:meas_id])"], meas_df[row,:], actual_meas, seed)
    end
    return data
end

## Powerflow results to CSV
repeated_measurement(df::_DFS.DataFrame, cmp_id::String, cmp_type::String, phases) =
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
    elseif model  <: _PMs.AbstractIVRModel
        # NB: IVR is a subtype of ACR, therefore it should preceed ACR
        if cmp_type == "bus"  return ["vr","vi"] end
        if cmp_type == "gen"  return ["crg","cig"] end
        if cmp_type == "load" return ["crd_bus","cid_bus"] end
    elseif model <: _PMs.AbstractACRModel
        if cmp_type == "bus"  return ["vr","vi"] end
        if cmp_type == "gen"  return ["pg","qg"] end
        if cmp_type == "load" return ["pd","qd"] end
    elseif model <: _PMD.SDPUBFPowerModel
        #if cmp_type == "bus"  return ["vr","vi"] end
        if cmp_type == "gen"  return ["pg","qg"] end
        if cmp_type == "load" return ["pd","qd"] end
    elseif model <: _PMD.LinDist3FlowModel
        if cmp_type == "bus"  return ["w"] end
        if cmp_type == "gen"  return ["pg","qg"] end
        if cmp_type == "load" return ["pd","qd"] end
    end
    return []
end
function reduce_name(meas_var::String)
    if meas_var == "crd_bus" return "crd" end
    if meas_var == "cid_bus" return "cid" end
    return meas_var
end
function get_sigma(meas_var::String,phases)
    sigma = meas_var in ["vm","vr","vi"] ? 0.005/3 : 0.001/3 ;
    return length(phases) == 1 ? sigma : sigma.*ones(length(phases)) ;
end
get_configuration(cmp_type::String, cmp_data::Dict{String,Any}) = "G"
init_measurements() =
    _DFS.DataFrame(meas_id=Int64[], cmp_type=String[], cmp_id=String[],
                         meas_type=String[], meas_var=String[], phase=String[],
                         dst=String[], val=String[], sigma=String[] )
function write_cmp_measurement!(df::_DFS.DataFrame, model::Type, cmp_id::String,
                                cmp_type::String, cmp_data::Dict{String,Any},
                                cmp_res::Dict{String,Any}, phases;
                                exclude::Vector{String}=String[])
    if !repeated_measurement(df, cmp_id, cmp_type, phases)
        config = get_configuration(cmp_type, cmp_data)
        for meas_var in get_measures(model, cmp_type) if !(meas_var in exclude)
            push!(df, [length(df.meas_id)+1,                # meas_id
                       cmp_type,                            # cmp_type
                       cmp_id,                              # cmp_id
                       config,                              # meas_id
                       reduce_name(meas_var),               # meas_var
                       string(phases),                      # phase
                       "Normal",                            # dst
                       string(cmp_res[meas_var][phases]),   # val
                       string(get_sigma(meas_var,phases))]) # sigma
    end end end
end
function write_cmp_measurements!(df::_DFS.DataFrame, model::Type, cmp_type::String,
                                 data::Dict{String,Any}, pf_results::Dict{String,Any};
                                 exclude::Vector{String}=String[])
    for (cmp_id, cmp_res) in pf_results["solution"][cmp_type]
        # write the properties for the component
        cmp_data = data[cmp_type][cmp_id]
        phases = get_phases(cmp_type,cmp_data)
        write_cmp_measurement!(df, model, cmp_id, cmp_type, cmp_data, cmp_res, phases, exclude = exclude)
        # write the properties for its bus
        cmp_id = string(cmp_data["$(cmp_type)_bus"])
        cmp_data = data["bus"][cmp_id]
        cmp_res = pf_results["solution"]["bus"][cmp_id]
        write_cmp_measurement!(df, model, cmp_id, "bus", cmp_data, cmp_res, [1, 2, 3], exclude = exclude)
    end
end
"""
    write_measurements!(model::Type, data::Dict, pf_results::Dict, path::String)

Function to write a measurement file, i.e., a csv-file, to a specific path based
on the power flow.
"""
function write_measurements!(model::Type, data::Dict, pf_results::Dict, path::String; exclude::Vector{String}=String[])
    df = init_measurements()
    for cmp_type in ["gen", "load"]
        write_cmp_measurements!(df, model, cmp_type, data, pf_results, exclude = exclude)
    end
    _CSV.write(path, df)
end

"""
    add_voltage_measurement!(model::Type, data::Dict, pf_results::Dict, path::String)

This function can be run after add_measurements! for the cases in which only power and/or
    current measurements are generated. It was observed that adding even only one voltage measurement
    helps the state estimator converge.
"""
function add_voltage_measurement!(data::Dict, pf_result::Dict, sigma::Float64)

    first_key =  first(keys(pf_result["solution"]["bus"]))
    if haskey(pf_result["solution"]["bus"][first_key], "vm")
        #do nothing
    else
        vm = sqrt.(pf_result["solution"]["bus"][first_key]["vi"].^2+pf_result["solution"]["bus"][first_key]["vr"].^2)
        voltage_meas_idx = string(maximum(parse(Int64,i) for i in keys(data["meas"]) ) + 1)
        bus_idx = parse(Int64, first_key)
        data["meas"][voltage_meas_idx] = Dict{String, Any}("var"=>:vm,"cmp"=>:bus,
                                        "dst"=>[Distributions.Normal{Float64}(vm[1], sigma), Distributions.Normal{Float64}(vm[2], sigma), Distributions.Normal{Float64}(vm[3], sigma)],
                                        "cmp_id"=>bus_idx)
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
