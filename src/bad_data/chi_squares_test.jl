"""
    exceeds_chi_squares_threshold(sol_dict::Dict, data::Dict; prob_false::Float64=0.05)

Standard bad data detection method that consists of performing a Chi squares analysis on the objective value, i.e.,
the sum of the residuals. The outcome of the analysis depends on the degrees of freedom of the problem, which are calculated calling
the `get_degrees_of_freedom` function (see below).

This function returns a Boolean. If `true`, there are probably bad data points, if `false` there probably are not.

Arguments:
- `sol_dict`: solution dictionary, i.e., the default output dictionary of state estimation calculations,
- `data`: data input of the state estimation calculations, used to calculate the degrees of freedom,
- `prob_false`: probability of errors allowed in the Chi squares test.
"""
function exceeds_chi_squares_threshold(sol_dict::Dict, data::Dict; prob_false::Float64=0.05)::Bool
    dof = get_degrees_of_freedom(data)
    chi2 = _DST.Chisq(dof)
    sol_dict["solution"]["objective"] >= quantile(chi2, 1-prob_false)
end
"""
    get_degrees_of_freedom(data::Dict)
Calculates the degrees of freedom of the state estimation problem.
These equal `m-n` where `m` is the number of measurements and `n` that of the variables.
In general, the system is fully described by the voltage variables of all its buses.
Each bus has two variables for each terminal: voltage angle and magnitude in polar form, real and imag part in rectangular form.
Thus, a three-phase bus has 6 variables, a single-phase bus has 2.
An exception to this are reference buses, i.e., those buses that have a fixed voltage angle that serves as a reference. It is assumed
that there is only one reference bus in the network, and therefore its 3 (if three-phase) or 1 (if single-phase) angle variables are removed
from the count of `n`.
Furthermore, since zero-injection buses are taken care of by equality constraints, these do not count as variables, and thus are not
included in the calculation of `n`, either. Zero-injection buses are defined as buses that have no loads or generators connected to it.
`m` is simply the sum of the measurements in `data["meas"]` where again, if a measurement refers to three phases `m+=3` else `m+=1`.
"""
function get_degrees_of_freedom(data::Dict)

    # TODO: for MV/LV add transformer buses to non-zero buses?
    ref_bus = [bus for (_,bus) in data["bus"] if bus["bus_type"] == 3]
    
    @assert length(ref_bus) == 1 "There is more than one reference bus, double-check model"
    
    load_buses = ["$(load["load_bus"])" for (_, load) in data["load"]] # buses with demand (incl. negative demand, i.e., generation passed as negative load)
    gen_slack_buses = ["$(gen["gen_bus"])" for (_, gen) in data["gen"]] # buses with generators, including the slackbus
    non_zero_inj_buses = unique(vcat(load_buses, gen_slack_buses))
    
    @assert !isempty(non_zero_inj_buses) "This network has no active connected component, no point doing state estimation"
    
    n = sum([length(bus["terminals"]) for (b, bus) in data["bus"] if b ∈ non_zero_inj_buses ])*2-length(ref_bus[1]["terminals"]) # system variables: two variables per bus (e.g., angle and magnitude) per number of phases on the bus minus the angle variable(s) of a ref bus, which are fixed
    m = sum([length(meas["dst"]) for (_, meas) in data["meas"]])
    @assert m-n > 0 "system underdetermined or just barely determined, cannot perform bad data detection with this method"
    
    return m-n

end