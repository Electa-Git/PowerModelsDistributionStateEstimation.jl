Ωᵢᵢ = Rᵢᵢ⋅Sᵢᵢ
S = I - K
K = H⋅G⁻¹⋅Hᵀ⋅R⁻¹

\Omega = S*R = R - H*G^(-1)*H^T

ref_bus = [bus for (_,bus) in data["bus"] if bus["bus_type"] == 3]
ref_bus_idx = [b for (b,bus) in data["bus"] if bus["bus_type"] == 3]
    
@assert length(ref_bus) == 1 "There is more than one reference bus, double-check model"

load_buses = ["$(load["load_bus"])" for (_, load) in data["load"]] # buses with demand (incl. negative demand, i.e., generation passed as negative load)
gen_slack_buses = ["$(gen["gen_bus"])" for (_, gen) in data["gen"]] # buses with generators, including the slackbus
NZIB = unique(vcat(load_buses, gen_slack_buses)) # non-zero-injection buses

@assert !isempty(non_zero_inj_buses) "This network has no active connected component, no point doing state estimation"

Θ = [:(Θ$(b)) for (b, bus) in data["bus"] if b != ref_bus_idx]
x⁰ = [] # is the variable vector

# is the measurement Jacobian 
dp_dvm
dp_dΘ
dq_dvm
dq_dΘ
dvm_dvm = 1
dvm_dΘ = 0