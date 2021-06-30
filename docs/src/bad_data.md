# Bad Data Detection and Identification

As of version 0.4.0, PMDSE has bad data detection and identification functionalities, namely:
- Chi-square test,
- Largest normalized residuals,
- Least absolute value (LAV) estimator residual analysis.

The LAV is a robust estimator that presents bad data rejection properties. LAV residuals can be collected and sorted, and the measurements with higher 
residuals are the ones of the bad data points.
The LAV residual analysis can be done with all previous versions of the package too, but is made easier in v0.4.0: in versions up to 0.4.0 the user
needs to pass `wlav` or `rwlav` as a state estimation criterion, and assign a unitary standard deviation for all weights or all measurements. Now it is sufficient to 
pass `lav` as a state estimation criterion.

All these three techniques are very standard techniques, and a thorough theoretical discussion can be found in the well-known book: "Power system state estimation - Theory and implementation" by A. Abur and A. G. Exposito. Furthermore, numerous papers also address in which circumstances the different techniques are more or less effective.

Below, just a functional introduction.

First of all,
- Bad data *detection* consists of answering the yes/no question: "is there bad data"?
- Bad data *identification* consists of locating which data points are bad (to subsequently correct them or delete them).

All the presented techniques require the user to first run a state estimation algorithm, as they are based on the analysis of its residuals.

## Chi-square Analysis 

Chi-squares ($\Chi^2$) analysis is a bad data *detection* method. If bad data are detected, these still need to be identified.

The method is based on the following assumptions: if all measurement errors follow a Normal distribution, and there are no bad data, then the sum of the weighted squared residuals follows a Chi-square distributions with *m-n* degrees of freedom, where *m* is the number of measurements and *n* of the system variables.

The function `exceeds_chi_squares_threshold` takes as input the solution of a state estimation calculation and the data dictionary. It calculates the degrees of freedom and the sum of the weighted square residuals (where the weights are the inverse of each measurement's variance). If the state estimation that was run was a `wls` estimation with no weight rescaler, this sum corresponds to the objective value. However, the function always calculates the sum, to allow the user to use Chi-square calculations in combination with measurement rescalers or other state estimation criteria.
```@docs 
PowerModelsDistributionStateEstimation.exceeds_chi_squares_threshold(sol_dict::Dict, data::Dict; prob_false::Float64=0.05, suppress_display::Bool=false)
```
The function returns a boolean that states whether bad data are suspected, the value of the sum of the residuals and the threshold value above which bad data are suspected.
The threshold value depends on the degrees of freedom and the detection confidence probability, that cab=n be set by the user. The default value of the latter is 0.05, as this is often the choice in the literature. 

## Largest Normalized Residuals

Normalized residuals can be used for both bad data *detection* and *identification*. Let the residuals be $r_i = h_i(\mathbf{x}) - \mathbf{z}$, where $h$ are the measurement functions, $\mathbf{x}$ are the system variables and $\mathbf{z}$ is the measurement vector. This is often the standard notation, e.g., in the book by Abur and Exposito.
The normalized residuals $r^N_i$ are:

```math
\begin{align}
&r_i^N = \frac{|r_i|}{\sqrt{\Omega_{ii}}} = \frac{|r_i|}{\sqrt{R_{ii}S_{ii}}}
\end{align}
```
The largest $r^N$ is compared to a threshold, typically 3.0 in the literature. If its value exceeds the threshold, bad data are suspected, and the bad data point is identified as the measurement that corresponds to the largest $r^N$ itself.
This package contains different functions that allow to build the measurement matrix (H), the measurement error covariance matrix (R), the gain matrix (G), the hat matrix (K), the sensitivity matrix (S) and the residual covariance matrix ($\Omega$):
```@docs 
PowerModelsDistributionStateEstimation.build_H_matrix(functions::Vector, state::Array)::Matrix{Float64}
```
```@docs 
build_G_matrix(H::Matrix, R::Matrix)::Matrix{Float64}
```
```@docs 
build_R_matrix(data::Dict)::Matrix{Float64}
```
```@docs 
build_omega_matrix(R::Matrix{Float64}, H::Matrix{Float64}, G::Matrix{Float64})
```
```@docs 
build_omega_matrix(S::Matrix{Float64}, R::Matrix{Float64}) 
```
```@docs 
build_S_matrix(K::Matrix{Float64})
```
```@docs 
build_K_matrix(H::Matrix{Float64}, G::Matrix{Float64}, R::Matrix{Float64})
```
$\Omega$ can then be used in the function `normalized_residuals`, which calculates all $r_i$, returns the highest $r^N$ and indicates whether its value exceeds the threshold or not.
Again, the $r_i$ calculation is independent of the chosen state estimation criterion or weight rescaler.
```@docs 
PowerModelsDistributionStateEstimation.normalized_residuals(data::Dict, se_sol::Dict, Ω::Matrix; t::Float64=3.0)
```
Finally, a simplified version of the largest normalized residuals is available: `simple_normalized_residuals`, that instead of calculating the $\Omega$ matrix, calculates the normalized residuals as:
```math
\begin{align}
&r_i^N = \frac{|r_i|}{\sqrt{\Omega_{ii}}} = \frac{|r_i|}{\sqrt{R_{ii}^2}}
\end{align}
```
```@docs 
PowerModelsDistributionStateEstimation.simple_normalized_residuals(data::Dict, se_sol::Dict, R::Matrix)
```

## LAV Estimator Residual Analysis

The LAV estimator is known to be inherently robust to bad data, as it is basically a linear regression.
Thus, it is sufficient to run it and then check its residuals as in the piece of code below. The residuals do not even need to be calculated, because in a `LAV` estimation, they are by default reported as `res` in the solution dictionary. As such, the user only needs to sort the residuals in descending orders, see what their magnitude is, and whether some residuals are much higher than the others. The latter, in general, points out the bad data.

```julia
    bad_data["se_settings"] = Dict{String,Any}("criterion" => "lav",
                                            "rescaler" => 1)

    se_result_bd_lav = _PMDSE.solve_acp_red_mc_se(bad_data, solver)
    residual_tuples = [(m, maximum(meas["res"])[1]) for (m, meas) in se_result_bd_lav["solution"]["meas"]]
    sorted_tuples = sort(residual_tuples, by = last, rev = true)
    measurement_index_of_largest_residual = first(sorted_tuples[1])
    magnitude_of_largest_residual = last(sorted_tuples[1])
    ratio12 = (last(sorted_tuples[1])/last(sorted_tuples[2])) # ratio between the first and the second largest residuals.
```

## Other Notes

Virtually all bad data detection and identification methods from the literature are done "a-posteriori", i.e., after running a state estimation, by performing statistical considerations on the measurement residuals, or "a priori" doing some measurement data pre-processing (these are not discussed but could be, e.g., removing missing data or absurd measurements like negative or zero voltage). Thus, it is easy for the user to use this framework to just run the state estimation calculations and then add customized bad data handling methods that take as input the input measurement dictionary and/or the output solution dictionary.

An example on how to use this package to perform bad data detection and identification can be found at this [link](https://github.com/MartaVanin/SE_framework_paper_results): see both its readme and the file `src/scripts/case_study_E.jl`.