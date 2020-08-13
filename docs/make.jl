using Documenter
using PowerModelsDSSE

makedocs(
    modules     = [PowerModelsDSSE],
    format      = Documenter.HTML(mathengine = Documenter.MathJax()),
    sitename    = "PowerModelsDSSE.jl",
    authors     = "Tom Van Acker, Marta Vanin",
    pages       = [ "Home"              => "index.md"]
)

deploydocs(
     repo = "github.com/timmyfaraday/PowerModelsDSSE.jl.git"
)
