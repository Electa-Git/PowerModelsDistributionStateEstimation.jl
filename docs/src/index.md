# PowerModelsDSSE.jl Documentation

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

## Notes

Currently, bad data detection techniques and observability considerations are out of scope.

## Core Problem Specification

- State Estimation (SE), for the Bus Injection Model (BIM)

## Core Network Formulations

- AC (polar coordinates)

## Network Data Formats

- OpenDSS ".dss" files for grid and profile data
- CSV ".csv" file with measurement a statistical information for state estimation

## Summary of State Estimation Possibilities

| -  | SDP | VI | ACP | ACR |
| --- | --- |
| BF of BI | BF | BF | BI | BI |
| Advanced SE | Unavailable | Unavailable | Available | Unavailable |
| Simple SE | Available | Available | Available | Available |
| 4-wire | v0.2.0 | v0.2.0 | v0.2.0 | v0.2.0 |

BF indicates that the model is a branch flow model, BI that it is a bus injectino model.
Simple SE does not include modeling of transformers and delta/wye loads, ...

## Installation

XXX

## Acknowledgements

This code has been developed as part of the Decision Support at the University
of Leuven (KU Leuven) and EnergyVille. The primary developers are Tom Van Acker
(@timmyfaraday) and Marta Vanin (@MartaVanin) with support for the following
contributors:

- Frederik Geth (@frederikgeth) CSIRO, General PowerModelsDistribution.jl Advice.
- Sander Claeys (@SanderClaeys) KU Leuven, General PowerModelsDistribution.jl Advice.

## License

XXX
