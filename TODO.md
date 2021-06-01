## A list of things to do for the next release (0.3.1)

- [ ] re-introduce start_values in tests and enable ubuntu tests back in CI (and maybe julia 1.0)

- [ ] add `create_measurement` function like in PandaPower

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

- [ ] Add docs on Gaussian Mixture Models! Are the docs fully up to date then?

- [ ] standard bad data functionalities

## TODO for future releases

- [ ] test example notebooks                               (?)
- [ ] intuitive/automatic inclusion of load/transfo models (?)
      - or MV/LV notebook?
- [ ] convex (SDP, SOC?) state estimation                  (?)
- [ ] advanced bad data functionalities                    (?)
- [ ] consider other robust estimators, e.g. schweppe huber(?)
      - with MOI/JuMP complementarity constraints ?
      - or ConditionalJuMP.jl ? Or other?