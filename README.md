# PowerModelsDSSE

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://timmyfaraday.github.io/PowerModelsDSSE.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://timmyfaraday.github.io/PowerModelsDSSE.jl/dev)
[![Build Status](https://travis-ci.com/timmyfaraday/PowerModelsDSSE.jl.svg?branch=master)](https://travis-ci.com/timmyfaraday/PowerModelsDSSE.jl)
[![Codecov](https://codecov.io/gh/timmyfaraday/PowerModelsDSSE.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/timmyfaraday/PowerModelsDSSE.jl)

PowerModelsDSSE.jl is an extention package of PowerModelsDistribution.jl for
Static Distribution System State Estimation. A Distribution System State
Estimator determines the most-likely state of distribution system given a set
of uncertainties. These uncertainties may pertain to any quantity of any network
component, e.g., :vm of a :bus, :pd of a :load, etc.

Currently, uncertainties may either be described by:
- a nothing {Nothing},
- a deterministic value {Float64}, or
- a continuous univariate distribution {ContinuousUnivariateDistribution}:
    * a normal distribution, modeled through either wls or wlav approach, or
    * a non-normal distribution, modeled through -logpdf.

## Core Problem Specification

- State Estimation (SE), for the Bus Injection Model (BIM)

## Core Network Formulations

- AC (polar coordinates)

## Network Data Formats

- OpenDSS ".dss" files

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
