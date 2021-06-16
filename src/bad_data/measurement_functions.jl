function create_trigonometric_blocks(cmp_bus, ref_bus, t_buses, va_fr, va_to; extra_block_needed::Bool=false)

    vat = []
    vaf_ref = [0.0, -2.0943951023931953, 2.0943951023931953] # angle of reference buses
    vaf_block = cmp_bus == ref_bus ? (x, fc, fd) -> vaf_ref[fc] - vaf_ref[fd] : (x, fc, fd) -> x[va_fr["$fc"]] - x[va_fr["$fd"]]

    if cmp_bus == ref_bus
        vat_block = (x, fc, br, td, d, vat) -> vaf_ref[fc] - x[va_to[br]["$td"]]
        if extra_block_needed  extra_block = (x, fc) -> vaf_ref[fc] end
    elseif ref_bus ∈ t_buses
        for bus in t_buses
            bus != ref_bus ? push!(vat, (x, br, td) -> [x[va_to[br]["$td"]], x[va_to[br]["$td"]], x[va_to[br]["$td"]] ]) : push!(vat, (x, br, td) -> [0.0, -2.9044, 2.0944])
        end
        vat_block = (x, fc, br, td, d, vat) -> x[va_fr["$fc"]] - vat[br](x, br, td)[td]
        if extra_block_needed  extra_block = (x, fc) -> x[va_fr["$fc"]] end
    else
        vat_block = (x, fc, br, td, d, vat) -> x[va_fr["$fc"]] - x[va_to[br]["$td"]]
        if extra_block_needed  extra_block = (x, fc) -> x[va_fr["$fc"]] end
    end 
    extra_block_needed ? (return vaf_block, vat_block, vat, extra_block) : (return vaf_block, vat_block, vat)
end

function build_measurement_function_array(data::Dict, variable_dict::Dict)

    functions = []
    ref_bus = [bus["index"] for (_, bus) in data["bus"] if bus["bus_type"]==3][1]

    for (m, meas) in data["meas"]
        add_h_function!(meas["var"], m, data, ref_bus, variable_dict, functions)
    end
    return functions
end

function add_h_function!(qmeas::Symbol, m::String, data::Dict, ref_bus::Int64, variable_dict::Dict, functions::Array)

    meas = data["meas"][m]

    if qmeas ∈ [:pd, :qd, :pg, :qg, :p, :q]
        input = qmeas ∈ [:pd, :qd, :pg, :qg] ? build_multibranch_input(qmeas, meas, data, variable_dict) : build_singlebranch_input(meas, data, variable_dict)                 
        eval(Meta.parse(string(qmeas)[1]*"inj_function"))(functions, ref_bus, input[1], input[2], input[3], input[4], input[5], input[6], input[7], input[8], input[9], input[10], input[11], input[12], input[13])
    elseif qmeas ∈ [:cmd, :cmg, :cm]
        input = qmeas ∈ [:cmd, :cmg] ? build_multibranch_input(qmeas, meas, data, variable_dict) : build_singlebranch_input(meas, data, variable_dict)                
        cm_function(functions, ref_bus, input[1], input[2], input[3], input[4], input[5], input[6], input[7], input[8], input[9], input[10], input[11], input[12], input[13])
    elseif qmeas ∈ [:crd, :cid, :crg, :cig, :cr, :ci]
        input = qmeas ∈ [:crd, :cid, :crg, :cig] ? build_multibranch_input(qmeas, meas, data, variable_dict) : build_singlebranch_input(meas, data, variable_dict) 
        eval(Meta.parse(string(qmeas)[1:2]*"_function"))(functions, ref_bus, input[1], input[2], input[3], input[4], input[5], input[6], input[7], input[8], input[9], input[10], input[11], input[12], input[13])
    elseif qmeas ∈ [:vm, :va]
        v_bus = variable_dict[string(qmeas)]["$(meas["cmp_id"])"]
        for i in collect(keys(v_bus))
            push!(functions, x->x[v_bus["$i"]])
        end
    else
        error("Measured quantity $qmeas of measurement $m not recognized.")
    end
