function add_h_function!(qmeas::Symbol, m::String, data::Dict, ref_bus::Int64, variable_dict::Dict, functions::Array)
    if qmeas == :pd
        load_bus = data["load"]["$(meas["cmp_id"])"]["load_bus"]
        vm_load_bus = variable_dict["vm"]["$load_bus"]
        va_load_bus = variable_dict["va"]["$load_bus"]
        for c in 1:length(vm_load_bus)
            B_i = adjacent_buses(load_bus, data) 
            vm_adj_bus, va_adj_bus = variables_adjacent_buses(B_i, variable_dict)
            G,B = get_line_param(data, load_bus, B_i)
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
    elseif qmeas ∈ [:vm, :va]
        v_bus = variable_dict[string(qmeas)]["$(meas["cmp_id"])"]
        for i in 1:length(v_bus)
            push!(functions, x->x[v_bus["$i"]])
        end
    else
        error("Measured quantity of measurement $m not supported for bad data identification.")
    end
end