################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
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
"""
    sample_fake_measurements(meas_row_dst, sorted_args, seed)
Called within read_measurement!. Samples measurement errors from a distribution.
Currently available
"""
function sample_fake_measurements(meas_row_dst, sorted_args, seed)
    meas_row_dst == "ExtendedBeta" ? pkg_id = _PMDSE : pkg_id = _DST
    distr = [getfield(pkg_id, Symbol(meas_row_dst))(tuple(sa...)...) for sa in sorted_args]
    randRNG = [_RAN.seed!(seed+i) for i in 1:length(sorted_args)]
    fake_meas = [_RAN.rand(randRNG[i], distr[i]) for i in 1:length(sorted_args)]
    return [[fake_meas[i], last.(sorted_args)[i]] for i in 1:length(sorted_args)]
end
"""
    read_measurement!(data, meas_row; sample_fake_meas, seed)
Adds measurement data from separate CSV file to the PowerModelsDistribution data
dictionary, called from within `add_measurements!()`.
"""
function read_measurement!(data::Dict, meas_row::_DFS.DataFrameRow, sample_fake_meas, seed)
    dst_params = []
    for nr in 1:4
        if "par_$(nr)" ∈ names(meas_row) && !ismissing(meas_row[Symbol("par_",nr)]) && meas_row[Symbol("par_",nr)] != "missing"
            typeof(meas_row[Symbol("par_",nr)]) == String ? par_array = dataString_to_array(meas_row[Symbol("par_",nr)]) : par_array = [meas_row[Symbol("par_",nr)]]
            push!(dst_params, par_array)
        end
    end
    @assert all([length(dst_params[1])==length(dst_params[i]) for i in 1:length(dst_params)]) "The lengths of the distribution parameters must be equal, e.g, all three-phase"
    sorted_args = []
    for ph in 1:length(dst_params[1])
        sorted_arg = [param[ph] for param in dst_params]
        push!(sorted_args, sorted_arg)
    end
    if sample_fake_meas
        sorted_args = sample_fake_measurements(meas_row[:dst], sorted_args, seed)
    end
    meas_row[:dst] == "ExtendedBeta" ? pkg_id = _PMDSE : pkg_id = _DST
    data["dst"] = [getfield(pkg_id, Symbol(meas_row[:dst]))(tuple(sa...)...) for sa in sorted_args]
    #NB code below to change with PMD10.0
    if length(meas_row[:phase]) == 1
        save_dst = data["dst"][1]
        data["dst"] = Any[0.0, 0.0, 0.0]
        data["dst"][parse(Int64,meas_row[:phase])] = save_dst
    end
end
"""
    add_measurements!(data::Dict, meas_file::String; actual_meas::Bool = false, seed::Int=0)

Add measurement data from separate CSV file to the PowerModelsDistribution data
dictionary. To fully understand how this function works, it is recommended to first read
the documentation section that describes the CSV measurement file format.
# Arguments
-   `data`: MATHEMATICAL data dictionary in a format usable with PowerModelsDistribution
-   `meas_file`: path to and name of file with measurement data
-   `actual_meas`: default is false. When applied to non-normal distributions,
        the effect is overruled to that of `true`. For normal distributions, the following applies:
    *   `false`: the "par_1" in meas_file are not actual measurements, but, e.g.,
        error-free powerflow results. Then, a fake measurement is built, extracting
        a value with an error from the given normal distribution.
    *   `true`: the "par_1" values in meas_file are actual measurement values,
        and the "par_2" are the σs of the measurements' distributions. These are
        directly used as input of the state estimator without further processing.
    *   if a "parse" column is present in the CSV file, the `true` or `false` is associated
        to each individual row (i.e., measurement), and overrules whatever the actual_meas
        input of add_measurements!() itself is.
-   `seed`: random seed value to make the results reproducible and explore different
    Monte Carlo scenarios when sampling measurement with errors from a probability distribution.
"""
function add_measurements!(data::Dict, meas_file::String; actual_meas::Bool=false, seed::Int = 0)
    meas_df = _CSV.read(meas_file)
    data["meas"] = Dict{String, Any}()
    [data["meas"]["$m_id"] = Dict{String,Any}() for m_id in meas_df[!,:meas_id]]
    for row in 1:size(meas_df)[1]
        meas_df[row,:dst] ∈ ["Normal"] ? sample_fake_meas = !actual_meas : sample_fake_meas = false
        data["meas"]["$(meas_df[row,:meas_id])"] = Dict{String,Any}()
        data["meas"]["$(meas_df[row,:meas_id])"]["cmp"] = Symbol(meas_df[row,:cmp_type])
        data["meas"]["$(meas_df[row,:meas_id])"]["cmp_id"] = meas_df[row,:cmp_id]
        data["meas"]["$(meas_df[row,:meas_id])"]["var"] = Symbol(meas_df[row,:meas_var])
        if "crit" ∈ names(meas_df)
            data["meas"]["$(meas_df[row,:meas_id])"]["crit"] = meas_df[row, :crit]
        end
        if "sample" ∈ names(meas_df) &&  !ismissing(meas_df[row, :sample]) && meas_df[row,:dst] ∈ ["Normal"]
            sample_fake_meas = meas_df[row, :sample]
        end
        read_measurement!(data["meas"]["$(meas_df[row,:meas_id])"], meas_df[row,:], sample_fake_meas, seed)
    end
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
function get_sigma(σ, meas_var::String,phases)
    sigma = meas_var in ["vm","vr","vi"] ? σ/3 : σ/5/3 ;
    return length(phases) == 1 ? sigma : sigma.*ones(length(phases)) ;
