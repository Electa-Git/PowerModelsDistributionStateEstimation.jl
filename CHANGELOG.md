## staged
- adds "lav" and "ls" criteria explicitly, i.e., no weights
- removes run_mc_ functions in favour of solve_mc_ functions (breaking!)

## v0.3.0
- adds tests/examples and docs for state estimation with single-phase connections and matpower data parsing 
- updates to PowerModelsDistribution v0.11.1 and InfrastructureModels 0.6.0 (breaking!)
- adds `core/export.jl` with all the exported functions instead of keeping them in the _PMDSE module
- removes PowerModels dependency, all functions imported via PowerModelsDistribution
- removes Memento dependency, logging is made consistent with PowerModelsDistribution v0.11 using Julia standard library
- adds short bad data consideration to Readme

## v0.2.4
- improves PMDSE_intro notebook
- fixes StatsPlots dep allowing more recent _DST versions
- depreciates run_ functions in favor of solve_ (with warns)
- adds support for `relax_integrality` (InfrastructureModels ~0.5.4)
- adds logo

## v0.2.1-3
- Bugfix: minor bugfixes for non-gaussian SE
- Bugfix: use of gaussian mixture models led to invalid JuMP models (Inf logpdf/NaN gradlogpdf and heslogpdf)

## v0.2.0
- Add: possibility to set upper bound on residuals
- Add: support for easier non gaussian measurement creation
- Add: support for PMD v0.10.0
      - rename constraints
      - iteration through conductors in all functionalities
      - deprecate "gmm" for "mle" with extended grad/heslogpdf for GMMs
- Add: dimension reduction for buses and branches with only single-phase loads/gens
- Refactor: changed all _PMS abbreviations for the package into _PMDSE
- Add: helper functions to generate pseudo measurement dictionaries, tests, docs and examples.
- Add: extension of `minimum` and `maximum` for the `ExtendedBeta`
- Add: possibility to rescale the `ExtendedBeta` if not in per unit
- TMP FIX: removed SDP unstable tests. SDP is not tested anymore
- Add: possibility to set upper bound on residuals, helper function `assign_residual_ub!`, test of the util and docs
- Add: tests for functions in utils.jl and start_values_methods.jl
- Add: individual measurement criterion, including helper function `assign_basic_individual_criteria!` test of criterion and util and docs

## v0.1.2

- Initial public release
