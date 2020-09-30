# Input Data Format

The data input required by PowerModelsDSSE takes the form of a dictionary and can be subdivided in three parts:

- Network data
- Measurement data
- State estimation settings

The network data contains all the information relative to the physics of the analyzed network: topology, line impedance, power demand and generation, etc..
The measurement data contains all the information relative to the available (pseudo-)measurements available for that network: number and placement of meters, measured quantities (power, voltage...) and measurement accuracy.
The state estimation settings allow the user to choose the type of estimation criterion to be used (e.g., WLS, WLAV,..) and add a weight rescaler.
More details on each of the three parts can be found in the following sections of this manual.

## Network Data Input

The network data input of PowerModelsDSSE is based on that of PowerModelsDistribution (PMD).
In the versions supported by PowerModelsDSSE, PMD allows for two input data formats:
- The `ENGINEERING` model (extensively documented [here](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/eng-data-model/))
- The `MATHEMATICAL` model
The idea behind offering two options is that the `ENGINEERING` model is quite intuitive and allows a non-developer to easily generate data and use the PMD package as made available. The `MATHEMATICAL` model allows developers to explore the details of the PMD package and/or add extra information that can be passed as additional input to go beyond the functionalities that are natively offered in PMD.
Ultimately, both PMD and PowerModelsDSSE use the `MATHEMATICAL` model to build the input for the calculations, but PMD can be provided directly an `ENGINEERING` model, which is then transformed at runtime.
This is not the case in PowerModelsDSSE, which requires measurement data and state estimation settings to perform state estimation calculations.
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

A small example of OpenDSS network data can be found in PowerModelsDSSE/test/data/extra/networks

### Parsing ENWL files

