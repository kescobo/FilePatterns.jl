# FilePatterns.jl

FilePatterns.jl finds the files in a directory whose names match a regular
expression or a simple template, and returns one `NamedTuple` per file holding
the file name, its directory, and the value of every named capture. The result
is a [Tables.jl](https://github.com/JuliaData/Tables.jl) row table, ready for
`DataFrame`. Options let you keep only some combinations of capture values
(`select`), check that every expected combination is present (`require`), and
catch files that share the same capture values (`distinct`). Building sample
sheets for sequencing data is the motivating use, but nothing in the package is
specific to it.

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

```@meta
DocTestSetup = DOCTEST_SETUP
DocTestTeardown = DOCTEST_TEARDOWN
```

```jldoctest quickstart
julia> using FilePatterns

julia> filesearch(r"(?<sample>[A-Z0-9]+)_L001_R(?<R>1|2)\.fastq\.gz", "fastqs")
4-element Vector{@NamedTuple{filename::String, directory::String, sample::String, R::String}}:
 (filename = "A0001_L001_R1.fastq.gz", directory = "fastqs", sample = "A0001", R = "1")
 (filename = "A0001_L001_R2.fastq.gz", directory = "fastqs", sample = "A0001", R = "2")
 (filename = "A0002_L001_R1.fastq.gz", directory = "fastqs", sample = "A0002", R = "1")
 (filename = "A0002_L001_R2.fastq.gz", directory = "fastqs", sample = "A0002", R = "2")
```

The same search, written as a template:

```jldoctest quickstart
julia> pat = Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")
Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")

julia> filesearch(pat, "fastqs") == filesearch(r"(?<sample>[A-Z0-9]+)_L001_R(?<R>1|2)\.fastq\.gz", "fastqs")
true
```

The [Manual](@ref) covers every option, and the [API](@ref) page has the full
reference.

## Comparison with Glob.jl

[Glob.jl](https://github.com/vtjnash/Glob.jl) matches POSIX shell glob patterns
(including per-directory `Regex` components) and returns the matching paths as
strings. FilePatterns.jl instead extracts the named captures of a regex or
template from each matching file name and returns them as table rows, with
options to filter and validate the combinations found. It does not support glob
syntax.

## Roadmap

- Accepting path types from FilePathsBase.jl and similar packages through a
  package extension.
