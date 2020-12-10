# Input Data Format

The data input required by PowerModelsDistributionStateEstimation takes the form of a dictionary and can be subdivided in three parts:

- Network data
- Measurement data
- State estimation settings

The network data contains all the information relative to the physics of the analyzed network: topology, line impedance, power demand and generation, etc..
The measurement data contains all the information relative to the available (pseudo-)measurements available for that network: number and placement of meters, measured quantities (power, voltage...) and measurement accuracy.
The state estimation settings allow the user to choose the type of estimation criterion to be used (e.g., WLS, WLAV,..) and add a weight rescaler.
More details on each of the three parts can be found in the following sections of this manual.

## Network Data Input

The network data input of PowerModelsDistributionStateEstimation is based on that of PowerModelsDistribution (PMD).
In the versions supported by PowerModelsDistributionStateEstimation, PMD allows for two input data formats:
- The `ENGINEERING` model (extensively documented [here](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/eng-data-model/))
- The `MATHEMATICAL` model
The idea behind offering two options is that the `ENGINEERING` model is quite intuitive and allows a non-developer to easily generate data and use the PMD package as made available. The `MATHEMATICAL` model allows developers to explore the details of the PMD package and/or add extra information that can be passed as additional input to go beyond the functionalities that are natively offered in PMD.
Ultimately, both PMD and PowerModelsDistributionStateEstimation use the `MATHEMATICAL` model to build the input for the calculations, but PMD can be provided directly an `ENGINEERING` model, which is then transformed at runtime.
This is not the case in PowerModelsDistributionStateEstimation, which requires measurement data and state estimation settings to perform state estimation calculations.
These two take the form of "sub-dictionaries" that need to be appended to a PMD `MATHEMATICAL` network data model dictionary. If added to the `ENGINEERING` data model, they will be ignored in the transformation to the `MATHEMATICAL` model, returning an error.
For additional information on the network data input, the user is referred to the [PMD manual](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/).
The user can build the network data from scratch, for example writing a native julia parser that builds the dictionary starting from external files, or reading an otherwise created JSON file with the right dictionary structure.
However, to encourage the use and creation of easily reproducible test cases, two network data parsers are made available, for the following files:
- OpenDSS files, for which we use the parsers from PowerModelsDistribution,
- A native ENWL files parser, courtesy of Sander Claeys ([@sanderclaeys](https://github.com/sanderclaeys)).

### Parsing OpenDSS files

To parse an OpenDSS file into PowerModelsDistribution's default `ENGINEERING`
format, use the `parse_file` function:

```julia
eng = PowerModelsDistribution.parse_file("path/to/file/file_name.dss")
```

To obtain the `MATHEMATICAL` model it is possible to transform the data model
using the `transform_data_model` function.

```julia
math = PowerModelsDistribution.transform_data_model(eng)
```

A small example of OpenDSS network data can be found in PowerModelsDistributionStateEstimation/test/data/extra/networks

### Parsing ENWL files

[ENWL files](https://www.enwl.co.uk/zero-carbon/innovation/smaller-projects/low-carbon-networks-fund/low-voltage-network-solutions/) are a collection of 25 real low voltage distribution networks (each of the networks' feeders is also individually accessible) and realistic demand/generation profile data, made available by the Electricity North West and The University of Manchester.

The data is available in OpenDSS-like format in PowerModelsDistributionStateEstimation/test/data/enwl/networks and can be parsed with the PowerModelsDistribution `parse_file` function.
A specific feeder `fdr` of a network `ntw` should be parsed to the `ENGINEERING` model, using:

```julia
eng_data = PowerModelsDistribution.parse_file(PowerModelsDistributionStateEstimation.get_enwl_dss_path(ntw,fdr),data_model=PowerModelsDistribution.ENGINEERING)
```

All feeders are featured with a detailed transformer model. It might be convenient or necessary to drop the transformer model and define the source bus as a slack bus: this (slightly) improves tractability and in low voltage power flow and state estimation studies, the exact substation model is often not taken into account. The removal should happen at the `ENGINEERING` data stage:

```@docs
PowerModelsDistributionStateEstimation.rm_enwl_transformer!(eng_data)
```

The ENWL feeders feature a high number of buses that are only used to interpolate the topology layout (i.e., where the cables are) but that host no device. Function `reduce_enwl_lines_eng!` is included specifically to simplify the data and remove the nodes and lines in excess in order to (considerably) improve tractability. It is highly recommended to use it. The resulting feeder is equivalent to the original one in terms of physical properties, and the calculation results are the same. The function can be applied both to an ENGINEERING and a MATHEMATICAL data model.

```@docs
PowerModelsDistributionStateEstimation.reduce_enwl_lines_eng!(eng_data)
```

```@docs
PowerModelsDistributionStateEstimation.reduce_enwl_lines_math!(math_data)
```

Contrary to "regular" OpenDSS files, load profile information needs to be parsed and added to the ENWL feeder ENGINEERING data obtained so far. This is accomplished using the `insert_profiles!` function:

```@docs
PowerModelsDistributionStateEstimation.insert_profiles!(data, season, devices, pfs; t=missing, useactual=true)
```

The ENWL data set features a number of low-carbon technologies profiles: electric vehicles (EV), electric heat pumps (EHP), micro-CHP (uCHP), photovoltaic panels (PV). "load" indicates the "traditional" residential load.

## Measurement Data

Measurement data must be added to a `MATHEMATICAL` data dictionary, of which they are a "sub-dictionary". The user can either create the measurement dictionary from scratch, or it can be imported from a csv file in the right format, with the `add_measurements!` function. The measurement data in the csv file can be both real measurements (i.e., with an error), or "fake"/"ideal" measurements with no error. The function provides a functionality to add an error to "fake"/"ideal" measurements sampling the error from a Normal distribution. See the following:
```@docs
PowerModelsDistributionStateEstimation.add_measurements!(data::Dict, meas_file::String; actual_meas::Bool = false, seed::Int=0)
```
An example of csv file in the right format can be found in PowerModelsDistributionStateEstimation/test/data/enwl/measurements/meas_data_example.csv and refers to network 1, feeder 1 of the ENWL data. The format of the csv input file is explained in the following subsection.

Furthermore, functionality is included to write a measurement file, with the `write_measurements!` function. This is useful for quick testing or when the user has no actual measurement data, and allows to generate measurement files from the results of powerflow calculations on the same network. It should be noted that this function sets the measurement errors so that they follow a Normal distribution.

```@docs
PowerModelsDistributionStateEstimation.write_measurements!(model::Type, data::Dict, pf_results::Dict, path::String)
```

The measurement "sub-dictionary" is now incorporated in the network data dictionary, and can be showed in REPL typing data["meas"].

If there are pseudo measurements, or the user wants to explicitly describe measurements as non-Gaussian probability distributions, the same rules apply: either the measurements are provided as a csv file, or they can be created with the `write_measurements_and_pseudo!` function.
```@docs
PowerModelsDistributionStateEstimation.write_measurements_and_pseudo!(model::Type, data::Dict, pf_results::Dict, path::String; exclude::Vector{String}=String[], distribution_info::String, σ::Float64=0.005)
```
Please note that this function has only been fully tested with the `ExtendedBeta` distribution. Some functionalities, such as the per unit conversion of pdfs whose parameters are not in per unit might not work for other distributions. Providing distributions that are already in per unit might allow to use this function directly, but it is not guaranteed.
Furthermore, some assumptions need to hold to be able to correctly use this function:
- The distributions provided refer to active power pseudo measurements. The same distributions are scaled using the power factor to represent the reactive power of the same load.
- The format of the external file with distribution information matches the example one: test/data/extra/measurements/distr_example.csv.

In general, it is advised that users that intend to recur to non-Gaussian distributions build their own measurement creator/parser.

As state in the function description, the `data["load"]` dictionary entries of pseudo measurements need to point to the distribution file. A helper function is provided for this purpose as well:
```@docs
PowerModelsDistributionStateEstimation.assign_load_pseudo_measurement_info!(data::Dict, pseudo_load_list::Array, cluster_list::Array, csv_path::String; time_step::Int64=1, day::Int64=1)
```

### The csv (pseudo) measurement data format

In the present section, the term "component" refers to buses, branches, loads, generators or any other element present in the network data model. These need to be addressed using the singular term/abbreviation as present in the MATHEMATICAL data model, e.g. gen for generator. In the network data model, each component is identified by a unique index number (NB: there can be both a "load 1" and a "gen 1", but there can't be two "load 1").  
The required csv measurement file features the following columns:
- meas_id: unique identifier of the given measurement. Must be an integer.
- cmp_type: indicates which component the measurement refers to: bus, load, gen, branch, etc.
- cmp_id: integer that indicates the index of the above component.
- meas_type: this is "G" if the measured quantity is between phase and neutral, "P" if between phases.
- meas_var: indicates which variable is measured. The entry must correspond to the variable name as defined in PowerModelsDistribution or PowerModelsDistributionStateEstimation, e.g., pg for the injected power from a generator, vm for a bus voltage magnitude, etc.
- phase: phase the measurement refers to, i.e., 1, 2 or 3. If it is a three-phase measurement, this can be indicated with a "[1, 2, 3]".
- dst: type of continuous univariate distribution associated to the measurement. In the classic WLAV/WLS estimators, this is a "Normal" distribution. In this package, we allow a number of additional distributions. For details, see the manual section on "Maximum Likelihood Estimation"
- par_1: is the first of the two parameters that define the measurement error distribution. For the Normal distribution, this is the mean.
- par_2: second parameter of the distribution. For the Normal distribution this is the standard deviation.
- par_3: can be missing or string, if the distribution requires a third parameter.
- par_4: can be missing or string, if the distribution requires a third parameter.
- crit: can be missing, or it assigns an individual SE criterion to the measurement in a given row (see [Mathematical Model of the State Estimation Criteria](@ref)).
- parse: can be true or false (or missing). It should be true if the measurement provided are real measurements (i.e., with errors). It should be false if the measurements are not real but, e.g., generated with power flow calculations (i.e., they have no errors). In this case, a value with error is sampled from the distribution associated to the measurements, and used in the state estimation process.

Note that the error parsing only works for Normal distributions. It will not return an error for non-Normal distributions, but will default to the same behaviour as setting parse to false.

The last three columns are optional and don't necessarily need to be part of the CSV files. If a row/measurement is characterized by a distribution that requires 4 parameters, while the rest of them only require 2, the par_3 and par_4 columns of all other measurements need to have "missing" values, which will be ignored. Similarly, "missing" values in the other optional columns can be set, and they are ignored.

### The csv distribution file format

This section explains the format of the csv file that contains information relative to probability distribution for pseudo measurements.
An example is test/data/extra/measurements/distr_example.csv.
The file has the following columns:
- day: day to which the distribution refers, integer
- time_step: time step to which the distribution refers, integer
- cluster: load profile group or cluster, integer
- par_1,par_2,par_2,par_4: parameters of the distribution, if less than four are required, can be missing. Otherwise, they are floats
- distr: distribution type, string
- per_unit: boolean, indicates whether the distribution has been rescaled to the unit values used in the SE calculations (true) or not (false). It is advised to used rescaled distributions.
- PF: power factor. This is used to apply the same distribution, which is assumed to refer to the active power, to the reactive power

### The final dictionary format

In general, the measurement information needs to be correctly provided in the `data["meas"]` sub-dictionary, as ultimately it is this which is used for the calculations. It is to the user to make sure that this is the case, regardless of which helper functions and files are used.
Each measurement "m" needs to be unique, and should be similar to measurement "1" here:
```julia
data["meas"]["1"] => Dict{String,Any}(
    "var" => :pd,
    "cmp" => :load,
    "cmp_id" => 4
    "dst" => Any[ExtendedBeta{Float64}(α=1.18, β=7.1, min=-3.28684e-8, max=1.44621e-5), 0.0, 0.0],
    "crit" => "rwlav"
)
```
`var` is the variable to which the measurement refers. In this case, active power.
`cmp` is the component type to which the measurement refers. In this case, a load.
`cmp_id` is the unique id of this component.
`dst` is a vector that contains the pdf of the measurement, for each phase separately and scaled to the correct units. At the moment, this is always a 3x1 vector, and phases to which loads are not used are assigned a 0.0. **This is going to change very soon** when upgrading to PowerModelsDistribution v0.10.0, in v0.2.0 of the present package. We will do our best to keep the docs up to date but there might be a delay.
`crit` string that indicates the measurement's SE criterion, see [Mathematical Model of the State Estimation Criteria](@ref).

## State estimation settings

Finally, an indication on what type of state estimation needs to be performed should be provided using the "se_settings" dictionary.
The `se_settings` dictionary contains up to three keys: `rescaler`, `criterion` and `number_of_gaussian`.
The `rescaler` is a Float that multiplies the residual constraints. Depending on the specific case and solver, adding a rescaler can improve tractability, even quite significantly. If no entry is provided, this defaults to 1.0.
The `criterion` is a String and allows the user to choose a **global** residual definition for all measurements. If different measurements need to have different criteria, this shouldn't be used, but rather a local individual needs to be assigned to each measurement. For details on which criteria are available and how to use them, see [Mathematical Model of the State Estimation Criteria](@ref). If no entry is provided, no action is taken, as individual criterion assignment is assumed.
The `number_of_gaussian` is an Int and is only resorted to when the Gaussian Mixture criterion is chosen. In this context, it represents the number of Gaussian components of the model. If no entry is provided, this defaults to 10.
```julia
"se_settings" => Dict{String,Any}(
    "rescaler" => 10,
    "criterion" => "gmm", #only for global criterion assignment
    "number_of_gaussian" => 6
)
```

At this point, the data dictionary should have a structure similar to this:

```julia
Dict{String,Any}(
    "data_model" => MATHEMATICAL,
    "component_type" => Dict{Any,Dict{String,Any}}(
        id => Dict{String,Any}(
            "parameter" => value,
            ...
        ),
        ...
    ),
    "meas" => Dict{Any,Dict{String,Any}}(
        id => Dict{String,Any}(
            "parameter" => value,
            ...
        ),
        ...
    ),
    "se_settings" => Dict{String,Any}(
        "rescaler" => value,
        "criterion" => "chosen_criterion" #only for global criterion assignment
    ),
    ...
)
```

NB: do not confuse the "se_settings" dictionary key with the "settings" dictionary key, which is also present in the PowerModelsDistribution network data format.

## Putting everything together: complete input data

The following script allows the user to visualize the various steps to build the data and display final structure:

```julia

data = parse_file(joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss"); data_model=MATHEMATICAL) #parses the network data
msr_path = joinpath(BASE_DIR, "test/data/extra/measurements/case3_meas.csv") # indicates the path to measurement data csv file
add_measurements!(data, msr_path, actual_meas = false)                  # adds the measurement data to the network data dictionary
data["se_settings"] = Dict{String,Any}("criterion" => "rwlav",
                                        "rescaler" => rescaler)# adds the state estimation settings to the data
display(data)                                                                # displays the first "layer" of the dictionary. The internal structure can be "navigated" like any other dictionary

```