end
"""
Measurement function for both (active) power flow measurement and (reactive) power injections measurement
"""
function pinj_function(functions, ref_bus, cmp_bus, vm_fr, va_fr, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_to, va_to) 

    vaf_block, vat_block, vat = create_trigonometric_blocks(cmp_bus, ref_bus, t_buses, va_fr, va_to)

    br_func = Matrix{Any}(undef, (length(conn_branches), 3))
    for br in 1:length(conn_branches)
        for (c, (fc, _)) in enumerate(zip(f_conn[br], t_conn[br]))
            br_func[br, fc] = x-> (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$fc"]]^2 +
                                   sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf_block(x, fc, fd)) +
                                        (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf_block(x, fc, td)) 
                                        for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])) if d!=c; init=0 ) +
                                  sum( -g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vat_block(x, fc, br, td, d, vat)) 
                                       -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vat_block(x, fc, br, td, d, vat)) 
                                       for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])))
        end
    end
    for i in 1:size(br_func)[1]
        for j in 1:size(br_func)[2]
            if !isassigned(br_func, i, j) br_func[i,j] = x->0.0 end
        end
    end
    for c in 1:maximum([length(t_conn[br]) for br in 1:length(conn_branches)])
        if maximum([length(t_conn[br]) for br in 1:length(conn_branches)]) < 3
            fc = f_conn[1][c]
            push!(functions, x->sum([br_func[i,fc](x) for i in 1:size(br_func)[1]]))
        else
            push!(functions, x->sum([br_func[i,c](x) for i in 1:size(br_func)[1]]))
        end
    end
end
"""
Measurement function for both (reactive) power flow measurement and (reactive) power injections measurement
"""
function qinj_function(functions, ref_bus, cmp_bus, vm_fr, va_fr, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_to, va_to)
    
    vaf_block, vat_block, vat = create_trigonometric_blocks(cmp_bus, ref_bus, t_buses, va_fr, va_to)

    br_func = Matrix{Any}(undef, (length(conn_branches), 3))
    for br in 1:length(conn_branches)
        for (c, (fc, _)) in enumerate(zip(f_conn[br], t_conn[br])) 
            br_func[br, fc] = x-> ( -(b[br][c,c]+B_fr[br][c,c])*x[vm_fr["$fc"]]^2 
                                -sum( (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf_block(x, fc, fd))
                                        -(g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf_block(x, fc, fd)) 
                                        for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])) if d!=c; init=0 )
                                -sum( -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vat_block(x, fc, br, td, d, vat)) 
                                        +g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vat_block(x, fc, br, td, d, vat)) 
                                        for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])))
            )# closepush
        end
    end
    for i in 1:size(br_func)[1]
        for j in 1:size(br_func)[2]
            if !isassigned(br_func, i, j) br_func[i,j] = x->0.0 end
        end
    end
    for c in 1:maximum([length(t_conn[br]) for br in 1:length(conn_branches)])
        if maximum([length(t_conn[br]) for br in 1:length(conn_branches)]) < 3
            fc = f_conn[1][c]
            push!(functions, x->sum([br_func[i,fc](x) for i in 1:size(br_func)[1]]))
        else
            push!(functions, x->sum([br_func[i,c](x) for i in 1:size(br_func)[1]]))
        end
    end
end
"""
Current magnitude function
"""
function cm_function(functions, ref_bus, cmp_bus, vm_fr, va_fr, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_to, va_to)

    vaf_block, vat_block, vat = create_trigonometric_blocks(cmp_bus, ref_bus, t_buses, va_fr, va_to)

    br_func = Matrix{Any}(undef, (length(conn_branches), 3))
    for br in 1:length(conn_branches)
        for (c, (fc, _)) in enumerate(zip(f_conn[1], t_conn[1])) 
            br_func[br, fc] = x-> (sqrt(         # P^2
                                        ( -(b[br][c,c]+B_fr[br][c,c])*x[vm_fr["$fc"]]^2 
                                            -sum( (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf_block(x, fc, fd))
                                            -(g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf_block(x, fc, fd)) 
                                                for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])) if d!=c; init=0 )
                                            -sum( -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vat_block(x, fc, br, td, d, vat)) 
                                            +g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vat_block(x, fc, br, td, d, vat)) 
                                                for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br]))) )^2 +
                                                # Q^2
                                        ( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$fc"]]^2 +                        
                                            sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf_block(x, fc, fd)) +
                                                (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf_block(x, fc, fd)) 
                                                for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])) if d!=c; init=0 ) +
                                            sum( -g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vat_block(x, fc, br, td, d, vat)) 
                                                -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vat_block(x, fc, br, td, d, vat)) 
                                                for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br]))) )^2 ) 
                                                # / Vi
                                                / x[vm_fr["$fc"]] )
        end
    end
    for i in 1:size(br_func)[1]
        for j in 1:size(br_func)[2]
            if !isassigned(br_func, i, j) br_func[i,j] = x->0.0 end
        end
    end
    for c in 1:maximum([length(t_conn[br]) for br in 1:length(conn_branches)])
        if maximum([length(t_conn[br]) for br in 1:length(conn_branches)]) < 3
            fc = f_conn[1][c]
            push!(functions, x->sum([br_func[i,fc](x) for i in 1:size(br_func)[1]]))
        else
            push!(functions, x->sum([br_func[i,c](x) for i in 1:size(br_func)[1]]))
        end
    end
