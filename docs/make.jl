using Documenter, PowerModelsSE

makedocs(
    modules     = [PowerModelsSE],
    format      = Documenter.HTML(mathengine = Documenter.MathJax()),
    sitename    = "PowerModelsSE.jl",
    authors     = "Tom Van Acker, Marta Vanin",
    pages       = [
              "Home"    => "index.md",
              "Manual"  => [
                            "Getting Started"                => "quickguide.md",
                            "Input Data Format"              => "input_data_format.md",
                            "Mathematical Model "            => "math_model.md",
                            "Measurements and Conversions"   => "measurements.md",
                            "State Estimation Criteria"      => "se_criteria.md",
                            ],
             "Library " => [
                            "Power Flow Formulations"        => "formulations.md",
                            "Problem Specifications"         => "problems.md",
                           ],
                 ]
)

deploydocs(
     repo = "github.com/timmyfaraday/PowerModelsSE.jl.git"
)
