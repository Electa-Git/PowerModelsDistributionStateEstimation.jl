# Network Formulations

This section gives an overview of the three-phase power flow formulations that are available to perform state estimation in PowerModelsSE. All formulations except the Reduced ones are imported from PowerModels or PowerModelsDistribution. These are only a subset of the formulations available in these two packages. For further information please refer to their official [documentation](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/formulations/).

## Type Hierarchy

Formulations (or "PowerModels") follow the type hierarchy of PowerModels and PowerModelsDistribution, reported here for convenience for the relevant cases.
At the top of the type hierarchy are abstract types. Three exact nonlinear (non-convex) models are available at the top level:

```julia
abstract type PowerModels.AbstractACPModel <: PowerModels.AbstractPowerModel end
abstract type PowerModels.AbstractACRModel <: PowerModels.AbstractPowerModel end
abstract type PowerModels.AbstractIVRModel <: PowerModels.AbstractACRModel end
```

Abstract Models types are then used as the type parameter for `PowerModels`:

```julia
mutable struct PowerModels.ACPPowerModel <: PowerModels.AbstractACPModel PowerModels.@pm_fields end
mutable struct PowerModels.ACRPowerModel <: PowerModels.AbstractACRModel PowerModels.@pm_fields end
mutable struct PowerModels.IVRPowerModel <: PowerModels.AbstractIVRModel PowerModels.@pm_fields end
```

A "reduced" version of each of the three formulations above is derived in PowerModelsSE:

```julia
mutable struct PowerModelsSE.ReducedACPPowerModel <: PowerModels.AbstractACPModel PowerModels.@pm_fields end
mutable struct PowerModelsSE.ReducedACRPowerModel <: PowerModels.AbstractACRModel PowerModels.@pm_fields end
mutable struct PowerModelsSE.ReducedIVRPowerModel <: PowerModels.AbstractIVRModel PowerModels.@pm_fields end

AbstractReducedModel = Union{ReducedACRPowerModel, ReducedACPPowerModel}
```

The reduced models are still exact for networks like those made available in the ENWL database, where there are no cable ground admittance, storage elements and active switches.
A positive semi-definite (SDP) relaxation is also made available for state estimation in PowerModelsSE. The SDP model belongs to the following categories: conic models and branch flow (BF) models, and there relevant type structure is the following:

```julia
abstract type PowerModels.AbstractBFModel <: PowerModels.AbstractPowerModel end
abstract type PowerModels.AbstractBFConicModel <: PowerModels.AbstractBFModel end
abstract type PowerModelsDistribution.AbstractConicUBFModel <: PowerModels.AbstractBFConicModel end
abstract type PowerModelsDistribution.SDPUBFModel <: PowerModelsDistribution.AbstractConicUBFModel end

mutable struct PowerModelsDistribution.SDPUBFPowerModel <: PowerModelsDistribution.SDPUBFModel PowerModels.@pm_fields end
```
where `UBF` stands for unbalanced branch flow. Finally, a linear unbalanced branch flow model is available for state estimation: the `LPUBFDiagModel`, better known as `LinDist3FlowModel`.

```julia
abstract type PowerModelsDistribution.AbstractLPUBFModel <: PowerModelsDistribution.AbstractNLPUBFModel end
abstract type PowerModelsDistribution.LPUBFDiagModel <: PowerModelsDistribution.AbstractLPUBFModel end
const PowerModelsDistribution.LinDist3FlowModel = PowerModelsDistribution.LPUBFDiagModel

mutable struct PowerModelsDistribution.LPUBFDiagPowerModel <: PowerModelsDistribution.LPUBFDiagModel PowerModels.@pm_fields end
const PowerModelsDistribution.LinDist3FlowPowerModel = PowerModelsDistribution.LPUBFDiagPowerModel
```

## Details on the Formulations

This sub-section reports for convenience the relevant literature for the formulations used in PowerModelsSE and is again a reduced version of the official PowerModelsDistribution documentation, available [here](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/formulation-details/).

### `AbstractACPModel`

- Formulation without shunts: Mahdad, B., Bouktir, T., & Srairi, K. (2006). A three-phase power flow modelization: a tool for optimal location and control of FACTS devices in unbalanced power systems. In IEEE Industrial Electronics IECON (pp. 2238–2243).
See also:
- Carpentier, J. (1962) Contribution to the economic dispatch problem. In Bulletin de la Societe Francoise des Electriciens, vol. 3 no. 8, pp. 431-447.
- Cain, M. B., O' Neill, R. P. & Castillo, A. (2012). History of optimal power flow and Models. [Available online](https://www.ferc.gov/industries/electric/indus-act/market-planning/opf-papers/acopf-1-history-Model-testing.pdf)

### `AbstractACRModel`
See:
- Cain, M. B., O' Neill, R. P. & Castillo, A. (2012). History of optimal power flow and Models. [Available online](https://www.ferc.gov/industries/electric/indus-act/market-planning/opf-papers/acopf-1-history-Model-testing.pdf)

### `AbstractIVRModel`

- O' Neill, R. P., Castillo, A. & Cain, M. B. (2012). The IV formulation and linear approximations of the ac optimal power flow problem. [Available online](https://www.ferc.gov/sites/default/files/2020-05/acopf-2-iv-linearization.pdf)

### `SDPUBFModel`

- Gan, L., & Low, S. H. (2014). Convex relaxations and linear approximation for optimal power flow in multiphase radial networks. In PSSC (pp. 1–9). Wroclaw, Poland. [doi:10.1109/PSCC.2014.7038399](https://doi.org/10.1109/PSCC.2014.7038399)

### `LPUBFDiagModel` or `LinDist3FlowModel`

- Sankur, M. D., Dobbe, R., Stewart, E., Callaway, D. S., & Arnold, D. B. (2016). A linearized power flow model for optimization in unbalanced distribution systems. [arXiv:1606.04492v2](https://arxiv.org/abs/1606.04492v2)
