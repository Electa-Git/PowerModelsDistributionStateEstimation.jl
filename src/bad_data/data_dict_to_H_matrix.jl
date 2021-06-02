"""
function build_variable_dictionary(data::Dict)
    Builds a dictionary which is necessary to build the H matrix.
    This dictionary allows to pass the correct variables to each measurement function.     
"""
function build_variable_dictionary(data::Dict)

    bus_terms = [bus["terminals"] for (b, bus) in data["bus"]]
    ref_bus = [bus["index"] for (b, bus) in data["bus"] if bus["bus_type"]==3]
    @assert length(ref_bus) == 1 "There is more than one reference bus, double-check model"
    ref_bus_term = data["bus"]["$(ref_bus[1])"]["terminals"] 

    total_vm = sum(length.(bus_terms))
    total_va = sum(length.(bus_terms)) - length(ref_bus_term)

    variable_dict = Dict{String, Any}()
    variable_dict["vm"] = Dict{String, Any}()
    variable_dict["va"] = Dict{String, Any}()

    vmcount = 1
    for (b, bus) in data["bus"]
        variable_dict["vm"][b] = Dict{String, Any}()
        for i in 1:length(bus["terminals"])
            variable_dict["vm"][b]["$i"] = Dict{String, Any}()
            variable_dict["vm"][b]["$i"] = vmcount
            vmcount+=1
        end
    end

    vacount = total_vm+1
    for (b, bus) in data["bus"]
        if b != "$(ref_bus[1])"
            variable_dict["va"][b] = Dict{String, Any}()
            for i in 1:length(bus["terminals"])
                variable_dict["va"][b]["$i"] = Dict{String, Any}()
                variable_dict["va"][b]["$i"] = vacount
                vacount+=1
            end
        end
    end
    return variable_dict
end

add_zib_meas!(data)

function build_measurement_function_array(data::Dict, variable_dict::Dict)

    functions = []
    ref_bus = [bus["index"] for (b, bus) in data["bus"] if bus["bus_type"]==3][1]

    for (m, meas) in data["meas"]
        if meas["var"] == :pd
            load_bus = data["load"]["$(meas["cmp_id"])"]["load_bus"]
            vm_load_bus = variable_dict["vm"]["$load_bus"]
            va_load_bus = variable_dict["va"]["$load_bus"]
            for c in 1:length(vm_load_bus)
                B_i = adjacent_buses(load_bus, data) 
                vm_adj_bus, va_adj_bus = variables_adjacent_buses(B_i, variable_dict)
                if load_bus == ref_bus
                    va_ref = [0.0, -2.0944, 2.0944]
                    push!(functions, x->x[vm_load_bus["$c"]]*sum(sum(x[vm_adj_bus[j]["$d"]]*cos(va_ref[c] - x[va_adj_bus[j]["$d"]]) + sin(va_ref[c] - x[va_adj_bus[j]["$d"]]) for d in 1:length(va_adj_bus[j])) for j in 1:length(B_i)))
                elseif ref_bus ∈ B_i
                    arr = []
                    for bus in B_i
                        if bus != ref_bus
                            push!(arr, [x[vm_adj_bus[j]["$d"]], x[va_adj_bus[j]["$d"]], x[va_adj_bus[j]["$d"]]])
                        else
                            if c == 1 push!(arr, [:(x[vm_adj_bus[j]["$d"]]), 0.0, 0.0]) end
                            if c == 2 push!(arr, [:(x[vm_adj_bus[j]["$d"]]), -2.0944, -2.0944]) end
                            if c == 3 push!(arr, [:(x[vm_adj_bus[j]["$d"]]), 2.0944, 2.0944]) end
                        end
                    end
                    push!(functions, x->x[vm_load_bus["$c"]]*sum(sum(eval(arr_i[1])*cos(x[va_load_bus["$c"]] - eval(arr_i[2])) + sin(x[va_load_bus["$c"]] - eval(arr_i[3])) for arr_i in arr)))                
                else
                    push!(functions, x->x[vm_load_bus["$c"]]*sum(sum(x[vm_adj_bus[j]["$d"]]*cos(x[va_load_bus["$c"]] - x[va_adj_bus[j]["$d"]]) + sin(x[va_load_bus["$c"]] - x[va_adj_bus[j]["$d"]]) for d in 1:length(va_adj_bus[j])) for j in 1:length(B_i)))
                end
            end
        elseif meas["var"] ∈ [:vm, :va]
            bus = meas["cmp_id"]
            v_load_bus = variable_dict[string(meas["var"])]["$load_bus"]
            for i in 1:length(v_load_bus)
                push!(functions, x->x[v_load_bus["$i"]])
            end
        else
            error("Measured quantity of measurement $m not supported for bad data identification.")
        end
    end
    return functions
end

#TODO: G and B, other measurement quantities

function adjacent_buses(bus_idx::Int64, data::Dict)
    conn_branches = [b for (b, branch) in data["branch"] if (branch["f_bus"] == bus_idx || branch["t_bus"] == bus_idx)] 
    adj_buses = []
    for br in conn_branches
        push!(adj_buses, data["branch"][br]["f_bus"])
        push!(adj_buses, data["branch"][br]["t_bus"])
    end
    return (filter(x->x!=bus_idx, adj_buses) |> unique)
end

function variables_adjacent_buses(Bi::Array, variable_dict::Dict)
    vm_indices = []
    va_indices = []
    for bus in Bi
        push!(vm_indices, variable_dict["vm"]["$bus"])
        push!(va_indices, variable_dict["va"]["$bus"])
    end
    return vm_indices, va_indices
end