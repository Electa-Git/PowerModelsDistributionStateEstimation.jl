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
        for i in bus["terminals"]
            variable_dict["vm"][b]["$i"] = Dict{String, Any}()
            variable_dict["vm"][b]["$i"] = vmcount
            vmcount+=1
        end
    end

    vacount = total_vm+1
    for (b, bus) in data["bus"]
        if b != "$(ref_bus[1])"
            variable_dict["va"][b] = Dict{String, Any}()
            for i in bus["terminals"]
                variable_dict["va"][b]["$i"] = Dict{String, Any}()
                variable_dict["va"][b]["$i"] = vacount
                vacount+=1
            end
        end
    end
    return variable_dict
end

function variables_of_buses(Bi::Array, variable_dict::Dict)
    vm_indices = []
    va_indices = []
    for bus in Bi
        push!(vm_indices, variable_dict["vm"]["$bus"])
        if haskey(variable_dict["va"], "$bus") push!(va_indices, variable_dict["va"]["$bus"]) end # if it is a ref bus, the key does not exist 
    end
    return vm_indices, va_indices
end
"""
Function to build multi branch input for the injection functions (as injections can occur at buses with multiple incoming/outcoming branches,
    which is not the case for 'flows', which only refer to a single branch )
"""
function build_multibranch_input(qmeas, meas, data, variable_dict)

    cmp_bus = occursin("g", string(qmeas)) ? data["gen"]["$(meas["cmp_id"])"]["gen_bus"] : data["load"]["$(meas["cmp_id"])"]["load_bus"]
    vm_cmp_bus = variable_dict["vm"]["$cmp_bus"]
    va_cmp_bus = haskey(variable_dict["va"], "$cmp_bus") ? variable_dict["va"]["$cmp_bus"] : Dict{String, Any}() # is empty if cmp_bus is the ref bus
    conn_branches = [branch for (_, branch) in data["branch"] if (branch["f_bus"] == cmp_bus || branch["t_bus"] == cmp_bus)] 
    g = []
    b = []
    G_fr = []
    B_fr = []
    t_buses = []
    f_conn = []
    t_conn = []
    for branch in conn_branches
        push!(g, _PMD.calc_branch_y(branch)[1])
        push!(b, _PMD.calc_branch_y(branch)[2])
        push!(G_fr, branch["g_fr"])
        push!(B_fr, branch["b_fr"])
        push!(t_buses, branch["t_bus"])
        push!(t_buses, branch["f_bus"])
        push!(f_conn, branch["f_connections"])
        push!(t_conn, branch["t_connections"])
    end
    t_buses = filter(x-> x!=cmp_bus, t_buses) |> unique
    vm_adj_bus, va_adj_bus = variables_of_buses(t_buses, variable_dict)
    return cmp_bus, vm_cmp_bus, va_cmp_bus, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_adj_bus, va_adj_bus
end
"""
Function to build single branch input for the flow measurement functions (as 'flows' only refer to a single branch, as opposed to
    injections, which can occur at buses with multiple incoming/outcoming branches)
"""
function build_singlebranch_input(meas, data, variable_dict)

    branch = data["branch"]["$(meas["cmp_id"])"]
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    vm_fr = variable_dict["vm"]["$f_bus"]
    va_fr = haskey(variable_dict["va"], "$f_bus") ? variable_dict["va"]["$f_bus"] : Dict{String, Any}() # is empty if cmp_bus is the ref bus
     
    g, b = _PMD.calc_branch_y(branch)
    G_fr = branch["g_fr"]
    B_fr = branch["b_fr"]

    vm_to, va_to = variables_of_buses([t_bus], variable_dict)
    return f_bus, vm_fr, va_fr, [1], [branch["f_connections"]], [branch["t_connections"]], [g], [b], [G_fr], [B_fr], t_bus, vm_to, va_to
end
"""
    Given a state estimation or powerflow result or similar dictionary `se_sol`, and the system variables `variable_dict`,
    this function builds an array with the numerical state of the system, e.g., variables in `variable_dict`
        are assigned a scalar that correspond to their value in `se_sol`.
        The resulting array has the same index order of that of `h_functions`.
"""
function build_state_array(sol_dict::Dict, variable_dict::Dict)
    state_length = sum( length(val) for (_, val) in variable_dict["vm"]) + sum( length(val) for (_, val) in variable_dict["va"])
    state_array = zeros(Float64, (state_length,) )
    for (key, val) in variable_dict["vm"]
        bus_idx = minimum([idx for (_, idx) in val])
        for i in 1:length(val)
            state_array[bus_idx+i-1] = sol_dict["solution"]["bus"][key]["vm"][i]
        end
    end
    for (key, val) in variable_dict["va"]
        bus_idx = minimum([idx for (_, idx) in val])
        for i in 1:length(val)
            state_array[bus_idx+i-1] = sol_dict["solution"]["bus"][key]["va"][i]
        end
    end
    return state_array
end
"""
    Given a state estimation or powerflow result or similar dictionary `se_sol`, and the system variables `variable_dict`,
    this function builds an array with the numerical state of the system, e.g., variables in `variable_dict`
        are assigned a scalar that correspond to their value in `se_sol`.
        The resulting array has the same index order of that of `h_functions`.
"""
function build_state_array(sol_dict::Dict, variable_dict::Dict)
    state_length = sum( length(val) for (_, val) in variable_dict["vm"]) + sum( length(val) for (_, val) in variable_dict["va"])
    state_array = zeros(Float64, (state_length,) )
    for (key, val) in variable_dict["vm"]
        bus_idx = minimum([idx for (_, idx) in val])
        for i in 1:length(val)
            state_array[bus_idx+i-1] = sol_dict["solution"]["bus"][key]["vm"][i]
        end
    end
    for (key, val) in variable_dict["va"]
        bus_idx = minimum([idx for (_, idx) in val])
        for i in 1:length(val)
            state_array[bus_idx+i-1] = sol_dict["solution"]["bus"][key]["va"][i]
        end
    end
    return state_array
end
"""
Adds "virtual" zero zib residuals to a state estimation solution dictionary `se_sol`.
The `data` dictionary must have measurement data for these zibs, which can be added 
    with _PMDSE.add_zib_virtual_meas!
"""
function add_zib_virtual_residuals!(se_sol::Dict, data::Dict)
    original_meas = [m for (m, meas) in se_sol["solution"]["meas"]]
    for (m, meas) in data["meas"]
        if m ∉ original_meas
            se_sol["solution"]["meas"][m] = Dict("res"=>zeros(length(meas["dst"])))
        end
    end
end