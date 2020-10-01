# Mathematical Model of the State Estimation Criteria

The user needs to indicate in input data dictionary (see [Input Data Format](@ref)) what type of state estimation criteria should be used, i.e., what is the objective to minimize.
There are currently 7 possible entries/possibilities:
"wlav": performs a weighted least absolute value (WLAV) state estimation, in its full absolute value form. The absolute value is not continuously differentiable, so this criteria might cause convergence issues.
"rwlav": is an exact linear relaxation of WLAV. It gives the same result, without computational issues
"wls": is the standard weighted least squares state estimation. It is a non-convex function.
"rwls": is a convex relaxation of WLS.
"mle": performs a maximum likelihood estimation (MLE). It is a generalization of WLS and WLAV and can be used to include non-gaussian error distributions. See the mathematical description below.
"mixed-rwlav": associates a MLE-type of residual to measurements whose pdf is not gaussian, and a rwlav residual to those which are.
"mixed-rwls": as above, with rwls instead of rwlav.

## WLAV and rWLAV

## WLS and rWLS

## Maximum Likelihood Estimation

Mention which pdfs are supported
