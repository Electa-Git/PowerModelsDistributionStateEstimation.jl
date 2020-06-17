This section reports the allowed measured quantities, together with the expressions that convert them to a different variable space,
if they are not native to the space of the formulation they are associated to.


Table I: summary of allowed measured variables and conversions

| | vm | va | cmx | cax | crx | cix | px | qx | vr | vi |
|-----|----|----|-----|-----|-----|-----|----|----|----|----|
| **ACP** | N  | N  | SF  | AT  | F   | F   | N  | N  | X  | X  |
| **ACR** | SF | AT | SF  | AT  | SF  | SF  | N  | N  | N  | N  |
| **IVR** | SF | AT | SF  | AT  | N   | N   | M  | M  | N  | N  |

Where: <br />
N: no conversion needed (the variable is part of the formulation's space) <br />
X: not provided <br />
AT: conversion of type ArcTangent <br />
SF: conversion of type SquareFraction <br />
M: conversion of type Multiplication <br />
F: conversion of type Fraction <br />

The x in cmx, cax, etc.. indicates that the conversion is valid for all the following component type: branch, gen and load, for which they would be written as cm, cmg (gen), cmd (load), ca, cag, cad, etc.

Although they have been available, it is not advisable that the user relies on the AT conversions, as the optimizer might fail to identify the correct quadrant.

A guess is made in the conversion type definition, to assign the measure to the most likely quadrant. However, this might change from system to system or if a system is rather unbalanced. This can lead to convergence issues or large errors on the estimation. 

In table 2 below, a description of the actual conversion formula is provided.

| | vm | va | cmx | cax | crx | cix | px | qx | vr | vi |
|-----|----|----|-----|-----|-----|-----|----|----|----|----|
| **ACP** | N  | N  | cmx<sup>2</sup> = (px<sup>2</sup>+qx<sup>2</sup>)/vm<sup>2</sup>  | cax = va-tan<sup>-1</sup>(qx/px)  | crx = (px\*cos(va)+qx\*sin(va))/vm   | cix = (-qx \*cos(va)+px\*sin(va))/vm   | N  | N  | X  | X  |
| **ACR** | vm<sup>2</sup> = (vi<sup>2</sup>+vr<sup>2</sup>)/1 | va = tan<sup>-1</sup>(vi/vr) | cmx<sup>2</sup> = (px<sup>2</sup>+qx<sup>2</sup>)/vm<sup>2</sup>  | cax = tan<sup>-1</sup>(vi/vr)-tan<sup>-1</sup>(qx/px)  | crx = (px\*vr+qx\*vi)/(vr<sup>2</sup>+vi<sup>2</sup>)  | cix = (px\*vi-qx\*vr)/(vr<sup>2</sup>+vi<sup>2</sup>)  | N  | N  | N  | N  |
| **IVR** | vm<sup>2</sup> = (vi<sup>2</sup>+vr<sup>2</sup>)/1 | va = tan<sup>-1</sup>(vi/vr) | cmx<sup>2</sup> = (cix<sup>2</sup>+crx<sup>2</sup>)/1  | cax = tan<sup>-1</sup>(cix/crx)  | N   | N   | px = vr\*crx+vi\*cix  | qx = vi\*crx-vr\*cix  | N  | N  |
