# FilePatterns.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://kescobo.github.io/FilePatterns.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://kescobo.github.io/FilePatterns.jl/dev/)
[![CI](https://github.com/kescobo/FilePatterns.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/kescobo/FilePatterns.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/kescobo/FilePatterns.jl/graph/badge.svg)](https://codecov.io/gh/kescobo/FilePatterns.jl)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
[![Aqua QA](https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

FilePatterns.jl finds the files in a directory whose names match a regular
expression or a simple template, and returns one `NamedTuple` per file holding
the file name, its directory, and the value of every named capture. The result
is a [Tables.jl](https://github.com/JuliaData/Tables.jl) row table, ready for
`DataFrame`. Options let you keep only some combinations of capture values
(`select`), check that every expected combination is present (`require`), and
catch files that share the same capture values (`distinct`). Building sample
sheets for sequencing data is the motivating use, but nothing in the package is
specific to it.

See the [documentation](https://kescobo.github.io/FilePatterns.jl/stable/) for
the manual and API reference.

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/kescobo/FilePatterns.jl")
```

## Quick start

Given a directory `fastqs` containing

```
A0001_L001_R1.fastq.gz
A0001_L001_R2.fastq.gz
A0002_L001_R1.fastq.gz
A0002_L001_R2.fastq.gz
README.txt
```

```julia
julia> using FilePatterns

julia> filesearch(r"(?<sample>[A-Z0-9]+)_L001_R(?<R>1|2)\.fastq\.gz", "fastqs")
4-element Vector{@NamedTuple{filename::String, directory::String, sample::String, R::String}}:
 (filename = "A0001_L001_R1.fastq.gz", directory = "fastqs", sample = "A0001", R = "1")
 (filename = "A0001_L001_R2.fastq.gz", directory = "fastqs", sample = "A0001", R = "2")
 (filename = "A0002_L001_R1.fastq.gz", directory = "fastqs", sample = "A0002", R = "1")
 (filename = "A0002_L001_R2.fastq.gz", directory = "fastqs", sample = "A0002", R = "2")
```

The same search, written as a template, and checked against a sample sheet:

```julia
julia> pat = Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")
Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")

julia> filesearch(pat, "fastqs"; require = (sample = ["A0001", "A0002", "A0003"], R = 1:2))
ERROR: MissingMatchesError: 2 expected combinations have no matching file in "fastqs" for pattern Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2"):
  (sample = "A0003", R = "1")
  (sample = "A0003", R = "2")
```

## Development

Run the tests, including the Aqua, JET and ExplicitImports checks, with

```julia
using Pkg
Pkg.test("FilePatterns")
```

Build the documentation, which also runs its doctests, with

```sh
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl
```

Code is formatted with [Runic](https://github.com/fredrikekre/Runic.jl).
Install it as an app with `Pkg.Apps.add("Runic")` (Julia 1.12+), then format
and check with

```sh
runic --inplace .
runic --check --diff .
```

The README examples are run in `test/test_readme.jl`.
