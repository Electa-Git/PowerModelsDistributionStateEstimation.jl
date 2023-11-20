## A list of things to do for the next release (0.8.0)

- [ ] enable (and test) 4-wire with explicit neutral

- [ ] directly incorporate transformer models from PowerModelsDistribution

- [ ] remove CI if this file or README is updated

- [ ] import/export pdf, etc. from Distributions.jl? simplify residual constraint

- [ ] update basic notebook (add bad data), add non-Gaussian notebook and more non-Gaussian docs

- [ ] input through array of measurements/dataframe rather than csv
      - allows to create these directly from powerflow results without creating csv files
      - replace mktempdir etc. from the tests and use this once it is up and running
      - cannot remove CSV dep because of ENWL parsing, but maybe there is a workaround? (like putting ENWL data in another repo except tests, see below)

- [ ] consider deprecating reduced_ac and reduced_ivr after test against @smart_constraint (especially reduced_ac)

- [ ] increase coverage, in particular:
      - for all measurement conversions, check that the variables of the DSSE result dict match
      - test "ls" and "lav" (no weights)
      - test for rand(ExtendedBeta)
      - test for mles with various distributions
      - test with more measurement conversions
      - fix test of line 49-50 in pseudo_measurements.jl: in 50, NUMERICAL_ERROR when sol is correct, in 49 EXCEPTION_ACCESS_VIOLATION at 0x2e2075e6 -- mumps_cst_amf_ in windows CI
      - re-introduce start_values in tests and enable ubuntu tests back in CI (julia 1.6 as LTS will move, see below)
      - lines 228, 232-234 in bad_data.jl and move atol to 1.1e-3 in with_errors.jl line 186
      
- [ ] nw_id_default: ask _PMD to export sol_component_value so we can do without InfrastructureModels dep

- [ ] in `measurement_conversion.jl` remove all `d`s, `g`s, ... from power and current measurements, and just _PMD.ref the component they refer to based on the measurement index? (NOTE: this is breaking and would have an impact on the measurement creation / parsing. Maybe add a deprecation warning?)
