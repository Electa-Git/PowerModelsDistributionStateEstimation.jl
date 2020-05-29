using Statistics

# TODO: TOM: We should have an thourough discussion on which functionality we want to implement in this regard for v0.1, this should be driven from the features presented in literature.

function calculate_error(se_sol::Dict, pf_sol::Dict; vm_or_va = "vm")
    if haskey(se_sol, "solution")
        se_sol = se_sol["solution"]
    end
    if haskey(pf_sol, "solution")
        pf_sol = pf_sol["solution"]
    end

    if haskey(pf_sol["bus"]["1"], "vr")
        convert_rectangular_to_polar!(pf_sol["bus"])
    end
    if haskey(se_sol["bus"]["1"], "vr")
        convert_rectangular_to_polar!(se_sol["bus"])
    end
    diff = []
    for (b,bus) in pf_sol["bus"]
        for cond in 1:length(bus[vm_or_va])
            push!(diff, abs(bus[vm_or_va][cond]-se_sol["bus"][b][vm_or_va][cond]))
        end
    end
    return diff, maximum(diff), mean(diff)
end

function convert_rectangular_to_polar!(sol::Dict{String,Any})
    for (_,bus) in sol
        bus["vm"] = sqrt.(bus["vi"].^2+bus["vr"].^2)
        bus["va"] = [atan(bus["vi"][c]/bus["vr"][c]) for c in 1:3]
    end
    return sol
end
