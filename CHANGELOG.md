## v0.2.1
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
