using FilePatterns
using Documenter

DocMeta.setdocmeta!(FilePatterns, :DocTestSetup, :(using FilePatterns); recursive = true)

makedocs(;
    modules = [FilePatterns],
    authors = "Kevin Bonham <kevin.bonham@tufts.edu>",
    sitename = "FilePatterns.jl",
    format = Documenter.HTML(;
        canonical = "https://kescobo.github.io/FilePatterns.jl",
        edit_link = "main",
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => "manual.md",
        "API" => "api.md",
    ],
    checkdocs = :exports,
)

deploydocs(;
    repo = "github.com/kescobo/FilePatterns.jl",
    devbranch = "main",
)
