```
  a is the real part of a complex variable,
  a is the imaginary part.
  it is similar to atan(b, a) <- note the inversion of the arguments
  it is taken from reference: http://www-labs.iro.umontreal.ca/~mignotte/IFT2425/Documents/EfficientApproximationArctgFunction.pdf
```
function arctangent_approximation1(a,b)
    x = b/a
    arctan = π/4*x+0.273*x*(1-abs(x))

end

```
this one does not have an absolute value, which might complicate stuff
```
function arctangent_approximation2(a,b)
   x = b/a
   arctan = x/(1 + 0.28125*x^2)
end

function test_approximations(angle_in_degrees)

   real_part = cos(deg2rad(angle_in_degrees))
   imag_part = sin(deg2rad(angle_in_degrees))

   app1 = arctangent_approximation1(real_part, imag_part)
   app2 = arctangent_approximation2(real_part, imag_part)
   at = atan(imag_part, real_part)

   return app1,app2,at
end
