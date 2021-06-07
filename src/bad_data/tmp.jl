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
        for branch in conn_branches
            push!(g, _PMD.calc_branch_y(branch)[1])
            push!(b, _PMD.calc_branch_y(branch)[2])
            push!(G_fr, branch["g_fr"])
            push!(B_fr, branch["b_fr"])
            push!(t_buses, branch["t_bus"])
            push!(t_buses, branch["f_bus"])
        end
        t_buses = filter(x-> x!=cmp_bus, t_buses) |> unique
        vm_adj_bus, va_adj_bus = variables_of_buses(t_buses, variable_dict)
        
        sgn = occursin("g", string(qmeas)) ? -1 : +1
        eval(Meta.parse(string(qmeas)[1]*"inj_function"))(functions, ref_bus, cmp_bus, vm_cmp_bus, va_cmp_bus, conn_branches, g, b, G_fr, B_fr, t_buses, vm_adj_bus, va_adj_bus, sgn)

    elseif qmeas ∈ [:p, :q]
        #TODO
    elseif qmeas ∈ [:cm, :ca]
        #TODO
    elseif qmeas ∈ [:vm, :va]
        v_bus = variable_dict[string(qmeas)]["$(meas["cmp_id"])"]
        for i in 1:length(v_bus)
            push!(functions, x->x[v_bus["$i"]])
        end
    else
        error("Measured quantity of measurement $m not supported for bad data identification.")
    end
end

function pinj_function(functions, ref_bus, cmp_bus, vm_fr, va_fr, conn_branches, g, b, G_fr, B_fr, t_buses, vm_to, va_to, sgn)
    
    for c in 1:length(vm_fr) # 1 or 3 if single- or three-phase
        if cmp_bus == ref_bus
            vaf = [0.0, -2.0944, 2.0944]
            push!(functions, x-> sign(sgn)*(sum( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$c"]]^2 +
                                 sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$c"]]*x[vm_fr["$d"]]*cos(vaf[c] - vaf[d]) +
                                      (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$c"]]*x[vm_fr["$d"]]*sin(vaf[c] - vaf[d]) 
                                      for d in 1:length(va_to[br]) if d!=c ) +
                                 sum( -g[br][c,d]*x[vm_fr["$c"]]*x[vm_to[br]["$d"]]*cos(vaf[c] - x[va_to[br]["$d"]]) 
                                      -b[br][c,d]*x[vm_fr["$c"]]*x[vm_to[br]["$d"]]*sin(vaf[c] - x[va_to[br]["$d"]]) 
                                      for d in 1:length(va_to[br]))
                    for br in 1:length(conn_branches) ) #closes sum over br
                ))# close sign and push
        elseif ref_bus ∈ t_buses

            vat = []
            for bus in t_buses
                bus != ref_bus ? push!(vat, :([x[va_to[br]["$d"]], x[va_to[br]["$d"]], x[va_to[br]["$d"]]])) : push!(vat, :([0.0, -2.9044, 2.0944]))
            end

            push!(functions, x-> sign(sgn)*(sum( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$c"]]^2 +
                                 sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$c"]]*x[vm_fr["$d"]]*cos(x[va_fr["$c"]] - x[va_fr["$d"]]) +
                                      (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$c"]]*x[vm_fr["$d"]]*sin(x[va_fr["$c"]] - x[va_fr["$d"]]) 
                                    for d in 1:length(va_fr[br]) if d!=c ) +
                                 sum( -g[br][c,d]*x[vm_fr["$c"]]*x[vm_to[br]["$d"]]*cos(x[va_fr["$c"]] - vat[br][d]) 
                                      -b[br][c,d]*x[vm_fr["$c"]]*x[vm_to[br]["$d"]]*sin(x[va_fr["$c"]] - vat[br][d]) 
                                    for d in 1:length(va_fr[br]))
                    for br in 1:length(conn_branches) ) #closes sum over br
                ))# close sign and push
        else
            push!(functions, x-> sign(sgn)*(sum( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$c"]]^2 +
                                 sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$c"]]*x[vm_fr["$d"]]*cos(x[va_fr["$c"]] - x[va_fr["$d"]]) +
                                      (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$c"]]*x[vm_fr["$d"]]*sin(x[va_fr["$c"]] - x[va_fr["$d"]]) 
                                      for d in 1:length(va_to[br]) if d!=c ) +
                                 sum( -g[br][c,d]*x[vm_fr["$c"]]*x[vm_to[br]["$d"]]*cos(x[va_fr["$c"]] - x[va_to[br]["$d"]]) 
                                      -b[br][c,d]*x[vm_fr["$c"]]*x[vm_to[br]["$d"]]*sin(x[va_fr["$c"]] - x[va_to[br]["$d"]]) 
                                      for d in 1:length(va_to[br]))
                    for br in 1:length(conn_branches) ) #closes sum over br
                ))# close sign and push
        end
    end
end

function p_function(; push::Bool=true)
    JuMP.@NLconstraint(pm.model, p_fr[fc] == (G[idx,idx]+G_fr[idx,idx])*vm_fr[fc]^2
    +sum( (G[idx,jdx]+G_fr[idx,jdx]) * vm_fr[fc]*vm_fr[fd]*cos(va_fr[fc]-va_fr[fd])
         +(B[idx,jdx]+B_fr[idx,jdx]) * vm_fr[fc]*vm_fr[fd]*sin(va_fr[fc]-va_fr[fd])
        for (jdx, (fd,td)) in enumerate(zip(f_connections,t_connections)) if idx != jdx)
    +sum( -G[idx,jdx]*vm_fr[fc]*vm_to[td]*cos(va_fr[fc]-va_to[td])
          -B[idx,jdx]*vm_fr[fc]*vm_to[td]*sin(va_fr[fc]-va_to[td])
        for (jdx, (fd,td)) in enumerate(zip(f_connections,t_connections)))
    )
end #p_function

function q_function()
    JuMP.@NLconstraint(pm.model, q_fr[fc] == -(B[idx,idx]+B_fr[idx,idx])*vm_fr[fc]^2
    -sum( (B[idx,jdx]+B_fr[idx,jdx])*vm_fr[fc]*vm_fr[fd]*cos(va_fr[fc]-va_fr[fd])
         -(G[idx,jdx]+G_fr[idx,jdx])*vm_fr[fc]*vm_fr[fd]*sin(va_fr[fc]-va_fr[fd])
        for (jdx, (fd,td)) in enumerate(zip(f_connections,t_connections)) if idx != jdx)
    -sum(-B[idx,jdx]*vm_fr[fc]*vm_to[td]*cos(va_fr[fc]-va_to[td])
         +G[idx,jdx]*vm_fr[fc]*vm_to[td]*sin(va_fr[fc]-va_to[td])
        for (jdx, (fd,td)) in enumerate(zip(f_connections,t_connections)))
)
end #q_function