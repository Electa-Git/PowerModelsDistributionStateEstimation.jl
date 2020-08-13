# PowerModelsDSSE.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://timmyfaraday.github.io/PowerModelsDSSE.jl/dev)
[![Build Status](https://travis-ci.com/timmyfaraday/PowerModelsDSSE.jl.svg?branch=master)](https://travis-ci.com/timmyfaraday/PowerModelsDSSE.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/timmyfaraday/MultiStateSystems.jl?svg=true)](https://ci.appveyor.com/project/timmyfaraday/MultiStateSystems-jl)
[![Codecov](https://codecov.io/gh/timmyfaraday/PowerModelsDSSE.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/timmyfaraday/PowerModelsDSSE.jl)

PowerModelsDSSE.jl is an extention package of PowerModelsDistribution.jl for
Static Distribution System State Estimation.

A Distribution System State Estimator determines the *most-likely* state of
distribution system given a set of uncertainties, e.g., measurement errors,
pseudo-measurements, etc. These uncertainties may pertain to any quantity of any
network component, e.g., `:vm` of a `:bus`, `:pd` of a `:load`, etc.

Currently, uncertainties may either be described by:
- a deterministic value `Float64`, or
- a continuous univariate distribution `ContinuousUnivariateDistribution`:
    * a normal distribution, modeled through either WLS or LAV approach, or
    * a non-normal distribution, modeled through -logpdf.

## Core Problem Specification

- State Estimation (SE) as equality constrained optimization problem

## Core Network Constraint Formulations

- AC Polar (exact)
- AC Rectangular (exact)
- AC IV Rectangular (exact)
- SDP (positive semi-definite relaxation)

All the formulations are three-phase unbalanced and feature accurate delta/wye
load models. The exact formulations also feature delta/wye transformer models.
Network constraint, load and transformer models are taken from
[PowerModelsDistribution.jl](https://github.com/lanl-ansi/PowerModelsDistribution.jl)

## Network Data Formats

- OpenDSS ".dss" files in the PowerModelsDistribution format
- CSV ".csv" file with measurement a statistical information for state estimation

## Summary of State Estimation Possibilities

|                   | ACP           | ACR           | IVR           | SDP           |
| ----------------- | ------------- | ------------- | ------------- | ------------- |
| BI/BF             | BI            | BI            | BF            | BF            |
| Simple SE[^1]     | Available     | Available     | Available     | Available     |
| Advanced SE[^2]   | Available     | Available     | Available     | Unavailable   |
| 4-wire[^3]        | v0.2.0        | v0.2.0        | v0.2.0        | v0.2.0        |

[^1]: The simple SE **does not include** transformer models and delta/wye loads.
[^2]: The simple SE **includes** transformer models and delta/wye loads.
[^3]: Awaiting PowerModelsDistribution v0.10.0

## Installation

The latest stable release of PowerModelsDSSE can be installed using the Julia
package manager:

```
] add https://github.com/timmyfaraday/PowerModelsDSSE.jl.git
```

In order to test whether the package works, run:

```
] test MultiStateSystems
```

## Acknowledgements

This code has been developed at KU Leuven (University of Leuven). The primary
developers are Tom Van Acker ([@timmyfaraday](https://github.com/timmyfaraday))
and Marta Vanin ([@MartaVanin](https://github.com/MartaVanin)) with support for
the following contributors:

- Frederik Geth ([@frederikgeth](https://github.com/frederikgeth)) CSIRO,
General PowerModelsDistribution.jl Advice.
- Sander Claeys ([@sanderclaeys](https://github.com/sanderclaeys)) KU Leuven,
General PowerModelsDistribution.jl Advice.

## License

This code is provided under a BSD license.

## Notes

Currently, bad data detection techniques and observability considerations are out of scope.
