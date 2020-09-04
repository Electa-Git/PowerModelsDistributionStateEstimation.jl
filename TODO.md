## A list of random ideas and/or things to do before v0.2.0

- change ipopt settings/add derivatives?

- are there just too many measurements?

-test on VM so we can use MA27

-add measurements at transformer level?

-changing ipopt tol doesn't help make things faster for se

- break into multi-area

- explore smiplified formulations of components?

## TODO

[ ] check out the NLsolve implementation in PowerModels and use it for a set of grids in order to have a sense of its speed?
[ ] https://github.com/lanl-ansi/PowerModels.jl/blob/master/src/prob/pf.jl line 529
[ ] if you could separate built and solve time that would be great no pressure if you can’t get it done!   line 654
[ ] maybe include a comparison between ipopt and nlsolve
[ ] https://lanl-ansi.github.io/PowerModels.jl/dev/power-flow/
[ ] if it outperforms Ipopt we might want to write a WLS and use NLSolve as solver for this subclass.
