## A list of things to do for v0.3.0

- [ ] allow single-phase buses and branches measurements in automatic parser and se itself
      - add test where you parse .m file and solve one-conductor SE

- [ ] re-introduce start_values in tests and enable ubuntu tests back in CI

- [ ] update Pluto notebook, add non-Gaussian notebook

- [ ] input through array of measurements rather then csv

- [ ] consider deprecating reduced_ac and reduced_ivr after test against @smart_constraint (especially reduced_ac)

- [ ] increase coverage, in particular:
      - test for rand(ExtendedBeta)
      - test for GMM grad/heslogpdf
      - bring back test of line 49-50 in pseudo_measurements.jl

- [ ] Fix missing docstrings and faulty latex in mathematical model, update docs

## TODO before 0.X

- [ ] add loads and transformer models (v0.3?)?
