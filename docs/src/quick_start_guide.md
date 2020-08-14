# Quick Start Guide

Once Ipopt, PowerModelsDSSE and PowerModelsDistribution are installed, and a
network data file (e.g. `"case3_unbalanced.dss"` in the package folder under
`./test/data/ieee/network`) has been acquired as well as a measurement data file
(e.g. `"case3_unbalanced.csv"` in the package folder under
`./test/data/ieee/meas`), an unbalanced AC Static State Estimation can be
executed with,

```julia
using Ipopt
using PowerModelsDSSE
using PowerModelsDistribution

run_mc_se("case3_unbalanced.dss", "case3_unbalanced.csv", with_optimizer(Ipopt.Optimizer))
```

## Network Data Input

### Parsing OpenDSS files

To parse an OpenDSS file into PowerModelsDistribution's default `ENGINEERING`
format, use the `parse_file` command:

```julia
eng = parse_file("case3_unbalanced.dss")
```

To get the `MATHEMATICAL` model it is possible to transform the data model
using the `transform_data_model` command.

```julia
math = transform_data_model(eng)
```

### Parsing ENWL files

To parse a specific feeder `fdr` of a network `ntw` of the ENWL data use:

```julia
data = parse_file(get_enwl_dss_path(ntw,fdr))
```

Parsing ENWL data requires the addition of a load profile before it can be
used. This may be accomplished using

```@docs
PowerModelsDSSE.insert_profiles!(data, season, devices, pfs; t=missing, useactual=true)
```

Additionally, some functions are include specifically for the ENWL data to
simplify the data in order to improve tractability.

```@docs
PowerModelsDSSE.rm_enwl_transformer!(data_eng)
```

```@docs
PowerModelsDSSE.reduce_enwl_lines_eng!(data_eng)
```

```@docs
PowerModelsDSSE.reduce_enwl_lines_math!(data_math)
```

## Measurement Data Input

Adding the measurements to a `MATHEMATICAL` data dictionary may be accomplished
through:

```@docs
PowerModelsDSSE.add_measurements!(data::Dict, meas_file::String; actual_meas = false)
```

Furthermore, functionality is included to write a measurement file, i.e., a
csv-file based on powerflow results, using:

```@docs
PowerModelsDSSE.write_measurements!(model::Type, data::Dict, pf_results::Dict, path::String)
```
