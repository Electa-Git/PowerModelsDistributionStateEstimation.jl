# Measurement Conversion

## Introduction

Any network formulation has a specific variable space, e.g., ACP includes `vm`,
`va`, `px` and `qx`[^1]. `w` = `vm^2` is the lifted voltage variable native to branch flow conic and linear forms.
The conversions for the reduced formulations work identically as their non-reduced equivalent.

[^1]: The **x** in `px`, `qx`, `cmx`, `cax`, `crx` and `cix`
      indicates that these variables exists for branches (~), generators (g) and
      loads (-). In order to capture the variable for a specific element it
      should be rewritten, e.g., `"px"` respectively becomes `"p"`, `"pg"` and
      `"pd"`.

| -         | vm  | va  | cmx | cax | crx | cix | px  | qx  | vr  | vi  |  w  |
| :-------- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| **ACP**   | N   | N   | SF  | X   | F   | F   | N   | N   | X   | X   | X  |
| **ACR**   | S  | PP  | SF  | X   | MF  | MF  | N   | N   | N   | N   |  X  |
| **IVR**   | S  | PP  | S  | PP  | N   | N   | M   | M   | N   | N   |   X  |
| **SDP**   | X  |  X  | X | X   | X   | X   | N*   | N*   | X   | X   |  N  |
| **LD3F**  | S  |  X  | SF | X   | X   | X   | N   | N   | X   | X   |   N  |

where:
- F:  conversion of type Fraction
- M:  conversion of type Multiplication
- MF: conversion of type MultiplicationFraction
- N:  native to the network formulation
- PP: conversion of type Tangent
- S: conversion of type Square
- SF: conversion of type SquareFraction
- X:  not provided

The N* in the SDP formulation indicates that those variable are only native for
generators, loads and other devices/extensions, but not for measurements that
refer to branch flows, yet.

## Conversions

Certain measurement variables may not be natively supported in the formulation
space. Consequently, it becomes necessary to convert them into that specific
space. This is accomplished through the inclusion of an additional
constraint(s). The different types of conversion constraints are enumerated in
what follows.

### Tangent

The conversion type `Tangent`  allows to include `va` measurements in the
ACR and IVR formulation, and `cax` measurements in the IVR formulation,
respectively through:
```math
\begin{eqnarray}
      \tan(\text{va})   &= \frac{\text{vi}}{\text{vr}}              \\
      \tan(\text{cax})  &= \frac{\text{cix}}{\text{crx}}
\end{eqnarray}
```
These are non-linear equality constraints, modeled using `@NLconstraint`.

### Fraction

The conversion type `Fraction` allows to include `crx` and `cix` measurements
in the ACP formulation, respectively through:
```math
\begin{eqnarray}
      \text{crx} &= \frac{\text{px}\cdot\cos(\text{va})+\text{qx}\cdot\sin(\text{va})}{\text{vm}} \\
      \text{cix} &= \frac{\text{px}\cdot\sin(\text{va})-\text{qx}\cdot\cos(\text{va})}{\text{vm}}
\end{eqnarray}
```
These are non-linear equality constraints, modeled using `@NLconstraint`.

### Multiplication

The conversion type `Multiplication` allows to include `px` and `qx`
measurements in the IVR formulation, respectively through:
```math
\begin{eqnarray}
      \text{px} &= \text{vr}\cdot\text{crx} + \text{vi}\cdot\text{cix} \\
      \text{qx} &= \text{vi}\cdot\text{crx} - \text{vr}\cdot\text{cix}
\end{eqnarray}
```
These are quadratic equality constraints, modeled using `@constraint`.

### MultiplicationFraction

The conversion type `MultiplicationFraction` allows to include `crx` and `cix`
measurements in the ACR formulation, respectively through:
```math
\begin{eqnarray}
      \text{crx} &= \frac{\text{px}\cdot\text{vr}+\text{qx}\cdot\text{vi}}{\text{vr}^{2}+\text{vi}^{2}} \\
      \text{cix} &= \frac{\text{px}\cdot\text{vi}-\text{qx}\cdot\text{vr}}{\text{vr}^{2}+\text{vi}^{2}} \\
\end{eqnarray}
```
These are non-linear equality constraints, modeled using `@NLconstraint`.

### SquareFraction

The conversion type `SquareFraction` allows to include `cmx` measurements in the ACP and ACR
formulation, through:
```math
\begin{equation}
      \text{cmx}^{2} = \frac{\text{px}^{2} + \text{qx}^{2}}{\text{vm}^{2}}  
\end{equation}
```
If the conversion is applied to the LinDist3Flow formulation, then vm^2 is replaced by w.
These are non-linear equality constraints, modeled using `@NLconstraint`.

### Square

The conversion type `Square` allows to include `vm` measurements in the
ACR and IVR formulation, and `cmx` measurements in the IVR
formulation, respectively through:
```math
\begin{eqnarray}
      \text{vm}^{2}     &= \text{vi}^{2} + \text{vr}^{2}                  \\
      \text{cmx}^{2}    &= \text{cix}^{2} + \text{crx}^{2}    
\end{eqnarray}
```
These are quadratic equality constraints, modeled using `@constraint`.

### No conversion provided
As displayed in the Table, some conversions are not provided. This is because the measured quantities are either unlikely to take place in practice, e.g., w, or tend to appear in pairs, e.g., cmx and cax with PMUs. In the latter case, it is more efficient to transform cax and cmx into rectangular variables a priori and then use them, for instance, with IVR.

## Functions to create and edit measurements

TODO!
