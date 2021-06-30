# Bad Data Detection and Identification

As of version 0.4.0, PMDSE has bad data detection and identification functionalities, namely:
- Chi-square test,
- Largest normalized residuals,
- Least absolute value (LAV) estimator residual analysis.

The LAV is a robust estimator that presents bad data rejection properties. LAV residuals can be collected and sorted, and the measurements with higher 
residuals are the ones of the bad data points.
The LAV residual analysis can be done with all previous versions of the package too, but is made easier in v0.4.0: in versions up to 0.4.0 the user
needs to pass `wlav` or `rwlav` as a state estimation criterion, and assign a unitary standard deviation for all weights or all measurements. Now it is sufficient to 
pass `lav` as a state estimation criterion.

All these three techniques are very standard techniques, and a thorough theoretical discussion can be found in the well-known book: "Power system state estimation - Theory and implementation" by A. Abur and A. G. Exposito. Below, a more concise introduction.

## Chi-square Analysis 

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