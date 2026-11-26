using Documenter
using FilePatterns

# Doctests run inside a directory of empty example files. `@meta` blocks in the
# manual refer to `DOCTEST_SETUP` and `DOCTEST_TEARDOWN`, which Documenter
# evaluates in `Main`.
const EXAMPLES = mktempdir()
for path in [
        "fastqs/A0001_L001_R1.fastq.gz",
        "fastqs/A0001_L001_R2.fastq.gz",
        "fastqs/A0002_L001_R1.fastq.gz",
        "fastqs/A0002_L001_R2.fastq.gz",
        "fastqs/README.txt",
        "lanes/B0001_L002_R1.fastq.gz",
        "lanes/B0001_R1.fastq.gz",
        "runs/2024/run1.csv",
        "runs/2025/run2.csv",
        "reads/S1_R1.fastq.gz",
        "reads/S1_R2.fastq.gz",
        "reads/S2_R1.fastq.gz",
        "mixed/S1_L001_R1.fastq.gz",
        "mixed/S1_R1.fastq.gz",
        "mixed/S1_R2.fastq.gz",
    ]
    mkpath(dirname(joinpath(EXAMPLES, path)))
    touch(joinpath(EXAMPLES, path))
end
const DOCTEST_SETUP = :(using FilePatterns; cd($EXAMPLES))
const DOCTEST_TEARDOWN = :(cd($(pwd())))

DocMeta.setdocmeta!(FilePatterns, :DocTestSetup, DOCTEST_SETUP; recursive = true)
DocMeta.setdocmeta!(FilePatterns, :DocTestTeardown, DOCTEST_TEARDOWN; recursive = true)

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