end
get_configuration(cmp_type::String, cmp_data::Dict{String,Any}) = "G"
init_measurements() =
    _DFS.DataFrame(meas_id=Int64[], cmp_type=String[], cmp_id=String[],
                         meas_type=String[], meas_var=String[], phase=String[],
                         dst=String[], par_1=Union{String, Missing}[], par_2=Union{String, Missing}[],
                         par_3=Union{String, Missing}[], par_4=Union{String, Missing}[], crit=Union{String, Missing}[])
"""
   Function to write the dataframe row for a Normal component
"""
function write_cmp_measurement!(df::_DFS.DataFrame, model::Type, cmp_id::String, cmp_type::String, cmp_data::Dict{String,Any},
                                        cmp_res::Dict{String,Any}, phases; exclude::Vector{String}=String[], σ::Float64)
    if !repeated_measurement(df, cmp_id, cmp_type, phases)
        config = get_configuration(cmp_type, cmp_data)
        for meas_var in get_measures(model, cmp_type) if !(meas_var in exclude)
            push!(df, [length(df.meas_id)+1,                  # meas_id
                       cmp_type,                              # cmp_type
                       cmp_id,                                # cmp_id
                       config,                                # config
                       reduce_name(meas_var),                 # meas_var
                       string(phases),                        # phase
                       "Normal",                              # dst
                       string(cmp_res[meas_var][phases]),     # par_1
                       string(get_sigma(σ, meas_var,phases)), # par_2
                        missing, missing, missing             #par_3,4,crit
                      ])
    end end end
end
function write_cmp_measurements!(df::_DFS.DataFrame, model::Type, cmp_type::String,
                                 data::Dict{String,Any}, pf_results::Dict{String,Any};
                                 exclude::Vector{String}=String[], σ::Float64)
    for (cmp_id, cmp_res) in pf_results["solution"][cmp_type]
        # write the properties for the component
        cmp_data = data[cmp_type][cmp_id]
        phases = get_phases(cmp_type,cmp_data)
        write_cmp_measurement!(df, model, cmp_id, cmp_type, cmp_data, cmp_res, phases, exclude = exclude, σ = σ)
        # write the properties for its bus
        cmp_id = string(cmp_data["$(cmp_type)_bus"])
        cmp_data = data["bus"][cmp_id]
        cmp_res = pf_results["solution"]["bus"][cmp_id]
        write_cmp_measurement!(df, model, cmp_id, "bus", cmp_data, cmp_res, [1, 2, 3], exclude = exclude, σ = σ)
    end
end
"""
    write_measurements!(model::Type, data::Dict, pf_results::Dict, path::String; exclude::Vector{String}=String[])

Function to write a csv file with measurements, to be used to run state estimation calculations. The
file is built starting from power flow results from PowerModelsDistribution.jl (or any dictionary with
the same format). The mesurements consist of the voltage and power/current injection in correspondence
of all generators and loads. The exact measurement type depends on the chosen power flow formulation,
e.g., with the AC Polar formulation, these are voltage magnitude and active and reactive power.
# Arguments
-   `model`: power flow type of the generated measurements, e.g., ACPPowerModel.
             If it does not match the power flow model of the `pf_results`, it might not work.
             `pf_results` can be post-processed, e.g., polar results can be converted in rectangular
             and viceversa, to make the result dictionary compatible.
-   `data`: MATHEMATICAL data dictionary in a format usable with PowerModelsDistribution
-   `pf_results`: PowerModelsDistribution solution dictionary or similar format
-   `path`: path where the csv file will be generated and stored
-   `exclude`: select quantities from the `pf_results` dictionary to be excluded from the measurement
               generation. For example, to ignore generator results with ACPPowerModel,
               set exclude = ["pg", "qg"].
-   `σ`: standard deviation of demand/generation measurement, for voltage measurements
        this is rescaled in `get_sigma()`
"""
function write_measurements!(model::Type, data::Dict, pf_results::Dict, path::String; exclude::Vector{String}=String[], σ::Float64=0.005)
    df = init_measurements()
    for cmp_type in ["gen", "load"]
        write_cmp_measurements!(df, model, cmp_type, data, pf_results, exclude = exclude, σ = σ)
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
    elseif haskey(pf_result["solution"]["bus"][first_key], "w")
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
    write_measurements_and_pseudo!(model::Type, data::Dict, pf_results::Dict, path::String; exclude::Vector{String}=String[], distribution_info::String, σ::Float64=0.005)

