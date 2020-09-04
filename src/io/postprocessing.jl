################################################################################
#  Copyright 2020, Tom Van Acker, Marta Vanin                                  #
################################################################################
# PowerModelsDSSE.jl                                                           #
# An extention package of PowerModelsDistribution.jl for Static Distribution   #
# System State Estimation.                                                     #
# See http://github.com/timmyfaraday/PowerModelsDSSE.jl                        #
################################################################################

## Error calculation
convert_lifted_to_polar!(sol::Dict, name) =
        for (_,bus) in sol["bus"]
            bus["vm"] = sqrt.(bus[name])
        end

convert_rectangular_to_polar!(sol::Dict) =
    for (_,bus) in sol["bus"]
        bus["vm"] = sqrt.(bus["vi"].^2+bus["vr"].^2)
    end
"""
    calculate_voltage_magnitude_error(se_sol::Dict, pf_sol::Dict)

Function to determine the difference, maximum difference and mean difference
between the voltage magnitude on the busses between a power flow `pf_sol` and a
state estimation `se_sol`.
"""
function calculate_voltage_magnitude_error(se_result::Dict, pf_result::Dict)
    # check whether both se and pf have been solved
    (haskey(se_result, "solution") && haskey(pf_result, "solution")) || return false
    pf_sol, se_sol = pf_result["solution"], se_result["solution"]

    # convert the voltage magnitude variable to polar space
    if haskey(pf_sol["bus"]["1"], "Wr") convert_lifted_to_polar!(pf_sol, "Wr") end
    if haskey(se_sol["bus"]["1"], "Wr") convert_lifted_to_polar!(se_sol, "Wr") end
    if haskey(pf_sol["bus"]["1"], "vr") convert_rectangular_to_polar!(pf_sol) end
    if haskey(se_sol["bus"]["1"], "vr") convert_rectangular_to_polar!(se_sol) end
    if haskey(pf_sol["bus"]["1"], "w") convert_lifted_to_polar!(pf_sol, "w") end
    if haskey(se_sol["bus"]["1"], "w") convert_lifted_to_polar!(se_sol, "w") end

    # determine the difference between the se and pf
    delta = Float64[]
    for (b,bus) in pf_sol["bus"] for cond in 1:length(bus["vm"])
        push!(delta, abs(bus["vm"][cond]-se_sol["bus"][b]["vm"][cond]))
    end end

    return delta, maximum(delta), _STT.mean(delta)
end
