# PowerModelsSE.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Electa-Git.github.io/PowerModelsSE.jl/dev)
[![Build Status](https://travis-ci.com/Electa-Git/PowerModelsSE.jl.svg?branch=master)](https://travis-ci.com/Electa-Git/PowerModelsSE.jl)
[![codecov](https://codecov.io/gh/Electa-Git/PowerModelsSE.jl/branch/master/graph/badge.svg?token=vATNv5wVsp)](https://codecov.io/gh/Electa-Git/PowerModelsSE.jl)

PowerModelsSE.jl is an extension package of PowerModels(Distribution).jl for Static Power System State Estimation. Currently, the package focusses on Distribution System State Estimation.

A State Estimator determines the *most-likely* state of power system given a set of uncertainties, e.g., measurement errors,
pseudo-measurements, etc. These uncertainties may pertain to any quantity of any network component, e.g., voltage magnitude (`vm`) of a `bus`, power demand (`pd`) of a `load`, etc.

This README file is just a quick introduction. If you are interested in using the package, you can find more information in the [documentation](https://timmyfaraday.github.io/PowerModelsSE.jl/dev/).

## Modeling Uncertainties

Currently, measurement uncertainties may either be described by:
- a deterministic value `Float64`, or
- a continuous univariate distribution `ContinuousUnivariateDistribution`:
    * a Normal distribution, that can be included in a standard WLS or (W)LAV approach, or
    * a number of other distributions, included through the concept of Maximum Likelihood Estimation.
For details on the distributions and the state estimation problem formulation, the user is referred to the package manual.

## Core Problem Specification

- State Estimation (SE) as (in)equality constrained optimization problem, that can be performed according to different estimation criteria:
    - Weighted Least Squares (WLS)
    - Weighted Least Absolute Values (WLAV)
    - Maximum Likelihood Estimation (MLE)
    - It is also possible to remove the weights and perform LS and LAV

## Core Network Constraint Formulations

Together with measurement values, the use power flow equations is required to derive the most likely state of a network.
Several formulations of the power flow equations are imported from [PowerModelsDistribution.jl](https://github.com/lanl-ansi/PowerModelsDistribution.jl):
- AC Polar (exact)
- AC Rectangular (exact)
- IV Rectangular (exact)
- SDP (positive semi-definite relaxation)
- LinDist3Flow (linear approximation)

The three exact formulations in general lead to non-convex state estimation, unless the network is monitored via phasor measurement units. To reduce the complexity of the formulations a bit, improving tractability, three reduced versions are provided in the present package, that are not available on PowerModelsDistribution:

- Reduced AC Polar
- Reduced AC Rectangular
- Reduced IV Rectangular

These three formulations still lead, in general, to non-convex state estimation (again depending on the measurements), but some nonlinearities are avoided with minor variable reformulations and by assuming that the shunt admittance of the cables is negligible. This is often the case in low voltage distribution network databases. If the assumption holds, the Reduced formulations are still exact, i.e., the state estimation is free of modeling errors.

All the formulations are three-phase unbalanced.

## Load and Transformer Models

Currently, the developers' research work focuses on state estimation in low voltage distribution feeders, and therefore load measurements from the consumers are modeled as power/current injections at the bus where the measurement takes place. It is not considered whether the load is constant power, constant impedence, ZIP, etc.
No detailed model of the transformer substation is required, either, if the interest is exclusively on the low voltage side.
Accurate load and transformer models are available on PowerModelsDistribution and can be easily included in this package for state estimation purposes, e.g., to include the medium voltage network in the analysis. Extending the package to host these models is future work scheduled for future releases. If you would like to use realistic load/transformer models already, you are welcome to contribute to the package. Alternatively, you can let us know of your interest; if multiple requests are received, we might consider moving up the extension.

## Data Formats

To use the package, two type of data inputs are required:
- Network data (network topology, cable impedance, consumer location...)
- Measurement data (simulated or collected from measurement devices, etc..)

The two are then put together in a single dictionary and used to run the state estimator.
The network data needs to be compatible with PowerModelsDistribution, which also provides an automatic parser to read OpenDSS (".dss") data.
PowerModelsSE reads measurement data from CSV (".csv") files and comes with some helping function to build these csv files from power flow results from PowerModelsDistribution or similar sources.
More information can be found in the documentation.

## Citing PowerModelsSE

To do

## Acknowledgements

This code has been developed at KU Leuven (University of Leuven). The primary
developers are Marta Vanin ([@MartaVanin](https://github.com/MartaVanin)) and Tom Van Acker ([@timmyfaraday](https://github.com/timmyfaraday)) with support for
the following contributors:

- Frederik Geth ([@frederikgeth](https://github.com/frederikgeth)), CSIRO, General PowerModelsDistribution.jl Advice.
- Sander Claeys ([@sanderclaeys](https://github.com/sanderclaeys)), KU Leuven, General PowerModelsDistribution.jl Advice, ENWL data parser.

## License

This code is provided under a BSD license.

## Notes

Currently, the focus is on the state estimation model itself, and bad data detection techniques and observability considerations are not dealt with.
