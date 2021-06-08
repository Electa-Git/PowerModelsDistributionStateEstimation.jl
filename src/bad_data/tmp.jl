function add_h_function!(qmeas::Symbol, m::String, data::Dict, ref_bus::Int64, variable_dict::Dict, functions::Array)

    meas = data["meas"][m]

    if qmeas ∈ [:pd, :qd, :pg, :qg]

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
        
        eval(Meta.parse(string(qmeas)[1]*"inj_function"))(functions, ref_bus, cmp_bus, vm_cmp_bus, va_cmp_bus, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_adj_bus, va_adj_bus)

    elseif qmeas ∈ [:p, :q]
        
        branch = data["branch"]["$(meas["cmp_id"])"]
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        vm_fr = variable_dict["vm"]["$f_bus"]
        va_fr = haskey(variable_dict["va"], "$f_bus") ? variable_dict["va"]["$f_bus"] : Dict{String, Any}() # is empty if cmp_bus is the ref bus
         
        g, b = _PMD.calc_branch_y(branch)
        G_fr = branch["g_fr"]
        B_fr = branch["b_fr"]

        vm_to, va_to = variables_of_buses(t_bus, variable_dict)

        eval(Meta.parse(string(qmeas)[1]*"inj_function"))(functions, ref_bus, f_bus, vm_fr, va_fr, [1], branch["f_connections"], branch["t_connections"], g, b, G_fr, B_fr, t_bus, vm_to, va_to)

    elseif qmeas ∈ [:cm, :ca]
        #TODO
    elseif qmeas ∈ [:vm, :va]
        v_bus = variable_dict[string(qmeas)]["$(meas["cmp_id"])"]
        for i in collect(keys(v_bus))
            push!(functions, x->x[v_bus["$i"]])
        end
    else
        error("Measured quantity of measurement $m not supported for bad data identification.")
    end
end

function pinj_function(functions, ref_bus, cmp_bus, vm_fr, va_fr, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_to, va_to)
    
    for (c, (fc, _)) in enumerate(zip(f_conn[1], t_conn[1])) # 1 or 3 if single- or three-phase
        if cmp_bus == ref_bus
            vaf = [0.0, -2.0943951023931953, 2.0943951023931953]
            push!(functions, x-> sum( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$fc"]]^2 +
                                 sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf[fc] - vaf[fd]) +
                                      (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf[fc] - vaf[fd]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])) if d!=c; init=0 ) +
                                 sum( -g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vaf[fc] - x[va_to[br]["$td"]]) 
                                      -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vaf[fc] - x[va_to[br]["$td"]]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])))
                    for br in 1:length(conn_branches) ) #closes sum over br
                )# close push

        elseif ref_bus ∈ t_buses

            vat = []
            for bus in t_buses
                bus != ref_bus ? push!(vat, :([x[va_to[br]["$d_term"]], x[va_to[br]["$d_term"]], x[va_to[br]["$d_term"]]])) : push!(vat, :([0.0, -2.9044, 2.0944]))
            end

            push!(functions, x-> sum( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$fc"]]^2 +
                                 sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(x[va_fr["$fc"]] - x[va_fr["$fd"]]) +
                                      (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(x[va_fr["$fc"]] - x[va_fr["$fd"]]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])) if d!=c; init=0 ) +
                                 sum( -g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(x[va_fr["$fc"]] - vat[br][td]) 
                                      -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(x[va_fr["$fc"]] - vat[br][td]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])))
                    for br in 1:length(conn_branches) ) #closes sum over br
                )# close push
        else
            push!(functions, x-> sum( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$fc"]]^2 +
                                 sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(x[va_fr["$fc"]] - x[va_fr["$fd."]]) +
                                      (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(x[va_fr["$fc"]] - x[va_fr["$fd"]]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])) if d!=c; init=0 ) +
                                 sum( -g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(x[va_fr["$fc"]] - x[va_to[br]["$td"]]) 
                                      -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(x[va_fr["$fc"]] - x[va_to[br]["$td"]]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])))
                    for br in 1:length(conn_branches) ) #closes sum over br
                )# closepush
        end
    end
end

function qinj_function(functions, ref_bus, cmp_bus, vm_fr, va_fr, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_to, va_to)
    
    for (c, (fc, _)) in enumerate(zip(f_conn[1], t_conn[1])) 
        if cmp_bus == ref_bus
            vaf = [0.0, -2.0944, 2.0944]
            push!(functions, x-> sum( -(b[br][c,c]+B_fr[br][c,c])*x[vm_fr["$fc"]]^2 -
                                 sum( (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf[fc] - vaf[fd]) -
                                      (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf[fc] - vaf[fd]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])) if d!=c; init=0 ) -
                                 sum( -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vaf[fc] - x[va_to[br]["$td"]]) 
                                      +g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vaf[fc] - x[va_to[br]["$td"]]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])))
                    for br in 1:length(conn_branches) ) #closes sum over br
                )# closepush
        elseif ref_bus ∈ t_buses

            vat = []
            for bus in t_buses
                bus != ref_bus ? push!(vat, :([x[va_to[br]["$td"]], x[va_to[br]["$td"]], x[va_to[br]["$td"]]])) : push!(vat, :([0.0, -2.9044, 2.0944]))
            end

            push!(functions, x-> sum( -(b[br][c,c]+B_fr[br][c,c])*x[vm_fr["$fc"]]^2 -
                                 sum( (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(x[va_fr["$fc"]] - x[va_fr["$fd"]]) -
                                      (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(x[va_fr["$fc"]] - x[va_fr["$fd"]]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])) if d!=c; init=0 ) -
                                 sum( -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(x[va_fr["$fc"]] - vat[br][td]) 
                                      +g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(x[va_fr["$fc"]] - vat[br][td]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])))
                    for br in 1:length(conn_branches) ) #closes sum over br
                )# close push
        else
            push!(functions, x-> sum( -(b[br][c,c]+B_fr[br][c,c])*x[vm_fr["$fc"]]^2 -
                                 sum( (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(x[va_fr["$fc"]] - x[va_fr["$fd"]]) -
                                      (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(x[va_fr["$fc"]] - x[va_fr["$fd"]]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])) if d!=c; init=0 ) -
                                 sum( -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(x[va_fr["$fc"]] - x[va_to[br]["$td"]]) 
                                      +g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(x[va_fr["$fc"]] - x[va_to[br]["$td"]]) 
                                      for (d, (fd, td)) in enumerate(zip(f_conn[1], t_conn[br])))
                    for br in 1:length(conn_branches) ) #closes sum over br
                )# close push
        end
    end
end