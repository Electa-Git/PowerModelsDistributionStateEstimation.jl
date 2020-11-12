# PowerModelsDistributionStateEstimation.jl

<a href="https://github.com/Electa-Git/PowerModelsDistributionStateEstimation.jl/actions?query=workflow%3ATest+branch%3Adev"><img src="https://github.com/Electa-Git/PowerModelsDistributionStateEstimation.jl/workflows/CI/badge.svg"></img></a>

[![CI](https://github.com/Electa-Git/PowerModelsDistributionStateEstimation/workflows/CI/badge.svg)

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Electa-Git.github.io/PowerModelsDistributionStateEstimation.jl/dev)
[![Build Status](https://travis-ci.com/Electa-Git/PowerModelsStateEstimation.jl.svg?token=wBsNbd12XnPoP4bx78Cy&branch=master)](https://travis-ci.com/Electa-Git/PowerModelsDistributionStateEstimation.jl)
[![codecov](https://codecov.io/gh/Electa-Git/PowerModelsStateEstimation.jl/branch/master/graph/badge.svg?token=vATNv5wVsp)](https://codecov.io/gh/Electa-Git/PowerModelsDistributionStateEstimation.jl)

PowerModelsDistributionStateEstimation.jl is an extension package of PowerModelsDistribution.jl for Static Power Distribution Network State Estimation. The package is a flexible design tool, enabling benchmarks between different state estimation models. Different state estimation models can be built by using different power flow formulations, state estimation criteria, (in)equality constraints, etc.

A state estimator determines the *most-likely* state of power distribution networks given a set of uncertainties, e.g., measurement errors, pseudo-measurements, etc. These uncertainties may pertain to any quantity of any network component, e.g., voltage magnitude (`vm`) of a `bus`, power demand (`pd`) of a `load`, etc.

## Core Problem Specification

Estimation Criteria:
- (Weighted) Least Squares ((W)LS)
- (Weighted) Least Absolute Values ((W)LAV)
- Maximum Likelihood Estimation (MLE)

Measurement Uncertainties:
- a deterministic value `Float64`, or
- a continuous univariate distribution `ContinuousUnivariateDistribution`
	- normal distribution, included through (W)LS or (W)LAV
	- non-normal distributions, included through MLE

## Core Network Constraint Formulations

- Exact
	- (reduced) ACP
	- (reduced) ACR
	- (reduced) IVR
- Relaxations
	- SDP 
- Linear Approximations 
	- LinDist3Flow

## Data Formats

To use the package, two type of data inputs are required:
- Network data: OpenDSS “.dss” files
- Measurement data: CSV “.csv” files

## Examples (Coming Soon)

Examples on how to use PowerModelsDistributionStateEstimation can be found in Pluto Notebooks inside the `/examples` directory.

## Acknowledgements

This code has been developed at KU Leuven (University of Leuven). The primary
developers are Marta Vanin ([@MartaVanin](https://github.com/MartaVanin)) and Tom Van Acker ([@timmyfaraday](https://github.com/timmyfaraday)) with support for
the following contributors:

- Frederik Geth ([@frederikgeth](https://github.com/frederikgeth)), CSIRO, General PowerModelsDistribution.jl Advice.
- Sander Claeys ([@sanderclaeys](https://github.com/sanderclaeys)), KU Leuven, General PowerModelsDistribution.jl Advice, ENWL data parser.

## Citing PowerModelsDistributionStateEstimation

If you find PowerModelsDistributionStateEstimation.jl useful for your work, we kindly invite you to cite our [work](https://lirias.kuleuven.be/handle/123456789/662982):

```bibtex
@misc{vanin2021,
author = {Vanin, M and Van Acker, T and D'hulst, R and Van Hertem, D},
title = {A framework for constrained static state estimation in unbalanced distribution networks},
publicationstatus = {in-preparation},
}

```

## License

This code is provided under a BSD license.

## Notes

- The focus is on the state estimation model itself, and bad data detection techniques and observability considerations are not dealt with.
- Accurate load and transformer models are available on PowerModelsDistribution and can be easily included in this package for state estimation purposes, e.g., to include the medium voltage network in the analysis. Extending the package to host these models is scheduled for future releases. If you would like to use realistic load/transformer models already, you are welcome to contribute to the package.
