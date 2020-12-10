## staged
- Refactor: changed all _PMS abbreviations for the package into _PMDSE
- Add: helper functions to generate pseudo measurement dictionaries, tests, docs and examples.
- Add: extension of `minimum` and `maximum` for the `ExtendedBeta`
- Add: possibility to rescale the `ExtendedBeta` if not in per unit
- TMP FIX: removed SDP unstable tests. SDP is not tested anymore
- Add: possibility to set upper bound on residuals, helper function `assign_residual_ub!`, test of the util and docs
- Add: tests for functions in utils.jl and start_values_methods.jl
- Add: `mixed` criterion, including helper function `assign_basic_individual_criteria!` test of criterion and util and docs
- Fix: missing docstrings and faulty latex in mathematical model (check if actually went through)

## To change with PMD 0.10:
- read_measurement! in measurement_parser.jl

## v0.1.2

- Initial release
