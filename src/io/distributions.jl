################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsDistributionStateEstimation.jl                                    #
# An extention package of PowerModelsDistribution.jl for Static Power System   #
# State Estimation.                                                            #
################################################################################

## Exponential
# functions
heslogpdf(d::_DST.Exponential{T}, x::Real) where T<:Real = 0

## Weibull
# functions
function heslogpdf(d::_DST.Weibull{T}, x::Real) where T<:Real
    if _DST.insupport(_DST.Weibull, x)
        θ, α = _DST.params(d)
        - (α - 1) / x^2 - (α - 1) * α * x^(α - 2) / θ^(α)
    else
        zero(T)
    end
end

## Normal
# functions
heslogpdf(d::_DST.Normal{T}, x::Real) where T<:Real = -1/_DST.std(d)^2

## LogNormal
# functions
function heslogpdf(d::_DST.LogNormal{T}, x::Real) where T<:Real
    if _DST.insupport(_DST.LogNormal, x)
        μ, σ = _DST.params(d)
        ( log(x - μ) - 1 ) / ( 2σ^2 * ( x- μ )^2 ) + 1 / x^2
    else
        zero(T)
    end
end

## Beta
# functions
function heslogpdf(d::_DST.Beta{T}, x::Real) where T<:Real
    if _DST.insupport(_DST.Beta, x)
        α, β = _DST.params(d)
        - (α - 1) / x^2 - (β - 1) / (1 - x)^2
    else
        zero(T)
    end
end

## Extended Beta
# struct
"""
    ExtendedBeta

The [**extended beta distribution**](https://www.vosesoftware.com/riskwiki/Beta4distribution.php)
with shape parameters `α` and `β`, and optional support parameters `min` and
`max` has a probability density function
```math
f(x, α, β, \\text{min}, \\text{max}) =
    \\begin{cases}
        0,                                                                                              &\\text{if:}~x < \\text{min},               \\\\
        \\frac{(x-\\text{min})^{α-1} (\\text{max}-x)^{β-1}}{B(α,β) (\\text{max}-\\text{min})^{α+β-1}},  &\\text{if:}~\\text{min} ≤ x ≤ \\text{max}, \\\\
        0,                                                                                              &\\text{if:}~x > max,
    \\end{cases}
```
where B(α,β) is a Beta function.
"""
struct ExtendedBeta{T<:Real} <: _DST.ContinuousUnivariateDistribution
    α::T
    β::T
    min::T
    max::T
end

# additional constructors
ExtendedBeta(α::Real, β::Real) = ExtendedBeta(α, β, 0.0, 1.0)

# functions
scale(dst::ExtendedBeta) = (dst.α, dst.β)
params(dst::ExtendedBeta) = (dst.α, dst.β, dst.min, dst.max)
insupport(dst::ExtendedBeta, x::Real) = dst.min ≤ x ≤ dst.max

mean(dst::ExtendedBeta) = dst.min + dst.α * (dst.max - dst.min) / (dst.α + dst.β)
function mode(dst::ExtendedBeta)
    α, β, min, max = params(dst)
    if α > 1 && β > 1       return min + (α - 1) * (max - min) / (α + β - 2)
    elseif α < 1  && β ≥ 1  return min
    elseif α == 1 && β > 1  return min
    elseif α ≥ 1  && β < 1  return max
    elseif α > 1  && β == 1 return max
    elseif α ≤ 1  && β ≤ 1  error("mode is defined only when α > 1 and/or β > 1")
    end
end
skewness(dst::ExtendedBeta) =
    2 * (dst.β - dst.α) / (dst.α + dst.β + 2) * sqrt((dst.α + dst.β + 1) / (dst.α * dst.β))

function pdf(dst::ExtendedBeta{T}, x::Real) where T<:Real
    α, β, min, max = params(dst)
    if insupport(dst, x)
        (x - min)^(α - 1) * (max - x)^(β - 1) / _SF.beta(α,β) / (max - min)^(α + β - 1)
    else
        zero(T)
    end
end
function logpdf(dst::ExtendedBeta{T}, x::Real) where T<:Real
    α, β, min, max = params(dst)
    if insupport(dst, x)
        (α - 1) * log(x - min) + (β - 1) * log(max - x) - _SF.logbeta(α,β) - (α + β - 1) * log(max - min)
    else
        -T(Inf)
    end
end
function gradlogpdf(dst::ExtendedBeta{T}, x::Real) where T<:Real
    α, β, min, max = params(dst)
    if insupport(dst, x)
        (α - 1) / (x - min) - (β - 1) / (max - x)
    else
        zero(T)
    end
end
function heslogpdf(dst::ExtendedBeta{T}, x::Real) where T<:Real
    α, β, min, max = params(dst)
    if insupport(dst, x)
        - (α - 1) / (x - min)^2 - (β - 1) / (max - x)^2
    else
        zero(T)
    end
end
function maximum(dst::ExtendedBeta{T}) where T<:Real
    return params(dst)[4]
end
function minimum(dst::ExtendedBeta{T}) where T<:Real
    return params(dst)[3]
end

rand(dst::ExtendedBeta, N::Int) =
    (dst.max - dst.min) .* rand(_DST.Beta(dst.α, dst.β), N) .+ dst.min

rand(r::_RAN.AbstractRNG, dst::ExtendedBeta, N::Int) =
    (dst.max - dst.min) .* rand(r, _DST.Beta(dst.α, dst.β), N) .+ dst.min

## Gamma heslogpdf
function heslogpdf(d::_DST.Gamma{T}, x::Real) where T<:Real
    if _DST.insupport(_DST.Gamma, x)
        α, θ = _DST.params(d)
        - (α - 1) / x^2
    else
        zero(T)
    end
end
##
# gradlogpdf and heslogpdf for Gaussian mixtures done directly 
# with Distributions.jl
function gradlogpdf(d::_DST.MixtureModel, x::Real)
    @assert all([c isa _DST.Normal for c in d.components]) "Only Gaussian mixture models are supported!"
    σ = [c.σ for c in d.components]
    μ = [c.μ for c in d.components]
    γ = d.prior.p./(sqrt(2*π)*σ)
    sum([-γ[i]*(x-μ[i])*exp(-0.5*(x-μ[i])^2/σ[i]^2)*σ[i]^(-2) for i in 1:length(d.components)])/sum([γ[i]*exp(-0.5*(x-μ[i])^2/σ[i]^2) for i in 1:length(d.components)])
end

function heslogpdf(d::_DST.MixtureModel, x::Real)
    σ = [c.σ for c in d.components]
    μ = [c.μ for c in d.components]
    γ = d.prior.p./(sqrt(2*π)*σ)
    p1 = sum([γ[i]*(x-μ[i])^2*exp(-0.5*(x-μ[i])^2/σ[i]^2)*σ[i]^(-4) - γ[i]*exp(-0.5*(x-μ[i])^2/σ[i]^2)*σ[i]^(-2) for i in 1:length(d.components)])    
    p2 = sum([γ[i]*exp(-0.5*(x-μ[i])^2/σ[i]^2) for i in 1:length(d.components)]) 
    p3 = sum([-γ[i]*(x-μ[i])*exp(-0.5*(x-μ[i])^2/σ[i]^2)*σ[i]^(-2) for i in 1:length(d.components)])^2 
    p4 = sum([γ[i]*exp(-0.5*(x-μ[i])^2/σ[i]^2) for i in 1:length(d.components)])^2
    return p1/p2-p3/p4
end