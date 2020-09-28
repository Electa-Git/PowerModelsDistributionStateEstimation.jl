####################################################
# This file contains the second derivatives of the
# univariate continuous distributions that are available for MLE.
# For the univariate distribution, the first derivative is also provided, as
# not available in Distributions.jl .
# The first and second derivatives are then provided as input to JuMP, so that
# automatic differentiation is not required. This reduces the computational effort.
###################################################

function heslogpdf(d::_DST.Weibull{T}, x::Real) where T<:Real
    if _DST.insupport(Weibull, x)
        α, θ = _DST.params(d)
        - (α - 1) / x^2 - (α - 1)* α * x^(α - 2) / θ^(α)
    else
        zero(T)
    end
end

heslogpdf(d::_DST.Normal{T}, x::Real) where T<:Real = -1/_DST.std(d)^2

heslogpdf(d::_DST.Exponential{T}, x::Real) where T<:Real = 0

function heslogpdf(d::_DST.Gamma{T}, x::Real) where T<:Real
    if _DST.insupport(Gamma, x)
        α, θ = _DST.params(d)
        - (α - 1) / x^2
    else
        zero(T)
    end
end

function heslogpdf(d::_DST.Beta{T}, x::Real) where T<:Real
    if _DST.insupport(Beta, x)
        α, θ = _DST.params(d)
        - (α - 1) / x^2 - (θ - 1) / (1 - x^2)
    else
        zero(T)
    end
end

function heslogpdf(d::_DST.LogNormal{T}, x::Real) where T<:Real
    if _DST.insupport(LogNormal, x)
        μ, σ = _DST.params(d)
        ( log(x) - μ + σ^2 -1 ) / ( σ^2 * x^2 )
    else
        zero(T)
    end
end

function get_distribution_derivatives(d, x)
    if typeof(d) <: _DST.Uniform
        #NB: gradlogpdf is not defined for _DST.Uniform in Distributions.jl
        grd(x) = 0
        hes(x) = 0
    else
        grd(x) = _DST.gradlogpdf(d,x)
        hes(x) = PowerModelsDSSE.heslogpdf(d,x)
    end
end
