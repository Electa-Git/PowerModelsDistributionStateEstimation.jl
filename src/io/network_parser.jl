################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
# Contributor: Sander Claeys (@sanderclaeys)                                   #
################################################################################

## Electricity North West Data Parser
# constants
const ENWL_ROOT_PATH    = joinpath(BASE_DIR,"test/data/enwl")
const ENWL_PROFILE_PATH = "$ENWL_ROOT_PATH/profiles"
const ENWL_NETWORK_PATH = "$ENWL_ROOT_PATH/networks"
const ENWL_PROFILES     = Dict(
    ("summer","load") =>"Summer_Load_Profiles.csv",
    ("summer","pv")   =>"Summer_PV_Profiles.csv",
    ("winter","ehp")  =>"Winter_EHP_Profiles.csv",
    ("winter","ev")   =>"Winter_EV_Profiles.csv",
    ("winter","load") =>"Winter_Load_Profiles.csv",
    ("winter","uchp") =>"Winter_uCHP_Profiles.csv",
)
const ENWL_PROFILE_SIGN = Dict(
    ("summer","load") =>  1,
    ("summer","pv")   => -1,
    ("winter","ehp")  =>  1,
    ("winter","ev")   =>  1,
    ("winter","load") =>  1,
    ("winter","uchp") => -1,
)

# functions
get_profiles(ssn, dev) =
    Matrix{Float64}(_CSV.read("$ENWL_PROFILE_PATH/$(ENWL_PROFILES[(ssn, dev)])", _DFS.DataFrame))
function get_enwl_dss_path(network::Int, feeder::Int)
    return "$ENWL_NETWORK_PATH/network_$network/Feeder_$feeder/Master.dss"
end

"""
    insert_profiles!(data, season, devices, pfs; t=missing, useactual=true)

This function adds the load profiles to the parsed ENWL ENGINEERING data `data`.
# Arguments
- data: ENGINEERING data model of the feeder
- season: `"summer"`, `"winter"`
- devices: `"load"`, `"pv"`, `"ev"`, `"ehp"`, `"uchp"`
- pfs: power factor of the devices
- t: time-step

# Example
```julia-repl
julia> data = parse_file(get_enwl_dss_path(10, 1))
julia> insert_profiles!(data, "summer", ["load", "pv"], [0.95, 0.90], t = 144)
```
"""
function insert_profiles!(data, season, devices, pfs; t=missing, useactual=true)
    N = length(data["load"])
    mult = 1E3/data["settings"]["power_scale_factor"]
    sd_tot = zeros(287, N)
    for i in 1:length(devices)
        device = devices[i]; pf = pfs[i]
        linds  = ((1:N).-1).%100 .+1
        sign   = ENWL_PROFILE_SIGN[(season, device)]
        pd     = mult*sign*get_profiles(season, device)[:,linds]
        sd_tot += (1 + im*sqrt(1-pf^2))*pd
    end

    if ismissing(t)
        t = argmax(abs.(reshape(sum(real.(sd_tot), dims=2), 287)))
    end

    for i in 1:N
        load = data["load"]["load$i"]
        dims = length(load["pd_nom"])
        if useactual
            load["pd_nom"] = fill(real(sd_tot[t,i])/dims, dims)
            load["qd_nom"] = fill(imag(sd_tot[t,i])/dims, dims)
        else
            load["pd_nom"] *= real(sd_tot[t,i])
            load["qd_nom"] *= imag(sd_tot[t,i])
        end
    end
