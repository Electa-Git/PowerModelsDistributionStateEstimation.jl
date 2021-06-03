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

function build_measurement_function_array(data::Dict, variable_dict::Dict)

    functions = []
    ref_bus = [bus["index"] for (b, bus) in data["bus"] if bus["bus_type"]==3][1]

    for (m, meas) in data["meas"]
        add_h_function!(meas["var"], m, data, ref_bus, variable_dict, functions)
    end
    return functions
end

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