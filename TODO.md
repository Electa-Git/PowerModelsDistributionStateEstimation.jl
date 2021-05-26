## A list of things to do for the next release (0.3.1)

- [ ] re-introduce start_values in tests and enable ubuntu tests back in CI

- [ ] update basic notebook, add non-Gaussian notebook and more non-Gaussian docs

- [ ] input through array of measurements/dataframe rather than csv
      - allows to create these directly from powerflow results without creating csv files
      - replace mktempdir etc. from the tests and use this once it is up and running

- [ ] consider deprecating reduced_ac and reduced_ivr after test against @smart_constraint (especially reduced_ac)

- [ ] increase coverage, in particular:
      - test for rand(ExtendedBeta)
      - test for GMM grad/heslogpdf
      - fix test of line 49 in pseudo_measurements.jl: investigate NUMERICAL_ERROR when sol is correct

- [ ] Add docs on Gaussian Mixture Models! Are the docs fully up to date then?

- [ ] standard bad data functionalities

## TODO for future releases

- [ ] remove functions to be deprecated (now are just warnings)
- [ ] add loads and transformer models    (?)
- [ ] convex (SDP, SOC?) state estimation (?)
- [ ] advanced bad data functionalities   (?)