[ENWL files](https://www.enwl.co.uk/zero-carbon/innovation/smaller-projects/low-carbon-networks-fund/low-voltage-network-solutions/) are a collection of 25 real low voltage distribution networks (each of the networks' feeders is also individually accessible) and realistic demand/generation profile data, made available by the Electricity North West and The University of Manchester.

The data is available in OpenDSS-like format in PowerModelsDSSE/test/data/enwl/networks and can be parsed with the PowerModelsDistribution `parse_file` function.
A specific feeder `fdr` of a network `ntw` should be parsed to the `ENGINEERING` model, using:

```julia
eng_data = PowerModelsDistribution.parse_file(PowerModelsDSSE.get_enwl_dss_path(ntw,fdr),data_model=PowerModelsDistribution.ENGINEERING)
```

All feeders are featured with a detailed transformer model. It might be convenient or necessary to drop the transformer model and define the source bus as a slack bus: this (slightly) improves tractability and in low voltage power flow and state estimation studies, the exact substation model is often not taken into account. The removal should happen at the `ENGINEERING` data stage:

```@docs
PowerModelsDSSE.rm_enwl_transformer!(eng_data)
```

The ENWL feeders feature a high number of buses that are only used to interpolate the topology layout (i.e., where the cables are) but that host no device. Function `reduce_enwl_lines_eng!` is included specifically to simplify the data and remove the nodes and lines in excess in order to (considerably) improve tractability. It is highly recommended to use it. The resulting feeder is equivalent to the original one in terms of physical properties, and the calculation results are the same. The function can be applied both to an ENGINEERING and a MATHEMATICAL data model.

```@docs
PowerModelsDSSE.reduce_enwl_lines_eng!(eng_data)
```

```@docs
PowerModelsDSSE.reduce_enwl_lines_math!(math_data)
```

Contrary to "regular" OpenDSS files, load profile information needs to be parsed and added to the ENWL feeder ENGINEERING data obtained so far. This is accomplished using the `insert_profiles!` function:

```@docs
PowerModelsDSSE.insert_profiles!(data, season, devices, pfs; t=missing, useactual=true)
```

The ENWL data set features a number of low-carbon technologies profiles: electric vehicles (EV), electric heat pumps (EHP), micro-CHP (uCHP), photovoltaic panels (PV). "load" indicates the "traditional" residential load.

## Measurement Data

Measurement data must be added to a `MATHEMATICAL` data dictionary, of which they are a "sub-dictionary". The user can either create the measurement dictionary from scratch, or it can be imported from a csv file in the right format, with the `add_measurements!` function.

```@docs
PowerModelsDSSE.add_measurements!(data::Dict, meas_file::String; actual_meas = false)
```
An example of csv file in the right format can be found in PowerModelsDSSE/test/data/enwl/measurements/meas_data_example.csv and refers to network 1, feeder 1 of the ENWL data. The format of the csv input file is explained in the following subsection.

Furthermore, functionality is included to write a measurement file, with the `write_measurements!` function. This is useful for quick testing or when the user has no actual measurement data, and allows to generate measurement files from the results of powerflow calculations on the same network. It should be noted that this function sets the measurement errors so that they follow a Normal distribution. Other distributions are supported (see relative section of the manual), but currently there is not an automatic way to generate measurement data following them.

```@docs
PowerModelsDSSE.write_measurements!(model::Type, data::Dict, pf_results::Dict, path::String)
```

The measurement "sub-dictionary" is now incorporated in the network data dictionary, and can be showed in REPL typing data["meas"].

### The csv measurement data format

In the present section, the term "component" refers to buses, branches, loads, generators or any other element present in the network data model. These need to be addressed using the singular term/abbreviation as present in the MATHEMATICAL data model, e.g. gen for generator. In the network data model, each component is identified by a unique index number (NB: there can be both a "load 1" and a "gen 1", but there can't be two "load 1").  
The required csv measurement file features the following columns:
- meas_id: unique identifier of the given measurement. Must be an integer.
- cmp_type: indicates which component the measurement refers to: bus, load, gen, branch, etc.
- cmp_id: integer that indicates the index of the above component.
- meas_type: this is "G" if the measured quantity is between phase and neutral, "P" if between phases.
- meas_var: indicates which variable is measured. The entry must correspond to the variable name as defined in PowerModelsDistribution or PowerModelDSSE, e.g., pg for the injected power from a generator, vm for a bus voltage magnitude, etc.
- phase: phase the measurement refers to, i.e., 1, 2 or 3. If it is a three-phase measurement, this can be indicated with a "[1, 2, 3]".
- dst: type of continuous univariate distribution associated to the measurement. In the classic WLAV/WLS estimators, this is a "Normal" distribution. In this package, we allow a number of additional distributions. For details, see the manual section on "Maximum Likelihood Estimation"
- par_1: is the first of the two parameters that define the measurement error distribution. For the Normal distribution, this is the mean.
- par_2: second parameter of the distribution. For the Normal distribution this is the standard deviation.


### State estimation settings

Finally, an indication on what type of state estimation needs to be performed should be provided using the "se_settings" dictionary.
The "se_settings" dictionary contains two keys: "rescaler" and "criterion".
The "rescaler" consists of one value or an array of two values used to multiply the residual constraints (and in some cases also to put an offset on them) in the state estimation problem. Depending on the case the rescaler can improve tractability, even quite significantly. For more details on the use of the rescaler, the user can refer to the "State Estimation Criteria" section of this manual.
The "criterion" allows the user to choose the "type" of state estimation to be performed, the classic examples being weighted least squares (WLS) and weighted least absolute values (WLAV). For details on which criteria are available and how to use them, the user is again referred to the "State Estimation Criteria" section of this manual.

If the user does not provide any "se_settings", this dictionary automatically created when running state estimation calculations, and set to the default rescaler value of 1 and estimation criterion of "rwlav":

```julia
"se_settings" => Dict{String,Any}(
    "rescaler" => 1,
    "criterion" => "rwlav"
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
        "criterion" => "chosen_criterion"  
    ),
    ...
)
```

NB: do not confuse the "se_settings" dictionary key with the "settings" dictionary key, which is also present in the PowerModelsDistribution network data format.

## Putting everything together: complete input data

The following script allows the user to visualize the various steps to build the data and display final structure:

```julia

data = _PMD.parse_file(joinpath(BASE_DIR, "test/data/extra/networks/case3_unbalanced.dss"); data_model=MATHEMATICAL) #parses the network data
msr_path = joinpath(BASE_DIR, "test/data/extra/measurements/case3_meas.csv") # indicates the path to measurement data csv file
_PMS.add_measurements!(data, msr_path, actual_meas = false)                  # adds the measurement data to the network data dictionary
data["se_settings"] = Dict{String,Any}("criterion" => "rwlav", 
                                        "rescaler" => rescaler)# adds the state estimation settings to the data
display(data)                                                                # displays the first "layer" of the dictionary. The internal structure can be "navigated" like any other dictionary

```
