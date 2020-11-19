################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
"""
    assign_start_to_variables!(data)

This function gives the measurement value in the data dictionary
as a starting value to its associated variable.
"""
function assign_start_to_variables!(data::Dict{String, Any})
    for (_,meas) in data["meas"]
        msr_cmp = string(meas["cmp"])
        cmp_id = string(meas["cmp_id"])
        msr_var = string(meas["var"])
        if msr_var != "w"
            data[msr_cmp][cmp_id]["$(msr_var)_start"] = _DST.mean.(meas["dst"])
        else
            data[msr_cmp][cmp_id]["$(msr_var)_start"] = _DST.mean.(meas["dst"])[1]
        end
    end
end

"""
    assign_start_to_variables!(data, start_values_source)

This function assigns start values to the problem variables based on a dictionary where they are collected: start_values_source.
This dictionary must have the form of a powerflow solution dictionary.
"""
function assign_start_to_variables!(data::Dict{String, Any}, start_values_source::Dict{String, Any})
    for (_,meas) in data["meas"]
        msr_cmp = string(meas["cmp"])
        cmp_id = string(meas["cmp_id"])
        msr_var = string(meas["var"])
        if haskey(start_values_source["solution"][msr_cmp][cmp_id], msr_var)
            if msr_var != "w"
                data[msr_cmp][cmp_id]["$(msr_var)_start"] = start_values_source[msr_cmp][cmp_id][msr_var]
            else
                data[msr_cmp][cmp_id]["$(msr_var)_start"] = start_values_source[msr_cmp][cmp_id][msr_var][1]
            end
        else
            Memento.warn(_LOGGER, "$(msr_var) is not in $(start_values_source), possible formulation mismatch")
        end
    end
end
