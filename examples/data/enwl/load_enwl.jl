import CSV

const ENWL_ROOT_PATH    = joinpath(BASE_DIR,"examples/data/enwl")
const ENWL_PROFILE_PATH = "$ENWL_ROOT_PATH/lct-profiles"
const ENWL_NETWORK_PATH = "$ENWL_ROOT_PATH/lv-network-models"

const ENWL_PROFILE_FILENAMES = Dict(
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

get_profiles(season, device) = convert(Matrix, CSV.read("$ENWL_PROFILE_PATH/$(ENWL_PROFILE_FILENAMES[(season, device)])"))


function _replace_beginning!(lines, start, subst)
    found = false
    for (i, line) in enumerate(lines)
        if startswith(line, start)
            lines[i] = string(subst, line[1+length(start):end])
            found = true
        end
    end
    @assert(found)
end

function _patch_network_files()
    for (path, dirs, filenames) in walkdir("data/ENWL/LV network models")
        if "Master.txt" in filenames

            load_lines = ""
            open("$path/Loads.txt", "r") do f
                load_lines = readlines(f)
            end
            for (i, line) in enumerate(load_lines)
                parts = split(line, " ")
                @assert(parts[end][1:5]=="Daily")
                load_lines[i] = join(parts[1:end-1], " ")
            end
            open("$path/Loads.dss", "w") do f
                write(f, join(load_lines, "\n"))
            end

            master_lines = ""
            open("$path/Master.txt", "r") do f
                master_lines = readlines(f)
            end
            _replace_beginning!(master_lines, "Edit Vsource.Source", "New Circuit.ENWL")
            _replace_beginning!(master_lines, "Redirect Loads.txt", "Redirect Loads.dss")
            _replace_beginning!(master_lines, "Redirect Monitors.txt", "!Redirect Monitors.txt")
            _replace_beginning!(master_lines, "Redirect LoadShapes.txt", "!Redirect LoadShapes.txt")
            open("$path/Master.dss", "w") do f
                write(f, join(["Set DefaultBaseFreq=60", master_lines..., "solve"], "\n"))
            end


        end
    end
end

function get_enwl_dss_path(network::Int, feeder::Int)
    return "$ENWL_NETWORK_PATH/network_$network/Feeder_$feeder/Master.dss"
end

# function insert_profiles(enwl_data_eng, season, devices; pfs::Vector=fill(1.0, length(devices)), t::Int=missing, useactual=true)
function insert_profiles!(enwl_data_eng, season, devices, pfs; t=missing, useactual=true)
    N = length(enwl_data_eng["load"])
    mult = 1E3/enwl_data_eng["settings"]["power_scale_factor"]
    sd_tot = zeros(287, N)
    for i in 1:length(devices)
        device = devices[i]; pf = pfs[i]
        linds = ((1:N).-1).%100 .+1
        pd = mult*ENWL_PROFILE_SIGN[(season, device)]*get_profiles(season, device)[:,linds]
        sd_tot += (1 + im*sqrt(1-pf^2))*pd
    end

    if ismissing(t)
        t = argmax(abs.(reshape(sum(real.(sd_tot), dims=2), 287)))
    end

    for i in 1:N
        load = enwl_data_eng["load"]["load$i"]
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

function _identify_network_feeders()
    regexp_networks = [match(r"[Nn]etwork_(\d{1,2})", fn) for fn in readdir(ENWL_NETWORK_PATH)]
    networks = Dict([(parse(Int, x.captures[1]),x.match) for x in regexp_networks if x!=nothing])

    network_feeders = Dict()
    for (n, folder) in networks
        network_feeders[n] = collect(1:length(readdir("$ENWL_NETWORK_PATH/$folder")))
    end
    return network_feeders
end

const ENWL_NETWORK_FEEDERS = Dict(
    1  => [1, 2, 3, 4],
    2  => [1, 2, 3, 4, 5],
    3  => [1, 2, 3, 4, 5, 6],
    4  => [1, 2, 3, 4, 5, 6],
    5  => [1, 2, 3, 4, 5, 6, 7, 8],
    6  => [1, 2],
    7  => [1, 2, 3, 4, 5, 6, 7],
    8  => [1, 2],
    9  => [1, 2, 3, 4, 5, 6],
    10 => [1, 2, 3, 4, 5, 6],
    11 => [1, 2, 3, 4, 5],
    12 => [1, 2, 3],
    13 => [1, 2, 3, 4],
    14 => [1, 2, 3, 4, 5, 6],
    15 => [1, 2, 3, 4, 5, 6, 7],
    16 => [1, 2, 3, 4],
    17 => [1, 2, 3, 4, 5, 6, 7],
    18 => [1, 2, 3, 4, 5, 6, 7, 8, 9],
    19 => [1, 2, 3, 4, 5],
    20 => [1, 2, 3, 4, 5],
    21 => [1, 2, 3, 4, 5],
    22 => [1, 2, 3, 4, 5, 6],
    23 => [1, 2, 3, 4, 5],
    24 => [1, 2],
    25 => [1, 2, 3],
)
