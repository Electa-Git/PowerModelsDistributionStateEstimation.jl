using Documenter
using PowerModelsDSSE

makedocs(
    modules     = [PowerModelsDSSE],
    format      = Documenter.HTML(mathengine = Documenter.MathJax()),
    sitename    = "PowerModelsDSSE.jl",
    authors     = "Tom Van Acker, Marta Vanin",
    pages       = [ "Home"              => "index.md",
                    "Manual"            =>
                        ["Getting Started" =>  "quickguide.md"  ,
                        "Input Data Format"       => "input_data_format.md",
                         "Mathematical Model"       => "math_model.md",
                         "Measurement Conversion"   => "measurements.md",
                         "State Estimation Criteria" => "se_criteria.md"]
                  ]
)

deploydocs(
     repo = "github.com/timmyfaraday/PowerModelsDSSE.jl.git"
)
