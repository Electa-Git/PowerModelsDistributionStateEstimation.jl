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
      - test "ls" and "lav" (no weights)
      - test for rand(ExtendedBeta)
      - test for mles with various distributions
      - test with more measurement conversions
      - fix test of line 49-50 in pseudo_measurements.jl: in 50, NUMERICAL_ERROR when sol is correct, in 49 EXCEPTION_ACCESS_VIOLATION at 0x2e2075e6 -- mumps_cst_amf_ in windows CI
      - re-introduce start_values in tests and enable ubuntu tests back in CI (julia 1.6 as LTS will move, see below)
      - lines 228, 232-234 in bad_data.jl and move atol to 1.1e-3 in with_errors.jl line 186

- [ ] increase dependency bound on Distributions.jl
      
- [ ] nw_id_default: _IM to _PMD. to rm _IM dep, sol_component_value should should be replaced (ask _PMD people to export it?)

## (possible) TODO for future releases/research wishlist

- [ ] facilitate change ENWL database power_base           
- [ ] add tests on example notebooks                       
- [ ] intuitive/automatic inclusion of load/transfo models 
      - or MV/LV notebook?
- [ ] additional (convex?) formulations                    
- [ ] advanced bad data functionalities                    
- [ ] consider other robust estimators, e.g. schweppe huber
      - with MOI/JuMP complementarity constraints ?
      - or ConditionalJuMP.jl ? Or other?
- [ ] de-localize ENWL dataset to other repo (except feeders used in tests)        
- [ ] impl. own Gauss-Newton solver and matrix functions   
