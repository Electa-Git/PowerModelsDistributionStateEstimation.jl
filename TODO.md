## A list of things to do for the next release (0.4.1)

- [ ] update basic notebook (add bad data in it), add non-Gaussian notebook and more non-Gaussian docs

- [ ] input through array of measurements/dataframe rather than csv
      - allows to create these directly from powerflow results without creating csv files
      - replace mktempdir etc. from the tests and use this once it is up and running

- [ ] consider deprecating reduced_ac and reduced_ivr after test against @smart_constraint (especially reduced_ac)

- [ ] increase coverage, in particular:
      - test "ls" and "lav" (no weights)
      - test for rand(ExtendedBeta)
      - test for GMM grad/heslogpdf
      - fix test of line 49-50 in pseudo_measurements.jl: in 50, NUMERICAL_ERROR when sol is correct, in 49 EXCEPTION_ACCESS_VIOLATION at 0x2e2075e6 -- mumps_cst_amf_ in windows CI
      - re-introduce start_values in tests and enable ubuntu tests back in CI (and maybe julia 1.0)
      - lines 228, 232-234 in bad_data.jl and move atol to 1.1e-3 in with_errors.jl line 186

## TODO for future releases/research wishlist

- [ ] try rescale ENWL database per MVA                    (?)
- [ ] test example notebooks                               (?)
- [ ] intuitive/automatic inclusion of load/transfo models (?)
      - or MV/LV notebook?
- [ ] additional (convex?) formulations                    (?)
- [ ] advanced bad data functionalities                    (?)
- [ ] consider other robust estimators, e.g. schweppe huber(?)
      - with MOI/JuMP complementarity constraints ?
      - or ConditionalJuMP.jl ? Or other?
- [ ] find/build 4-wire test case and test                  