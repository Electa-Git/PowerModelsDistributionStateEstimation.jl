# PowerModelsDSSE

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://timmyfaraday.github.io/PowerModelsDSSE.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://timmyfaraday.github.io/PowerModelsDSSE.jl/dev)
[![Build Status](https://travis-ci.com/timmyfaraday/PowerModelsDSSE.jl.svg?branch=master)](https://travis-ci.com/timmyfaraday/PowerModelsDSSE.jl)
[![Codecov](https://codecov.io/gh/timmyfaraday/PowerModelsDSSE.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/timmyfaraday/PowerModelsDSSE.jl)

PowerModelsDSSE.jl is an extention package of PowerModelsDistribution.jl for
Static Distribution System State Estimation. A Distribution System State
Estimator determines the *most-likely* state of distribution system given a set
of uncertainties, e.g., measurement errors, pseudo-measurements, etc. These
uncertainties may pertain to any quantity of any network component, e.g., :vm
of a :bus, :pd of a :load, etc.

Currently, uncertainties may either be described by:
- a deterministic value {Float64}, or
- a continuous univariate distribution {ContinuousUnivariateDistribution}:
    * a normal distribution, modeled through either WLS or LAV approach, or
    * a non-normal distribution, modeled through -logpdf.

## Core Problem Specification

- State Estimation (SE) as equality constrained optimization problem

## Core Network Constraint Formulations

- AC Polar (exact)
- AC Rectangular (exact)
- AC IV Rectangular (exact)
- SDP (positive semi-definite relaxation)

All the formulations are three-phase unbalanced and feature accurate delta/wye load models.
The exact formulations also feature delta/wye transformer models.
Network constraint, load and transformer models are taken from PowerModelsDistribution.jl
You can find a quickguide here [add_hyperlink]


## Network Data Formats

- OpenDSS ".dss" files in the PowerModelsDistribution format

## Installation

XXX

## Acknowledgements

This code has been developed at KU Leuven (University of Leuven) and
EnergyVille. The primary developers are Tom Van Acker (@timmyfaraday) and
Marta Vanin (@MartaVanin) with support for the following
contributors:

- Frederik Geth (@frederikgeth) CSIRO, General PowerModelsDistribution.jl Advice.
- Sander Claeys (@sanderclaeys) KU Leuven, General PowerModelsDistribution.jl Advice.

## License

XXX

## TODO

- check out the NLsolve implementation in PowerModels and use it for a set of grids in order to have a sense of its speed?
- https://github.com/lanl-ansi/PowerModels.jl/blob/master/src/prob/pf.jl line 529
- if you could separate built and solve time that would be great no pressure if you can’t get it done!   line 654
- maybe include a comparison between ipopt and nlsolve
- https://lanl-ansi.github.io/PowerModels.jl/dev/power-flow/
- if it outperforms Ipopt we might want to write a WLS and use NLSolve as solver for this subclass.
