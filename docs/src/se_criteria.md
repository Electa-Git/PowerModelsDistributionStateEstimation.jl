# Mathematical Model of the State Estimation Criteria

The user needs to indicate in input data dictionary (see [Input Data Format](@ref)) what type of state estimation criteria should be used, i.e., what is the objective to minimize.
There are currently 5 possibilities:
`"wlav"`: performs a weighted least absolute value (WLAV) state estimation, in its full absolute value form. The absolute value is not continuously differentiable, so this criteria might cause convergence issues.
`"rwlav"`: is an exact linear relaxation of WLAV. It gives the same result, without computational issues
`"wls"`: is the standard weighted least squares state estimation. It is a quadratic function.
`"rwls"`: is a convex relaxation of WLS.
`"mle"`: performs a maximum likelihood estimation (MLE). It is a generalization of WLS and WLAV and can be used to include non-gaussian error distributions. See the mathematical description below.

The choice should be made by assigning the criterion in the data dictionary, as show below:
```julia
data["se_settings"] = Dict{String,Any}("criterion" => "rwlav")
```
A rescaler should also be assigned. This rescales the residual constraints in the optimization problem and can result in faster convergence. If the rescaler is exaggeratedly high/low, however, this could affect the quality of the solution. Recommended rescaler values are between 1 and 1000, the best value is problem specific.

```julia
data["se_settings"] = Dict{String,Any}("rescaler" => 100)
```
If criterion and/or rescaler are not provided, these default to `"rwlav"` and 1, respectively.

## WLAV and rWLAV

## WLS and rWLS

## MLE

Mention which pdfs are supported: Weibull, Normal, LogNormal, Beta, Gamma, Exponential
