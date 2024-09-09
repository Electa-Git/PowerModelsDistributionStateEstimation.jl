
abstract type SM_vmnpq end


#####################################################################

"specification of the state estimation problem for the IVR Flow formulation"
function build_mc_se(pm::_PMD.IVRENPowerModel)
    # Variables  
    _PMD.variable_mc_bus_voltage(pm, bounded = true)
    _PMD.variable_mc_branch_current(pm, bounded = true)
    variable_mc_load_current(pm, bounded = true)    
    _PMD.variable_mc_generator_current(pm, bounded = true)
    _PMD.variable_mc_transformer_current(pm, bounded = true)
    variable_mc_residual(pm, bounded = true)
    variable_mc_measurement(pm, bounded = false)

    # Constraints

    for i in _PMD.ids(pm, :bus)
        if i in _PMD.ids(pm, :ref_buses)
            _PMD.constraint_mc_voltage_reference(pm, i)  # vm is not fixed
        end
        _PMD.constraint_mc_voltage_absolute(pm, i)
        _PMD.constraint_mc_voltage_pairwise(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_voltage(pm, i)
        _PMD.constraint_mc_transformer_current(pm, i)
    end


    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_current_balance_se(pm, i)
    end

    for (i,meas) in _PMD.ref(pm, :meas)
        constraint_mc_residual(pm, i)
    end


    objective_mc_se(pm)
end




####################################################################
"only total current variables defined over the bus_arcs in PMD are considered: with no shunt admittance, these are
equivalent to the series current defined over the branches."
function variable_mc_branch_current(pm::_PMD.IVRENPowerModel; nw::Int=_IM.nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    # ADD MISSING SERIES CURRENT VARIABLES
end

function variable_mc_generator_current_se(pm::_PMD.IVRENPowerModel; nw::Int=_IM.nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    #NB: the difference with PowerModelsDistributions is that pg and qg expressions are not created
    _PMD.variable_mc_generator_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_generator_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end

"""
    variable_mc_load_current, IVR current equivalent of variable_mc_load
"""
function variable_mc_load_current(pm::_PMD.IVRENPowerModel; kwargs...)
    variable_mc_load_current_real(pm; kwargs...)
    variable_mc_load_current_imag(pm; kwargs...)
end


function variable_mc_load_current_real(pm::_PMD.IVRENPowerModel;
    nw::Int=_IM.nw_id_default, bounded::Bool=true, report::Bool=true)

    int_dim = Dict(i => _PMD._infer_int_dim_unit(load, false) for (i,load) in _PMD.ref(pm, nw, :load))

    crd_phases = _PMD.var(pm, nw)[:crd_phases] = Dict(i => JuMP.@variable(pm.model,
    [c in 1: int_dim[i]], base_name="$(nw)_crd_$(i)"
    #,start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "crd_start", c, 0.0)
    ) for i in _PMD.ids(pm, nw, :load)
    )

    _PMD.var(pm, nw)[:crd] = Dict()

    for i in _PMD.ids(pm, nw, :load)
        _PMD.var(pm, nw, :crd)[i] = _PMD._merge_bus_flows(pm, [crd_phases[i]..., -sum(crd_phases[i])], _PMD.ref(pm, nw, :load, i)["connections"])
    end

    crd = _PMD.var(pm, nw, :crd)

    report && _IM.sol_component_value(pm, :pmd, nw, :load, :crd, _PMD.ids(pm, nw, :load), crd)

end

function variable_mc_load_current_imag(pm::_PMD.IVRENPowerModel; nw::Int=_IM.nw_id_default, bounded::Bool=true, report::Bool=true, meas_start::Bool=false)


    int_dim = Dict(i => _PMD._infer_int_dim_unit(load, false) for (i,load) in _PMD.ref(pm, nw, :load))

    # Note: `cid_phases` is a Dict of variable reference for phases (no neutral) current variables
    cid_phases = _PMD.var(pm, nw)[:cid_phases] = Dict(i => JuMP.@variable(pm.model,
    [c in 1: int_dim[i]], base_name="$(nw)_cid_$(i)"
    #,start = _PMD.comp_start_value(_PMD.ref(pm, nw, :load, i), "cid_start", c, 0.0)
    ) for i in _PMD.ids(pm, nw, :load)
    )
    _PMD.var(pm, nw)[:cid] = Dict()
    
    for i in _PMD.ids(pm, nw, :load)
        _PMD.var(pm, nw, :cid)[i] = _PMD._merge_bus_flows(pm, [cid_phases[i]..., -sum(cid_phases[i])], _PMD.ref(pm, nw, :load, i)["connections"])
    end
    
    cid = _PMD.var(pm, nw, :cid)
report && _IM.sol_component_value(pm, :pmd, nw, :load, :cid, _PMD.ids(pm, nw, :load), cid)

end

function constraint_mc_generator_power_se(pm::_PMD.IVRENPowerModel, id::Int; nw::Int=_IM.nw_id_default, report::Bool=true, bounded::Bool=true)
    generator = _PMD.ref(pm, nw, :gen, id)
    bus =  _PMD.ref(pm, nw,:bus, generator["gen_bus"])

    N = length(generator["connections"])
    pmin = get(generator, "pmin", fill(-Inf, N))
    pmax = get(generator, "pmax", fill( Inf, N))
    qmin = get(generator, "qmin", fill(-Inf, N))
    qmax = get(generator, "qmax", fill( Inf, N))

    if get(generator, "configuration", WYE) == _PMD.WYE
        constraint_mc_generator_power_wye_se(pm, nw, id, bus["index"], generator["connections"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    else
        constraint_mc_generator_power_delta_se(pm, nw, id, bus["index"], generator["connections"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    end
end

"wye connected generator setpoint constraint for IVR formulation - SE adaptation"
function constraint_mc_generator_power_wye_se(pm::_PMD.IVRENPowerModel, nw::Int, id::Int, bus_id::Int, connections::Vector{Int}, pmin::Vector, pmax::Vector, qmin::Vector, qmax::Vector; report::Bool=true, bounded::Bool=true)
    vr =  _PMD.var(pm, nw, :vr, bus_id)
    vi =  _PMD.var(pm, nw, :vi, bus_id)
    crg =  _PMD.var(pm, nw, :crg, id)
    cig =  _PMD.var(pm, nw, :cig, id)

    if bounded
        for (idx, c) in enumerate(connections[1:end-1])
            if pmin[c]> -Inf
                JuMP.@constraint(pm.model, pmin[idx] .<= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if pmax[c]< Inf
                JuMP.@constraint(pm.model, pmax[idx] .>= vr[c]*crg[c]  + vi[c]*cig[c])
            end
            if qmin[c]>-Inf
                JuMP.@constraint(pm.model, qmin[idx] .<= vi[c]*crg[c]  - vr[c]*cig[c])
            end
            if qmax[c]< Inf
                JuMP.@constraint(pm.model, qmax[idx] .>= vi[c]*crg[c]  - vr[c]*cig[c])
            end
        end
    end
end




function constraint_mc_current_balance_se(pm::_PMD.IVRENPowerModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_loads::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    #NB only difference with pmd is crd_bus replaced by crd, and same with cid
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMD._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMD._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crd   = get(_PMD.var(pm, nw),   :crd, Dict()); _PMD._check_var_keys(crd, bus_loads, "real current", "load")
    cid   = get(_PMD.var(pm, nw),   :cid, Dict()); _PMD._check_var_keys(cid, bus_loads, "imaginary current", "load")
    crg   = get(_PMD.var(pm, nw),   :crg, Dict()); _PMD._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig, Dict()); _PMD._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(_PMD.var(pm, nw),   :crs, Dict()); _PMD._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(_PMD.var(pm, nw),   :cis, Dict()); _PMD._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(_PMD.var(pm, nw),  :crsw, Dict()); _PMD._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMD.var(pm, nw),  :cisw, Dict()); _PMD._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMD._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMD._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    Gs, Bs = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx, t) in ungrounded_terminals
        JuMP.@NLconstraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(crsw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(crs[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum(crd[d][t]         for (d, conns) in bus_loads if t in conns)
                                    - sum( Gs[idx,jdx]*vr[u] -Bs[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(cisw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(cis[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum(cid[d][t]         for (d, conns) in bus_loads if t in conns)
                                    - sum( Gs[idx,jdx]*vi[u] +Bs[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    )
    end
end









#####################################################################
###################### MEASUREMENT Variables
#####################################################################

"""
    variable_mc_measurement
checks for every measurement if the measured
quantity belongs to the formulation's variable space. If not, the function
`create_conversion_constraint' is called, that adds a constraint that
associates the measured quantity to the formulation's variable space.
"""
function variable_mc_measurement(pm::_PMD.IVRENPowerModel; nw::Int=_IM.nw_id_default, bounded::Bool=false)
    for i in _PMD.ids(pm, nw, :meas)
        msr_var = _PMD.ref(pm, nw, :meas, i, "var")
        cmp_id = _PMD.ref(pm, nw, :meas, i, "cmp_id")
        cmp_type = _PMD.ref(pm, nw, :meas, i, "cmp")
        connections = get_active_connections(pm, nw, cmp_type, cmp_id)
        if no_conversion_needed(pm, msr_var)
            #no additional variable is created, it is already by default in the formulation
        else
            cmp_type == :branch ? id = (cmp_id, _PMD.ref(pm,nw,:branch, cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch, cmp_id)["t_bus"]) : id = cmp_id
            if haskey(_PMD.var(pm, nw), msr_var)
                push!(_PMD.var(pm, nw)[msr_var], id => JuMP.@variable(pm.model,
                    [c in connections], base_name="$(nw)_$(String(msr_var))_$id"))
            else
                _PMD.var(pm, nw)[msr_var] = Dict(id => JuMP.@variable(pm.model,
                    [c in connections], base_name="$(nw)_$(String(msr_var))_$id"))
            end


            msr_type = assign_conversion_type_to_msr(pm, i, msr_var; nw=nw)

            create_conversion_constraint(pm, _PMD.var(pm, nw)[msr_var], msr_type; nw=nw)
        
        end
    end
end


############## constraints 


"""
    function constraint_mc_voltage_reference(
        pm::ExplicitNeutralModels,
        id::Int;
        nw::Int=nw_id_default,
        bounded::Bool=true,
        report::Bool=true,
    )

Imposes suitable constraints for the voltage at the reference bus
"""
function constraint_mc_voltage_reference(pm::_PMD.IVRENPowerModel, id::Int; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    bus = ref(pm, nw, :bus, id)
    terminals = bus["terminals"]
    grounded = bus["grounded"]
    constraint_mc_theta_ref(pm, id; nw=nw)
    # if haskey(bus, "va") && !haskey(bus, "vm")
    # elseif haskey(bus, "vm") && !haskey(bus, "va")
    #     constraint_mc_voltage_magnitude_fixed(pm, nw, id, bus["vm"], terminals, grounded)
    # elseif haskey(bus, "vm") && haskey(bus, "va")
    #     constraint_mc_voltage_fixed(pm, nw, id, bus["vm"], bus["va"], terminals, grounded)
    # end
end

################## CONVERSION FUNCTIONS 








#                                                                                  ↗  :vmn        ↗ Square(i, :bus, cmp_id, _PMD.ref(pm,nw,:bus,cmp_id)["index"], [:vi, :vr])
function create_conversion_constraint(pm::_PMD.IVRENPowerModel, original_var, msr::Square; nw=nw)
    new_var = []
    # prepare the :vi and :vr inside pm.model
    for nvn in msr.elements
        if msr.cmp_type == :branch
            push!(new_var, _PMD.var(pm, nw, nvn, (msr.cmp_id, _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"])))
        else
            push!(new_var, _PMD.var(pm, nw, nvn, msr.cmp_id))
        end
    end
    

    msr.cmp_type == :branch ? id = (msr.cmp_id,  _PMD.ref(pm,nw,:branch,msr.cmp_id)["f_bus"], _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)  # 1:4 for buses and branches while 1:3 for loads and gens by nature

    JuMP.@constraint(pm.model, [c in setdiff(conn,_N_IDX)],
    original_var[id][c]^2 == (sum( (n[c]- n[_N_IDX])^2 for n in new_var ))

    )

end

#                                                               ↗  :pd || :qd         ↗ Multiplication(msr, i,:load, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["load_bus"], [:crd, :cid], [:vr, :vi])
#                                                               ↗  :pg || :qg         ↗ Multiplication(msr, i,:gen, cmp_id, _PMD.ref(pm,nw,:gen,cmp_id)["gen_bus"], [:crg, :cig], [:vr, :vi])
function create_conversion_constraint(pm::_PMD.IVRENPowerModel, original_var, msr::Multiplication; nw=nw)

    m1 = []
    m2 = []

    for m in msr.mult1
        if occursin("v", String(m)) && msr.cmp_type != :bus
            push!(m1, _PMD.var(pm, nw, m, msr.bus_ind))
        elseif msr.cmp_type == :branch
            push!(m1, _PMD.var(pm, nw, m, (msr.cmp_id, msr.bus_ind, _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"])))
        else
            push!(m1, _PMD.var(pm, nw, m, msr.cmp_id))
        end
    end

    for mm in msr.mult2
        if occursin("v", String(mm)) && msr.cmp_type != :bus
            push!(m2, _PMD.var(pm, nw, mm, msr.bus_ind))
        elseif msr.cmp_type == :branch
            push!(m2, _PMD.var(pm, nw, mm, (msr.cmp_id, msr.bus_ind, _PMD.ref(pm, nw, :branch,msr.cmp_id)["t_bus"])))
        else
            push!(m2, _PMD.var(pm, nw, mm, msr.cmp_id))
        end
    end
    msr.cmp_type == :branch ? id = (msr.cmp_id,  msr.bus_ind, _PMD.ref(pm,nw,:branch,msr.cmp_id)["t_bus"]) : id = msr.cmp_id
    conn = get_active_connections(pm, nw, msr.cmp_type, msr.cmp_id)

    conn = setdiff(conn,_N_IDX)
    if occursin("p", String(msr.msr_sym))
        pcons = JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c] == m1[1][c]*(m2[1][c]-m2[1][_N_IDX])+m1[2][c]*(m2[2][c]-m2[2][_N_IDX])  #TODO: fix the Ur[c] - Ur[n] &  Ui[c] - Ui[n]
            )
            display(pcons)
    elseif occursin("q", String(msr.msr_sym))
        qcons= JuMP.@constraint(pm.model, [c in conn],
            original_var[id][c] == -m1[2][c]*(m2[1][c]-m2[1][_N_IDX])+m1[1][c]*(m2[2][c]-m2[2][_N_IDX])
            )
            display(qcons)
    end
end