end
"""
    rm_enwl_transformer!(data_eng)

This function removes the transformer from a parsed ENWL `ENGINEERING` data file.
"""
function rm_enwl_transformer!(data_eng)
    if haskey(data_eng, "transformer")
        line1 = data_eng["line"]["line1"]
        trans = data_eng["transformer"]["tr1"]
        vprim_scale = trans["vm_nom"][2]/trans["vm_nom"][1]

        vsource = data_eng["voltage_source"]["source"]

        vsource["vm"] *= vprim_scale
        vsource["rs"] *= vprim_scale^2
        vsource["xs"] *= vprim_scale^2
        vsource["bus"] = "1"

        delete!(data_eng, "transformer")
        delete!(data_eng["bus"], "sourcebus")

        vbases_default = data_eng["settings"]["vbases_default"]
        vbases_default["1"] = vbases_default["sourcebus"]*vprim_scale
        delete!(vbases_default, "sourcebus")
    end
end
"""
    reduce_enwl_lines_eng!(data_eng)

This function removes all trailing lines from a parsed ENWL `ENGINEERING` data
file.
"""
function reduce_enwl_lines_eng!(data_eng)
    rm_trailing_lines_eng!(data_eng)
    join_lines_eng!(data_eng)
end
function rm_trailing_lines_eng!(data_eng)

    buses_exclude = []
    for comp_type in ["load", "shunt", "generator", "voltage_source"]
        if haskey(data_eng, comp_type)
            buses_exclude = union(buses_exclude, [comp["bus"] for (_, comp) in data_eng[comp_type]])
        end
    end
    if haskey(data_eng, "transformer")
        buses_exclude = union(buses_exclude, hcat([tr["bus"] for (_, tr) in data_eng["transformer"]]...))
    end

    line_has_shunt = Dict()
    bus_lines = Dict(k=>[] for k in keys(data_eng["bus"]))
    for (id, line) in data_eng["line"]
        lc = data_eng["linecode"][line["linecode"]]
        line_has_shunt[id] = !all(iszero(lc[k]) for k in ["b_fr", "b_to", "g_fr", "g_to"])
        push!(bus_lines[line["f_bus"]], id)
        push!(bus_lines[line["t_bus"]], id)
    end

    eligible_buses = [bus_id for (bus_id, line_ids) in bus_lines if length(line_ids)==1 && !(bus_id in buses_exclude) && !line_has_shunt[line_ids[1]]]

    while !isempty(eligible_buses)
        for bus_id in eligible_buses
            # this trailing bus has one associated line
            line_id = bus_lines[bus_id][1]
            line = data_eng["line"][line_id]

            delete!(data_eng["line"], line_id)
            delete!(data_eng["bus"],  bus_id)

            other_end_bus = line["f_bus"]==bus_id ? line["t_bus"] : line["f_bus"]
            bus_lines[other_end_bus] = setdiff(bus_lines[other_end_bus], [line_id])
            delete!(bus_lines,  bus_id)
        end

        eligible_buses = [bus_id for (bus_id, line_ids) in bus_lines if length(line_ids)==1 && !(bus_id in buses_exclude) && !line_has_shunt[line_ids[1]]]
    end
end
function _line_reverse_eng!(line)
    prop_pairs = [("f_bus", "t_bus")]

    for (x,y) in prop_pairs
        tmp = line[x]
        line[x] = line[y]
        line[y] = tmp
    end
