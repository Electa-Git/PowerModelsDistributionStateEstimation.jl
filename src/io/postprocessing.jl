################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################

## Error calculation
function convert_lifted_to_polar!(sol::Dict, name)
    if name == "w"
        for (_,bus) in sol["bus"]
            bus["vm"] = sqrt.(bus[name])
        end
    elseif name == "Wr"
        for (_,bus) in sol["bus"]
            bus["vm"] = [sqrt(bus[name][c,c]) for c in 1:size(bus[name])[1]]
        end
    end
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
"""
    calculate_voltage_magnitude_error_perphase(se_sol::Dict, pf_sol::Dict)
Like _PMDSE.calculate_voltage_magnitude_error(se_sol::Dict, pf_sol::Dict) but the errors
are per phase instead of the average values over the three pahses.
"""
function calculate_voltage_magnitude_error_perphase(se_result::Dict, pf_result::Dict)

    (haskey(se_result, "solution") && haskey(pf_result, "solution")) || return false
    pf_sol, se_sol = pf_result["solution"], se_result["solution"]

    # convert the voltage magnitude variable to polar space
    if haskey(pf_sol["bus"]["1"], "Wr") _PMDSE.convert_lifted_to_polar!(pf_sol, "Wr") end
    if haskey(se_sol["bus"]["1"], "Wr") _PMDSE.convert_lifted_to_polar!(se_sol, "Wr") end
    if haskey(pf_sol["bus"]["1"], "vr") _PMDSE.convert_rectangular_to_polar!(pf_sol) end
    if haskey(se_sol["bus"]["1"], "vr") _PMDSE.convert_rectangular_to_polar!(se_sol) end
    if haskey(pf_sol["bus"]["1"], "w")  _PMDSE.convert_lifted_to_polar!(pf_sol, "w") end
    if haskey(se_sol["bus"]["1"], "w")  _PMDSE.convert_lifted_to_polar!(se_sol, "w") end

    # determine the difference between the se and pf
    delta_1 = []
    delta_2 = []
    delta_3 = []
    for (b,bus) in pf_sol["bus"] for cond in 1:length(bus["vm"])
        if cond == 1
            push!(delta_1, abs(bus["vm"][cond]-se_sol["bus"][b]["vm"][cond]))
        elseif cond == 2
            push!(delta_2, abs(bus["vm"][cond]-se_sol["bus"][b]["vm"][cond]))
        else
            push!(delta_3, abs(bus["vm"][cond]-se_sol["bus"][b]["vm"][cond]))
        end
    end end

    return delta_1, delta_2, delta_3, maximum(delta_1), maximum(delta_2), maximum(delta_3), _STT.mean(delta_1), _STT.mean(delta_2), _STT.mean(delta_3)
end