@testset "Distributions" begin

# Testing the second derivative of distributions provided by Distributions.jl
@test isapprox(_PMDSE.heslogpdf(_DST.Exponential(100.0),100.0),  0.0,     atol=1e-8)
@test isapprox(_PMDSE.heslogpdf(_DST.Weibull(3.0,100.0),2.0),   -24.75,    atol=1e-8)
@test isapprox(_PMDSE.heslogpdf(_DST.Normal(100.0,5.0),45.0),   -0.04,    atol=1e-8)
@test isapprox(_PMDSE.heslogpdf(_DST.LogNormal(1.0, 1.0),3.0), 0.07275451 , atol=1e-8)
@test isapprox(_PMDSE.heslogpdf(_DST.Beta(2.0,4.0),0.5),        -16.00,   atol=1e-8)
@test isapprox(_PMDSE.heslogpdf(_DST.Gamma(2.0, 3.0),10.0),  -0.01,  atol=1e-8)

# An extended Beta distribution with support [0,1] should reduce to the 'normal'
# Beta distribution
alt = _DST.Beta(2.0,4.0)
dst = ExtendedBeta(2.0,4.0,0.0,1.0)
@test isapprox(_DST.mean(alt), _PMDSE.mean(dst),                          atol=1e-8)
@test isapprox(_DST.mode(alt), _PMDSE.mode(dst),                          atol=1e-8)
@test isapprox(_DST.skewness(alt), _PMDSE.skewness(dst),                  atol=1e-8)
@test isapprox(_DST.pdf(alt,0.5), _PMDSE.pdf(dst,0.5),                    atol=1e-8)
@test isapprox(_DST.logpdf(alt,0.5), _PMDSE.logpdf(dst,0.5),              atol=1e-8)
@test isapprox(_DST.gradlogpdf(alt,0.5), _PMDSE.gradlogpdf(dst,0.5),      atol=1e-8)

# Testing logpdf/gradlogpdf/heslogpdf of the extended beta distribution
dst = ExtendedBeta(2.0,4.0,10.0,100.0)
@test isapprox(_PMDSE.logpdf(dst,50.0), log(_PMDSE.pdf(dst,50.0)),          atol=1e-8)
@test isapprox(_PMDSE.gradlogpdf(dst,50.0),               -0.035,         atol=1e-8)
@test isapprox(_PMDSE.heslogpdf(dst,50.0),                -0.001825,      atol=1e-8)

# Testing logpdf/gradlogpdf/heslogpdf of gaussian mixture models
beta = _PMDSE.ExtendedBeta(1.6339, 20.9022, 0.001, 2.0)
gmm = _DST.MixtureModel([_DST.Normal(0.14585265, sqrt(0.01144241))], [1.0])
g1 = _DST.Normal(gmm.components[1].μ, gmm.components[1].σ)
@test isapprox(_DST.logpdf(g1, beta.min),      _PMDSE.logpdf(gmm, beta.min),     atol = 1e-8)
@test isapprox(_DST.logpdf(g1, beta.max),      _PMDSE.logpdf(gmm, beta.max),     atol = 1e-8)
@test isapprox(_DST.gradlogpdf(g1, beta.min),  _PMDSE.gradlogpdf(gmm, beta.min), atol = 1e-8)    
@test isapprox(_DST.gradlogpdf(g1, beta.max),  _PMDSE.gradlogpdf(gmm, beta.max), atol = 1e-8)
@test isapprox(_PMDSE.heslogpdf(g1, beta.min), _PMDSE.heslogpdf(gmm, beta.min),  atol = 1e-2)
@test isapprox(_PMDSE.heslogpdf(g1, beta.max), _PMDSE.heslogpdf(gmm, beta.max),  atol = 1e-2)

p = _Poly.Polynomial([0,1,1])
@test isapprox(_PMDSE.logpdf(p, 0.0), 0.0, atol=1e-8)
@test isapprox(_PMDSE.logpdf(p, 1.0), 2.0, atol=1e-8)
@test isapprox(_PMDSE.gradlogpdf(p, 1.0), 3.0, atol=1e-8)
@test isapprox(_PMDSE.gradlogpdf(p, 0.0), 1.0, atol=1e-8)
@test isapprox(_PMDSE.heslogpdf(p, 0.0), 2.0, atol=1e-8)
@test isapprox(_PMDSE.heslogpdf(p, 1.0), 2.0, atol=1e-8)

end
