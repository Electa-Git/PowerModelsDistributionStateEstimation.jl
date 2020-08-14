"""
"""

function generate_power_meas_at_loadbuses(meas_nr::Int64, pmd_data::Dict{String,Any}, pf_result::Dict{String, Any}, case_name::String; choose_distribution::String="Normal", distribution_param::Float64=0.001)

    df = DataFrames.DataFrame( meas_id = Int64[], cmp_type = String[], cmp_id = Int64[], meas_type = String[], meas_var = String[],
                               phase = String[], dst = String[], val = String[], sigma = String[] )

    for (l,load) in pf_result["solution"]["load"]

        string(pmd_data["load"][l]["configuration"]) == "WYE" ? conf = "G" : conf = "P"
        if length(pmd_data["load"][l]["connections"]) > 2
            phases = "[1, 2, 3]"
            sigma = "[$distribution_param, $distribution_param, $distribution_param]"
            pd =  load["pd"]
            qd =  load["qd"]
        else
            phases = pmd_data["load"][l]["connections"][1]
            sigma = distribution_param
            pd =  load["pd"][phases]
            qd =  load["qd"][phases]
        end

        push!( df, [meas_nr,"load",parse(Int64, l), conf,"pd",string(phases), "Normal", string(pd), string(sigma)] )
        push!( df, [meas_nr+1,"load",parse(Int64, l), conf,"qd",string(phases), "Normal", string(qd), string(sigma)] )
        meas_nr+=2
    end
    CSV.write("test/data/$(case_name)_loadpower.csv", df)
end

function generate_voltage_meas_at_loadbuses(meas_nr::Int64, pmd_data::Dict{String,Any}, pf_result::Dict{String, Any}, case_name::String; choose_distribution::String="Normal", distribution_param::Float64=0.001)

    df = DataFrames.DataFrame( meas_id = Int64[], cmp_type = String[], cmp_id = Int64[], meas_type = String[], meas_var = String[],
                               phase = String[], dst = String[], val = String[], sigma = String[] )

    for (l,load) in pf_result["solution"]["load"]

       load_bus = pmd_data["load"][l]["load_bus"]
       sum(pmd_data["bus"]["$load_bus"]["grounded"]) >= 1 ? conf = "G" : conf = "P"
       phases = "[1, 2, 3]"
       sigma = "[$distribution_param, $distribution_param, $distribution_param]"
       vm =   pf_result["solution"]["bus"]["$load_bus"]["vm"]
       push!( df, [meas_nr,"bus",load_bus, conf,"vm",string(phases), "Normal", string(vm), string(sigma)] )
       meas_nr+=1
    end
    CSV.write("test/data/$(case_name)_loadbus_vm.csv", df)
end

#NB: the functions commented out below can be used to generate data from the original bus numbering. not sure it still makes sense..?
# function generate_load_meas(meas_nr::Int64, case_name::String, original_case_buses::Array; choose_distribution::String="Normal", distribution_param::Float64=0.001)
#     #NB IEEE123 buses with loads: [1,4,5, 6,7,9, 16, 17,19,2,12,10,11,20,22,24,28,29,30,31,32,34,35,38,33,37,39,41,42,43,45,46,49,50,51,52,53,55,56,58,60,62,63,64,65,68,69,70,73,74,76,77,80,82,84,86,87,96,92,90,88,94,95,98,99,100,102,103,106,109,112,83,79,85,59,75,71,104,107,111,113,114,66]
#     @assert case_name*"_pmd.dss" ∈ readdir("test/data/opendss") "The chosen test case is not among the available dss data files"
#     case_file = "test/data/opendss/"*case_name*"_pmd.dss"
#     data = _PMD.parse_file(case_file)
#     pmd_data = _PMD.transform_data_model(data)
#     df = DataFrames.DataFrame( meas_id = Int64[], cmp_type = String[], cmp_id = Int64[], meas_type = String[], meas_var = String[],
#                                phase = String[], dst = String[], val = String[], sigma = String[] )
#     for ocb in original_case_buses
#         conn = []
#         for entry in pmd_data["map"][2:end]
#             if occursin("s"*string(ocb), entry["from"])
#                 push!(conn, entry["to"][6:end])
#             end
#         end
#         for cn in conn
#             if length(pmd_data["load"][cn]["connections"]) > 2
#                 phases = "[1, 2, 3]"
#                 pd = string(pmd_data["load"][cn]["pd"])
#                 qd = string(pmd_data["load"][cn]["qd"])
#                 sigma = "[$distribution_param, $distribution_param, $distribution_param]"
#             else
#                 phases = pmd_data["load"][cn]["connections"][1]
#                 pd = pmd_data["load"][cn]["pd"][phases]
#                 qd = pmd_data["load"][cn]["qd"][phases]
#                 sigma = distribution_param
#             end
#             meas_type = pmd_data["load"][cn]["configuration"] == WYE ? "G" : "P"
#             push!( df, [meas_nr,"load",parse(Int64, cn), meas_type,"pd",string(phases), "Normal", string(pd), string(sigma)] )
#             push!( df, [meas_nr+1,"load",parse(Int64, cn), meas_type,"qd",string(phases), "Normal", string(qd), string(sigma)] )
#             meas_nr+=2
#         end
#     end #original case buses
#     df_tosave = unique(df,[:cmp_id, :meas_var])
#     CSV.write("test/data/$(case_name)_load.csv", df_tosave)
# end#generate_measurement_csv
#

# function generate_voltage_meas_at_loadbuses(meas_nr::Int64, case_name::String, original_case_buses::Array, pf_result::Dict; choose_distribution::String="Normal", distribution_param::Float64=0.001)
#     #NB IEEE123 buses with loads: [1,4,5, 6,7,9, 16, 17,19,2,12,10,11,20,22,24,28,29,30,31,32,34,35,38,33,37,39,41,42,43,45,46,49,50,51,52,53,55,56,58,60,62,63,64,65,68,69,70,73,74,76,77,80,82,84,86,87,96,92,90,88,94,95,98,99,100,102,103,106,109,112,83,79,85,59,75,71,104,107,111,113,114,66]
#     @assert case_name*"_pmd.dss" ∈ readdir("test/data/opendss") "The chosen test case is not among the available dss data files"
#     case_file = "test/data/opendss/"*case_name*"_pmd.dss"
#     data = _PMD.parse_file(case_file)
#     pmd_data = _PMD.transform_data_model(data)
#     df = DataFrames.DataFrame( meas_id = Int64[], cmp_type = String[], cmp_id = Int64[], meas_type = String[], meas_var = String[],
#                                phase = String[], dst = String[], val = String[], sigma = String[] )
#     for ocb in original_case_buses
#         conn = []
#         for entry in pmd_data["map"][2:end]
#             if string(ocb) == entry["from"]
#                 push!(conn, entry["to"][5:end])
#             end
#         end
#         for cn in conn
#             phases = "[1, 2, 3]"
#             vm = string(pf_result["bus"][cn]["vm"])
#             sigma = "[$distribution_param, $distribution_param, $distribution_param]"
#             meas_tpye = sum(pmd_data["bus"][cn]["grounded"]) == 0 ? "G" : "P"
#             push!( df, [meas_nr,"bus",parse(Int64, cn), meas_type,"vm",string(phases), "Normal", string(vm), string(sigma)] )
#             meas_nr+=1
#         end
#     end #original case buses
#     CSV.write("test/data/$(case_name)_loadbus.csv", df)
# end#generate_measurement_csv