end
"""
Reactive current function
"""
function cr_function(functions, ref_bus, cmp_bus, vm_fr, va_fr, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_to, va_to)

    vaf_block, vat_block, vat, extra_block = create_trigonometric_blocks(cmp_bus, ref_bus, t_buses, va_fr, va_to, extra_block_needed = true)

    br_func = Matrix{Any}(undef, (length(conn_branches), 3))
    for br in 1:length(conn_branches)
        for (c, (fc, tc)) in enumerate(zip(f_conn[br], t_conn[br])) 
            br_func[br,fc] = x-> (          #  Q * sin(Θ)
                                        ( -(b[br][c,c]+B_fr[br][c,c])*x[vm_fr["$fc"]]^2 
                                        -sum( (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf_block(x, fc, fd))
                                        -(g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf_block(x, fc, fd)) 
                                            for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])) if d!=c; init=0 )
                                        -sum( -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vat_block(x, fc, br, td, d, vat)) 
                                        +g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vat_block(x, fc, br, td, d, vat)) 
                                            for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br]))))*sin(extra_block(x, fc))+
                                            # P * cos(Θ)
                                        ( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$fc"]]^2 +                        
                                        sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf_block(x, fc, fd)) +
                                            (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf_block(x, fc, fd)) 
                                            for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])) if d!=c; init=0 ) +
                                        sum( -g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vat_block(x, fc, br, td, d, vat)) 
                                            -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vat_block(x, fc, br, td, d, vat)) 
                                            for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br]))))*cos(extra_block(x, fc))
                                            # / |U|
                                            / x[vm_fr["$fc"]]  
                )
        end
    end
    for i in 1:size(br_func)[1]
        for j in 1:size(br_func)[2]
            if !isassigned(br_func, i, j) br_func[i,j] = x->0.0 end
        end
    end
    for c in 1:maximum([length(t_conn[br]) for br in 1:length(conn_branches)])
        if maximum([length(t_conn[br]) for br in 1:length(conn_branches)]) < 3
            fc = f_conn[1][c]
            push!(functions, x->sum([br_func[i,fc](x) for i in 1:size(br_func)[1]]))
        else
            push!(functions, x->sum([br_func[i,c](x) for i in 1:size(br_func)[1]]))
        end
    end
end

function ci_function(functions, ref_bus, cmp_bus, vm_fr, va_fr, conn_branches, f_conn, t_conn, g, b, G_fr, B_fr, t_buses, vm_to, va_to)

    vaf_block, vat_block, vat, extra_block = create_trigonometric_blocks(cmp_bus, ref_bus, t_buses, va_fr, va_to, extra_block_needed = true)
    
    br_func = Matrix{Any}(undef, (length(conn_branches), 3))
    for br in 1:length(conn_branches)
        for (c, (fc, tc)) in enumerate(zip(f_conn[br], t_conn[br])) 
            br_func[br,fc] = x-> (          #  - Q * cos(Θ)
                                - ( -(b[br][c,c]+B_fr[br][c,c])*x[vm_fr["$fc"]]^2 
                                -sum( (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf_block(x, fc, fd))
                                -(g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf_block(x, fc, fd)) 
                                    for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])) if d!=c; init=0 )
                                -sum( -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vat_block(x, fc, br, td, d, vat)) 
                                +g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vat_block(x, fc, br, td, d, vat)) 
                                    for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br]))))*cos(extra_block(x, fc))+
                                    # + P * sin(Θ)
                                ( (g[br][c,c]+G_fr[br][c,c])*x[vm_fr["$fc"]]^2 +                        
                                sum( (g[br][c,d]+G_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*cos(vaf_block(x, fc, fd)) +
                                    (b[br][c,d]+B_fr[br][c,d])*x[vm_fr["$fc"]]*x[vm_fr["$fd"]]*sin(vaf_block(x, fc, fd)) 
                                    for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br])) if d!=c; init=0 ) +
                                sum( -g[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*cos(vat_block(x, fc, br, td, d, vat)) 
                                    -b[br][c,d]*x[vm_fr["$fc"]]*x[vm_to[br]["$td"]]*sin(vat_block(x, fc, br, td, d, vat)) 
                                    for (d, (fd, td)) in enumerate(zip(f_conn[br], t_conn[br]))))*sin(extra_block(x, fc))
                                    # / |U|
                                    / x[vm_fr["$fc"]]  
                )
        end
    end
    for i in 1:size(br_func)[1]
        for j in 1:size(br_func)[2]
            if !isassigned(br_func, i, j) br_func[i,j] = x->0.0 end
        end
    end
    for c in 1:maximum([length(t_conn[br]) for br in 1:length(conn_branches)])
        if maximum([length(t_conn[br]) for br in 1:length(conn_branches)]) < 3
            fc = f_conn[1][c]
            push!(functions, x->sum([br_func[i,fc](x) for i in 1:size(br_func)[1]]))
        else
            push!(functions, x->sum([br_func[i,c](x) for i in 1:size(br_func)[1]]))
        end
    end
end