Helper function to write a csv file with a combination of measurements and pseudo-measurements.
Works similarly to write_measurements!() with additional support for non-Normal distributions
for the pseudo-measurements. In order to use this function, the load data for pseudo measurements
data["load"] need to point to an external file where information on the probability distribution is stored.
An example of such a file is distr_example.csv in test/extra/measurements.
The arguments of the function are the same as write_measurements!(), with the addition of
`distribution_info`: the path to external csv file for pseudo-measurements distributions.
"""
function write_measurements_and_pseudo!(model::Type, data::Dict, pf_results::Dict, path::String; exclude::Vector{String}=String[], distribution_info::String, σ::Float64=0.005)

    df = _DFS.DataFrame(meas_id=Int64[], cmp_type=String[], cmp_id=String[],meas_type=String[], meas_var=String[],
             phase=String[], dst=String[], par_1=Union{String, Missing}[], par_2=Union{String, Missing}[],
             par_3=Union{String, Missing}[], par_4=Union{String, Missing}[], crit=Union{String, Missing}[] )
    di_df = _CSV.read(distribution_info)
    for cmp_type in ["gen", "load"]
        for (cmp_id, cmp) in data[cmp_type]
            phases = get_phases(cmp_type, data[cmp_type][cmp_id])
            if haskey(cmp,"pseudo")
                write_cmp_pseudo!(df, model, cmp_type, cmp_id, data, di_df, phases, exclude)
            else
                write_cmp_measurement!(df, model, cmp_id, cmp_type, data[cmp_type][cmp_id], pf_results["solution"][cmp_type][cmp_id],
                                                    phases, exclude = exclude, σ = σ)
            end
        end
    end
    _CSV.write(path, df)
end
"""
    write_cmp_pseudo!(df::_DFS.DataFrame, model::Type, cmp_type::String, cmp_id::String, data::Dict{String,Any}, distr_info::_DFS.DataFrame, phases)
Used within write_measurements_and_pseudo!() to generate pseudo-measurements
"""
function write_cmp_pseudo!(df::_DFS.DataFrame, model::Type, cmp_type::String, cmp_id::String,
                                 data::Dict{String,Any}, distr_info::_DFS.DataFrame, phases, exclude)
    cosϕ = distr_info[1, :PF]
    if !repeated_measurement(df, cmp_id, cmp_type, phases)
        config = get_configuration(cmp_type, data[cmp_type][cmp_id])
        row_idx = find_row(distr_info, data[cmp_type][cmp_id]["pseudo"]["time_step"], data[cmp_type][cmp_id]["pseudo"]["cluster"],data[cmp_type][cmp_id]["pseudo"]["day"])
        for meas_var in get_measures(model, cmp_type) if !(meas_var in exclude)
            if distr_info[row_idx, :distr][1] == "ExtendedBeta" && !distr_info[row_idx, :per_unit][1]
                per_unit_div = data["settings"]["sbase_default"]
            else
                per_unit_div = 1
            end
            occursin("q", string(meas_var)) ? per_unit_div/=tan(acos(cosϕ)) : per_unit_div/=1
            #push active power pseudo
            push!(df, [length(df.meas_id)+1,              # meas_id
                   cmp_type,                              # cmp_type
                   cmp_id,                                # cmp_id
                   config,                                # meas_id
                   reduce_name(meas_var),                 # meas_var
                   string(phases),                        # phase
                   distr_info[row_idx, :distr][1],           # dst
                   string(has_par(distr_info, row_idx, 1)[1]),       # par_1
                   string(has_par(distr_info, row_idx, 2)[1]),       # par_2
                   string(has_par(distr_info, row_idx, 3)[1]/per_unit_div),  # par_3
                   string(has_par(distr_info, row_idx, 4)[1]/per_unit_div),  # par_4
                   "mle"                                  # crit
                  ])
    end end end
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
    elseif haskey(pf_result["solution"]["bus"][first_key], "w")
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
function find_row(df::DataFrames.DataFrame, time_step::Int64, cluster::Int64, day::Int64)
    bitarray_sum = ( df[!, :day].==day) + (df[!, :time_step].==time_step) + (df[!, :cluster].==cluster)
    row_index = findall(x->x==maximum(bitarray_sum), bitarray_sum)
    @assert length(row_index) == 1 "There is more than one entry that matches time step and cluster"
    return row_index
end
"""
checks if load/gen data has a given distribution parameter
"""
has_par(df, row, par_num) =
      "par_$(par_num)" ∈ names(df) ? df[row, Symbol("par_$(par_num)") ] : missing
