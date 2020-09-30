################################################################################
#  Copyright 2020, Marta Vanin, Tom Van Acker                                  #
################################################################################
# PowerModelsSE.jl                                                             #
# An extention package of PowerModels(Distribution).jl for Static Power System #
# State Estimation.                                                            #
################################################################################
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
