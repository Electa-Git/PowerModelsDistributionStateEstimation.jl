using Documenter, PowerModelsDistributionStateEstimation

makedocs(
    modules     = [PowerModelsDistributionStateEstimation],
    format      = Documenter.HTML(mathengine = Documenter.MathJax()),
    sitename    = "PowerModelsDistributionStateEstimation.jl",
    authors     = "Marta Vanin, and Tom Van Acker",
    pages       = [
              "Home"    => "index.md",
              "Manual"  => [
                            "Getting Started"                         => "quickguide.md",
                            "Input Data Format"                       => "input_data_format.md",
                            "Measurements and Conversions"            => "measurements.md",
                            "State Estimation Criteria"               => "se_criteria.md",
                            "Bad Data Detection and Identification"   => "bad_data.md",
                            ],
             "Library " => [
                            "Power Flow Formulations"        => "formulations.md",
                            "Problem Specifications"         => "problems.md",
                           ],
                 ]
)

deploydocs(
     repo = "github.com/Electa-Git/PowerModelsDistributionStateEstimation.jl.git"
)
