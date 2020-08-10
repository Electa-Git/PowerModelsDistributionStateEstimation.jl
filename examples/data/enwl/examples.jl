import PowerModelsDistribution
const PMD = PowerModelsDistribution
# Update this to the location of the enwl root folder in your system
path = "/Users/tvanacke/Downloads/enwl"
# Also update it in load_enwl.jl so it can return absolute paths correctly
include("$path/load_enwl.jl")
@assert(ENWL_ROOT_PATH==path) # check that paths match
include("$path/mod_enwl.jl")
##

dss_path = get_enwl_dss_path(10, 1)
data_eng = PMD.parse_file(dss_path, data_model=PMD.ENGINEERING)

# remove the MV/LV transformer if desired
@show keys(data_eng["transformer"])
rm_enwl_transformer!(data_eng)
@show keys(data_eng)

# simplify network topology if possible (highly recommended)
@show length(data_eng["line"])
reduce_lines_eng!(data_eng)
@show length(data_eng["line"])

# insert profiles
@show data_eng["load"]["load1"]["pd_nom"][1]
insert_profiles!(data_eng, "summer", ["load", "pv"], [0.95, 0.90], t=144)
@show data_eng["load"]["load1"]["pd_nom"][1]
insert_profiles!(data_eng, "summer", ["load"], [0.95], t=144)
@show data_eng["load"]["load1"]["pd_nom"][1]
