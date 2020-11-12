# Problem Specifications

The main purpose of PowerModelsDistributionStateEstimation is to solve state estimation problems. For a number of purposes, it might be useful to perform power flow or OPF calculations, within the context of a state estimation study. For example, power flow calculations can be used to validate the accuracy of the state estimator, or to generate artificial measurement data, if these are not available. Power flow and OPF calculations can be accessed from PowerModelsDistribution. The description of these problems can be found in PowerModelsDistribution's [documentation](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/math-model/). 

## State estimation problem implementation

For a bus injection model, the structure of the state estimation problem is the following. See the implementation at src/prob/se.jl for all the models'  implementations and their details.
The functions preceded by a "_PMD." are imported from PowerModelsDistributions.jl. Those without prefix are original PowerModelsDistributionStateEstimation functions, those preceded by a "PowerModelsDistributionStateEstimation." are present in both and therefore needed disambiguation.

### Variables

```julia

PowerModelsDistributionStateEstimation.variable_mc_bus_voltage(pm; bounded = true)
_PMD.variable_mc_branch_power(pm; bounded = true)
_PMD.variable_mc_transformer_power(pm; bounded = true)
_PMD.variable_mc_gen_power_setpoint(pm; bounded = true)
variable_mc_load(pm; report = true)
variable_mc_residual(pm, bounded = true)
variable_mc_measurement(pm, bounded = false)
```

It can be seen that the first variables are bounded. It is up to the user to define reasonable upper/lower bounds that don't cut the feasible space of the problem. They can in principle be set as +/- infinity if no better information on the bounds is available.

### Constraints

```julia

for (i,gen) in _PMD.ref(pm, :gen)
    _PMD.constraint_mc_gen_setpoint(pm, i)
end
for (i,bus) in _PMD.ref(pm, :ref_buses)
    @assert bus["bus_type"] == 3
    _PMD.constraint_mc_theta_ref(pm, i)
end
for (i,bus) in _PMD.ref(pm, :bus)
    PowerModelsDistributionStateEstimation.constraint_mc_load_power_balance_se(pm, i)
end
for (i,branch) in _PMD.ref(pm, :branch)
    _PMD.constraint_mc_ohms_yt_from(pm, i)
    _PMD.constraint_mc_ohms_yt_to(pm,i)
end
for (i,meas) in _PMD.ref(pm, :meas)
    constraint_mc_residual(pm, i)
end

for i in _PMD.ids(pm, :transformer)
    _PMD.constraint_mc_transformer_power(pm, i)
end
```

### Objective

```julia
    objective_mc_se(pm)
```

For branch flow/linearized/SDP models, the variable space changes and also some of the constraints, while the objective always stays the same.

## Mathematical formulation

For a detailed description of the mathematical model, please refer to the following [publication]().
In the mathematical description below, the following sets are used,

```math
\begin{align}
%
\mbox{sets:} & \nonumber \\
& \mathcal{N} \mbox{ - buses}\nonumber \\
& \mathcal{R} \mbox{ - references buses}\nonumber \\
& \mathcal{E}, \mathcal{E}_i  \mbox{ - branches, branches to and from bus $i$} \nonumber \\
& \mathcal{G}, \mathcal{G}_i \mbox{ - generators and generators at bus $i$} \nonumber \\
& \mathcal{L}, \mathcal{L}_i \mbox{ - loads and loads at bus $i$} \nonumber \\
& \mathcal{S}, \mathcal{S}_i \mbox{ - shunts and shunts at bus $i$} \nonumber \\
& \Phi. \Phi_{ij} \mbox{ - conductors, conductors of branch $(ij)$} \nonumber \\
%
\end{align}
```

- Bold characters indicate vectors and matrices
- The $\text{diag}(\cdot)$ operator takes the diagonal (vector) from a matrix
- The $(\cdot)^H$ indicates the conjugate transpose of a matrix

The julia problem above, can be associated to the following mathematical description

Variables:
```math

\begin{align}
  &\mathbf{S}^g_{k}, \mathbf{S}^d_{k}, \mathbf{U}_{i}   \;\; \forall k \in \mathcal{G}, k \in \mathcal{L}, i \in \mathcal{N}, \nonumber \\     & \mathbf{S}_{ij}, \boldsymbol{\rho}_m \;\; \forall (i,j) \in \mathcal{E}, m \in \mathcal{M} \nonumber.
\end{align}
```
Constraints:
```math
\begin{align}
&\mathbf{\angle {U}}_{r} = [0, -120, 120] \deg  \;\; \forall r \in \mathcal{R}, \\
\begin{split}
&\sum_{\substack{k \in \mathcal{G}_i}} \mathbf{S}^g_k - \sum_{\substack{k \in \mathcal{L}_i}} \mathbf{S}^d_k - \sum_{\substack{k \in \mathcal{S}_i}}  \mathbf{U}_i \mathbf{U}^H_i (\mathbf{Y}^s_k)^H  = \\
& \; \; \; \sum_{\substack{(i,j)\in \mathcal{E}_i}} diag(\mathbf{S}_{ij}) \;\; \forall i\in \mathcal{N},
 \end{split} \\
 & \mathbf{S}_{ij} =  \mathbf{U}_i \mathbf{U}_i^H \left( \mathbf{Y}^{sh}_{ij}\right)^H + \mathbf{U}_i \left(\mathbf{U}_i- \mathbf{U}_j \right)^H (\mathbf{Y}_{ij})^H  \;\; \forall (i,j)\in \mathcal{E}, \\
%& \mathbf{S}_{ij} =  {\mathbf{U}_i \mathbf{U}_i^H} \left( \mathbf{Y}_{ij} + \mathbf{Y}^{sh}_{ij}\right)^H - {\mathbf{U}_i \mathbf{U}^H_j} \mathbf{Y}^H_{ij}  \;\; \forall (i,j)\in \mathcal{E}, \\
%& \mathbf{S}_{ji} = \mathbf{U}_j \mathbf{U}_j^H \left( \mathbf{Y}_{ij} + \mathbf{Y}^{sh}_{ji} \right)^H - {\mathbf{U}^H_i \mathbf{U}_j} \mathbf{Y}^H_{ij} \;\; \forall (i,j)\in \mathcal{E}, \\
& \boldsymbol{\rho}_m = r_m(\mathbf{f}_m(\mathbf{x}), \mathbf{z}_m, \boldsymbol{\sigma}_m)
%\| \mathbf{f}_m(\mathbf{x}) - \mathbf{z}_m \|_p/\boldsymbol{\sigma}^p_m \;\; \forall m \in \mathcal{M}, \mathbf{x} \in \mathcal{X}.
\end{align}
```
Objective:
```math
\begin{equation}\label{eq:objective}
  \text{minimize} \; \; \sum_{\substack{m \in \measm}} \boldsymbol{\rho}_{m}.
\end{equation}
 ```
The residual $\rho_{m, \phi}$ is a function that allows to represent the uncertainty on a given measurement $m$, performed on conductor $\phi$. In the mathematical description above, it is identified as the function $r$, which is depending on the measurement $\mathbf{z}$, and another function: $f$.

The function $f_{m,\phi}$ are used to handle measurements $z_{m,\phi}$ that are performed on quantities that do not refer to the problems' variable space. There are the measurements conversions described in the ([Measurements And Conversions](@ref)) section of this manual.

Function $r_{m,\phi}$, on the other hand, depends on what state estimation criterion is chosen, e.g., WLS, WLAV, MLE. The form that $r_{m,\phi}$ takes in the various cases is defined in the section ([State Estimation Criteria](@ref)) of this manual.
