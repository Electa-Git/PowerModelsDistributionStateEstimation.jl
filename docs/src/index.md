# PowerModelsDistributionStateEstimation.jl Documentation

## Overview

PowerModelsDistributionStateEstimation.jl is an extension package of PowerModelsDistribution.jl for three-phase
static Power System State Estimation.

A Power System State Estimator determines the *most-likely* state of
power system given a set of uncertainties, e.g., measurement errors,
pseudo-measurements, etc. These uncertainties may pertain to any quantity of any
network component, e.g., voltage magnitude (`vm`) of a `bus`, power demand (`pd`) of a `load`, etc.

## Installation

The latest stable release of PowerModelsDistributionStateEstimation can be installed using the Julia
package manager:

```
] add https://github.com/Electa-Git/PowerModelsDistributionStateEstimation.jl.git
```

To be able to use PowerModelsDistributionStateEstimation, at least one solver is required. For our package tests, we rely on Ipopt and SCS solvers, since they do not have license restrictions. Both solvers can be installed using the package manager:

```
] add Ipopt
```
```
] add SCS
```
However, it should be noted that, depending on the problem type, these solvers might not be the most appropriate/efficient choice.

In order to test whether the package works, run:

```
] test PowerModelsDistributionStateEstimation
```
