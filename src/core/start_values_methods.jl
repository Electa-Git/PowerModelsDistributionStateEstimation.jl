"""
assign_start_to_variables!(pmd_data) gives the measurement value in the pmd_data dictionary
        as a starting value to its associated variable.

assign_start_to_variables!(pmd_data, start_values_source) assigns starting values
        to the problem variables based on a dictionary where they are collected: start_values_source.
        This dictionary must have the form of a powerflow solution dictionary.
"""
function assign_start_to_variables!(pmd_data::Dict{String, Any})
    for (_,meas) in pmd_data["meas"]
        msr_cmp = string(meas["cmp"])
        cmp_id = string(meas["cmp_id"])
        msr_var = string(meas["var"])
        pmd_data[msr_cmp][cmp_id]["$(msr_var)_start"] = _DST.mean.(meas["dst"])
    end
end#assign_start_to_variables

function assign_start_to_variables!(pmd_data::Dict{String, Any}, start_values_source::Dict{String, Any})
    for (_,meas) in pmd_data["meas"]
        msr_cmp = string(meas["cmp"])
        cmp_id = string(meas["cmp_id"])
        msr_var = string(meas["var"])
        if haskey(start_values_source["solution"][msr_cmp][cmp_id], msr_var)
            pmd_data[msr_cmp][cmp_id]["$(msr_var)_start"] = start_values_source[msr_cmp][cmp_id][msr_var]
        else
            @warn "$(msr_var) is not in $(start_values_source), possible formulation mismatch"
        end
    end
end#assign_start_to_variables
