using CSV, DataFrames, Random
"""
    add_measurement_to_pmd_data!(pmd_data::Dict, meas_file::String; actual_meas = false)

Add measurement data from separate CSV file to the PowerModelsDistribution data dictionary.
# Arguments
 -    `pmd_data`: data dictionary in a format usable with PowerModelsDistribution
 -   `meas_file`: name of file with measurement data and path thereto
 - `actual_meas`: default is false.
                  if `false`, the "val" in meas_file are not actual measurements, e.g., error-free powerflow results.
                  in this case, a fake measurement is built, extracting a value from the given distribution.
                  if `true`, the "val" column in meas_file are actual measurement values, i.e., with an error.
                  no other processing is required.
-         `seed`: random seed value to make the results reproducible. It is an argument and not a fixed value
                  inside the function to allow, e.g., the exploration of different MonteCarlo scenarios
"""
function add_measurement_to_pmd_data!(pmd_data::Dict, meas_file::String; actual_meas::Bool=false, seed::Int = 0 )::Dict
    meas_df = CSV.read(meas_file)
    pmd_data["meas"] = Dict{String, Any}()
    [pmd_data["meas"]["$m_id"] = Dict{String,Any}() for m_id in meas_df[!,:meas_id]]
    for row in 1:size(meas_df)[1] # TODO: TOM: A possible cleaner way is to look into linear and carthesian indices as an iterator.
        @assert meas_df[row,:dst] == "Normal" "Currently only normal distributions supported"
        pmd_data["meas"]["$(meas_df[row,:meas_id])"] = Dict{String,Any}()
        pmd_data["meas"]["$(meas_df[row,:meas_id])"]["cmp"] = Symbol(meas_df[row,:cmp_type])
        pmd_data["meas"]["$(meas_df[row,:meas_id])"]["cmp_id"] = meas_df[row,:cmp_id]
        pmd_data["meas"]["$(meas_df[row,:meas_id])"]["var"] = Symbol(meas_df[row,:meas_var])
        read_measurement!(pmd_data["meas"]["$(meas_df[row,:meas_id])"], meas_df[row,:], actual_meas, seed)
    end
    return pmd_data
end

function read_measurement!(data::Dict, meas_row::DataFrameRow, actual_meas, seed)::Dict
    meas_val = dataString_to_array(meas_row[:val])
    σ = dataString_to_array(meas_row[:sigma])
    if actual_meas
        data["dst"] = [_DST.Normal(meas_val[i], σ[i]) for i in 1:length(meas_val)]
    else #if it is not a real measurement
        distr = [_DST.Normal(meas_val[i], σ[i]) for i in 1:length(meas_val)]
        randRNG = [Random.seed!(seed+i) for i in 1:length(meas_val)]
        fake_meas = [rand(randRNG[i], distr[i]) for i in 1:length(meas_val)]
        data["dst"] = [_DST.Normal(fake_meas[i], σ[i]) for i in 1:length(meas_val)]
    end
    if length(meas_row[:phase]) ==1
        save_dst = data["dst"][1]
        data["dst"] = Any[0.0, 0.0, 0.0]
        data["dst"][parse(Int64,meas_row[:phase])] = save_dst
    end

    return data
end

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

function update_voltage_bounds!(data::Dict; v_min::Float64=0.0, v_max::Float64=Inf)
    for (_,bus) in data["bus"]
        bus["vmin"] = [v_min, v_min, v_min]
        bus["vmax"] = [v_max, v_max, v_max]
    end
end

function update_generator_bounds!(data::Dict; p_min::Float64=0.0, p_max::Float64=Inf, q_min::Float64=-Inf, q_max::Float64=Inf)
    for (_,gen) in data["gen"]
        gen["pmin"] = [p_min, p_min, p_min]
        gen["pmax"] = [p_max, p_max, p_max]
        gen["qmin"] = [q_min, q_min, q_min]
        gen["qmax"] = [q_max, q_max, q_max]
    end
end

function update_load_bounds!(data::Dict; p_min::Float64=0.0, p_max::Float64=Inf, q_min::Float64=-Inf, q_max::Float64=Inf)
    for (_,load) in data["load"]
        load["pmin"] = [p_min, p_min, p_min]
        load["pmax"] = [p_max, p_max, p_max]
        load["qmin"] = [q_min, q_min, q_min]
        load["qmax"] = [q_max, q_max, q_max]
    end
end

function update_all_bounds!(data::Dict; v_min::Float64=0.0, v_max::Float64=Inf, pg_min::Float64=0.0, pg_max::Float64=Inf, qg_min::Float64=-Inf, qg_max::Float64=Inf, pd_min::Float64=0.0, pd_max::Float64=Inf, qd_min::Float64=-Inf, qd_max::Float64=Inf)
    update_voltage_bounds!(data; v_min=v_min, v_max=v_max)
    update_generator_bounds!(data; p_min=pg_min, p_max=pg_max, q_min=qg_min, q_max=qg_max)
    update_load_bounds!(data; p_min=pd_min, p_max=pd_max, q_min=qd_min, q_max=qd_max)
end
