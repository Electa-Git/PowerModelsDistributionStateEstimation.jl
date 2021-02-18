## A list of things to do for v0.3.0

- [ ] update code for PMD v0.10.2 once it is released (!)
      - unlock single-phase buses and branches
      - re-introduce start_values in tests and enable ubuntu tests back

- [ ] fix StatsPlots dependency

- [ ] update to InfrastructureModels 0.6.0

- [ ] update Pluto notebook

- [ ] quantify rescaler for non-gaussian

- [ ] investigate techniques to speed up code (continuous effort)

- [ ] input through array of measurements rather then csv

- [ ] consider deprecating reduced_ac and reduced_ivr after test against @smart_constraint (especially reduced_ac)

- [ ] increase coverage, in particular:
      - test for rand(ExtendedBeta)
      - test for GMM grad/heslogpdf
      - bring back test of line 49-50 in pseudo_measurements.jl

- [ ] Fix missing docstrings and faulty latex in mathematical model, update docs

## TODO before 0.X

- [ ] add loads and transformer models (v0.3?)?
