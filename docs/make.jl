using Documenter
using PowerModelsDSSE

makedocs(
    modules     = [PowerModelsDSSE],
    format      = Documenter.HTML(mathengine = Documenter.MathJax()),
    sitename    = "PowerModelsDSSE.jl",
    authors     = "Tom Van Acker, Marta Vanin",
    pages       = [ "Home"              => "index.md",
                    "Manual"            =>
                        ["Getting Started"          => "quick_start_guide.md",
                         "Mathematical Model"       => "math_model.md",
                         "Measurement Conversion"   => "measurements.md"]
                  ]
)

deploydocs(
     repo = "github.com/timmyfaraday/PowerModelsDSSE.jl.git"
)
