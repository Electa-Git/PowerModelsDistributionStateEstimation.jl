# Mathematical Model of the State Estimation Criteria

The state of a power system can be determined based on a specific estimation criterion.
The user has to specify the `criterion` through the `se_settings` ([Input Data Format](@ref)).
If no criterion is specified, it will default to `rwlav`.

Currently, the following criteria are supported:
- `wlav`: weighted least absolute value
- `rwlav`: relaxed weighted least absolute value
- `wls`: weighted least square
- `rwls`: relaxed weighted least square
- `mle`: maximum likelihood estimation
- `mixed`: a combination of the criteria above

The first four criteria assume that the error on a measurement follows a Normal
distribution. The `mle` criterion can account for any univariate continuous distribution.
The `mixed` criterion allows to use a combination of the above, for different measurements.

Furthermore, a rescaler can be introduced to improve the convergence of the state
estimation. The user has to specify the `rescaler` through the `se_settings` ([Input Data Format](@ref)).
If no rescaler is specified, it will default to `1.0`.

## WLAV and rWLAV

The WLAV criterion represents the absolute value norm (p=1) and is given by
```math
\begin{eqnarray}
      \rho_{m}          &= \frac{| x - \mu_{m} |}{\text{rsc} \cdot \sigma_{m}},\quad m \in \mathcal{M}: m \to x \in \mathcal{X},
\end{eqnarray}
```
where:
* `𝓜` denotes the set of measurements,
* `𝓧` denotes the (extended) variable space of the OPF problem.

A injective-only mapping exist between the measurement set `𝓜` and
variable space `𝓧`.

Furthermore:

* `ρ` denotes the residual associated with a measurement $m$,
* `x` denotes the variable corresponding to a measurement $m$.
* `μ` denotes the measured value,
* `σ` denotes the the measurement error,
* `rsc` denotes the rescaler.

Solving a state estimation using the WLAV criterion is non-trivial as the
absolute value function is not continuously differentiable. This drawback is
lifted by its exact linear relaxation: rWLAV[^1]. The rWLAV criterion is given by

```math
\begin{eqnarray}
      \rho_{m}          &\geq \frac{ x - \mu_{m} }{\text{rsc} \cdot \sigma_{m}},\quad m \in \mathcal{M}: m \to x \in \mathcal{X},    \\
      \rho_{m}          &\geq - \frac{ x - \mu_{m} }{\text{rsc} \cdot \sigma_{m}},\quad m \in \mathcal{M}: m \to x \in \mathcal{X},    \\
\end{eqnarray}
```

[^1]: Note that this relaxation is only exact in the context of minimization problem.

## WLS and rWLS

The WLS criterion represents the Eucledian norm (p=2) and is given by
```math
\begin{eqnarray}
      \rho_{m}          &= \frac{( x - \mu_{m} )^{2}}{\text{rsc} \cdot \sigma_{m}^{2}},\quad m \in \mathcal{M}: m \to x \in \mathcal{X}.
\end{eqnarray}
```
The rWLS criterion relaxes the former as a cone and is given by
```math
\begin{eqnarray}
      rsc \cdot \sigma_{m}^{2} \cdot \rho_{m} &\geq ( x - \mu_{m} )^{2},\quad m \in \mathcal{M}: m \to x \in \mathcal{X}.
\end{eqnarray}
```

## Maximum Likelihood Estimation

The maximum likelihood criterion links the measurement residual to the logpdf of
the associated distribution and is given by
```math
\begin{eqnarray}
      \rho_{m}          &= - \text{rsc} \cdot \text{logpdf}_{m}(x) + \text{shf},\quad m \in \mathcal{M}: m \to x \in \mathcal{X}.
\end{eqnarray}
```
where `shf` denotes a shift setting the minimum value of the residual to zero.

Currently, the following univariate continuous distributions are supported through
the [Distributions.jl](https://github.com/JuliaStats/Distributions.jl) package:
- Exponential
- Weibull
- Normal
- Log-Normal
- Gamma
- Beta
- Extended Beta
From v0.2.0, the following will also be available:
- Arcsine
- Chi
- Chisq
- Frechet
- Gumbel
- Laplace
- Locationscale
- Logistic
- Logitnormal
- Tdist

```@docs
ExtendedBeta
```

To avoid the use of automatic differentiation, the first derivative (`gradlogpdf`)
is provided by Distributions.jl and the second derivative (`heslogpdf`) is provided internally.

## Mixed criterion

To use the `mixed` criterion, it is not sufficient to set the `criterion` in `se_settings` as `mixed`.
In addition to this, an individual dictionary entry for every measurement in `data["meas"]` needs to be added,
to state which criterion is associated to each measurement.
The individual criterion entry needs to be placed under a `crit` key. For example:
`data["meas"]["1"]["crit"] = "rwlav"` and `data["meas"]["2"]["crit"] = "mle"`.
A basic function to assign different criteria to different measurement is provided:
```@docs
PowerModelsDistributionStateEstimation.assign_default_individual_criterion!(data; chosen_criterion="rwlav")
```