end
function join_lines_eng!(data_eng)
    # a bus is eligible for reduction if it only appears in exactly two lines
    buses_all = collect(keys(data_eng["bus"]))
    buses_exclude = []

    # start by excluding all buses that appear in components other than lines
    for comp_type in ["load", "shunt", "generator", "voltage_source"]
        if haskey(data_eng, comp_type)
            buses_exclude = union(buses_exclude, [comp["bus"] for (_, comp) in data_eng[comp_type]])
        end
    end

    # per bus, list all inbound or outbound lines
    bus_lines = Dict(bus=>[] for bus in buses_all)
    for (id, line) in data_eng["line"]
        push!(bus_lines[line["f_bus"]], id)
        push!(bus_lines[line["t_bus"]], id)
    end

    # exclude all buses that do not have exactly two lines connected to it
    buses_exclude = union(buses_exclude, [bus for (bus, lines) in bus_lines if length(lines)!=2])

    # now loop over remaining buses
    candidates = setdiff(buses_all, buses_exclude)
    for bus in candidates
        line1_id, line2_id = bus_lines[bus]
        line1 = data_eng["line"][line1_id]
        line2 = data_eng["line"][line2_id]

        # reverse lines if needed to get the order
        # (x)--fr-line1-to--(bus)--to-line2-fr--(x)
        if line1["f_bus"]==bus
            _line_reverse_eng!(line1)
        end
        if line2["f_bus"]==bus
            _line_reverse_eng!(line2)
        end

        reducable = true
        reducable = reducable && line1["linecode"]==line2["linecode"]
        reducable = reducable && all(line1["t_connections"].==line2["t_connections"])
        if reducable

            line1["length"] += line2["length"]
            line1["t_bus"] = line2["f_bus"]
            line1["t_connections"] = line2["f_connections"]

            delete!(data_eng["line"], line2_id)
            delete!(data_eng["bus"], bus)
            for x in candidates
                if line2_id in bus_lines[x]
                    bus_lines[x] = [setdiff(bus_lines[x], [line2_id])..., line1_id]
                end
            end
        end
    end

    return data_eng
end
"""
    reduce_enwl_lines_math!(data_math)

This function removes all trailing lines from a parsed ENWL `MATHEMATICAL` data
file.
"""
function reduce_enwl_lines_math!(data_math)

    # a bus is eligible for reduction if it only appears in exactly two lines
    buses_all = collect(keys(data_math["bus"]))
    buses_exclude = []

    # start by excluding all buses that appear in components other than lines
    for comp_type in ["load", "shunt", "gen"]
        if haskey(data_math, comp_type)
            buses_exclude = union(buses_exclude, [string(comp["$(comp_type)_bus"]) for (_, comp) in data_math[comp_type]])
        end
    end

    # per bus, list all inbound or outbound lines
    bus_lines = Dict(bus=>[] for bus in buses_all)
    for (id, line) in data_math["branch"]
        push!(bus_lines[string(line["f_bus"])], id)
        push!(bus_lines[string(line["t_bus"])], id)
    end

    # exclude all buses that do not have exactly two lines connected to it
    buses_exclude = union(buses_exclude, [bus for (bus, lines) in bus_lines if length(lines)!=2])

    # now loop over remaining buses
    candidates = setdiff(buses_all, buses_exclude)
    for bus in candidates
        line1_id, line2_id = bus_lines[bus]
        line1 = data_math["branch"][line1_id]
        line2 = data_math["branch"][line2_id]

        # reverse lines if needed to get the order
        # (x)--fr-line1-to--(bus)--to-line2-fr--(x)
        if line1["f_bus"]==bus
            _line_reverse!(line1)
        end
        if line2["f_bus"]==bus
            _line_reverse!(line2)
        end

        reducable = true
        reducable = reducable && iszero(line1["g_to"]) && iszero(line1["b_to"])
        reducable = reducable && iszero(line2["g_fr"]) && iszero(line2["b_fr"])
        if reducable
            line1["br_r"] = line1["br_r"] .+ line2["br_r"]
            line1["br_x"] = line1["br_x"] .+ line2["br_x"]
            line1["g_to"] = line2["g_fr"]
            line1["b_to"] = line2["b_fr"]
            line1["t_bus"] = line2["f_bus"]

            delete!(data_math["branch"], line2_id)
            for x in candidates
                if line2_id in bus_lines[x]
                    bus_lines[x] = [setdiff(bus_lines[x], [line2_id])..., line1_id]
                end
            end
        end
    end

    return data_math
end
function _line_reverse!(line)
    prop_pairs = [("f_bus", "t_bus"), ("g_fr", "g_to"), ("b_fr","b_to")]

    for (x,y) in prop_pairs
        tmp = line[x]
        line[x] = line[y]
        line[y] = tmp
    end
end
