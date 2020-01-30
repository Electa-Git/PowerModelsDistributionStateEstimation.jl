my_f(x,y) = 2x + 3y
derivative_of_my_f(x,y) = ForwardDiff.derivative(x -> my_f(x,y),x)
