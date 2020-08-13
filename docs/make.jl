using Documenter

makedocs(sitename="PowerModelsDSSE",
        modules="PowerModelsDSSE",
        authors="Tom Van Acker, Marta Vanin")

deploydocs(
    repo = "github.com/Electa-Git/PowerModelsDSSE.jl.git",
)
#
# makedocs(
#     sitename    = "PowerModelsDSSE",
#     pages       = [
#         "Home"          => "index.md",
#         "Formulation"   => "formulation.md"
#     ])
