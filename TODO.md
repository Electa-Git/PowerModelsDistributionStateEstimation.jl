## A list of random ideas and/or things to do before v0.2.0

- unify conversion type MultiplicationFraction and Fraction? maybe with create_conversion_constraint(pm::_PMs.ACP, original_var, msr::SquareFraction; nw=nw, nph=3) + create_conversion_constraint(pm::_PMs.ACR, original_var, msr::SquareFraction; nw=nw, nph=3)

- model loads as constant power? worked in previous version of DSSE (before PMD 0.9.0 introduced complexity)

- change ipopt settings/add derivatives?

- are there just too many measurements?

-test on VM so we can use MA27

-add measurements at transformer level?

-changing ipopt tol doesn't help make things faster for se

- break into multi-area

- add variable bounds?

- explore smiplified formulations of components?

- I tried removing the transfo from EU LV feeder,but didn't help the tragically slow calculations/convergence issues. perhaps more diverse weights?

-find a way to use sdp where there are transfos
