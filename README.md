# FilePatterns.jl

[![CI](https://github.com/kescobo/FilePatterns.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/kescobo/FilePatterns.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/kescobo/FilePatterns.jl/graph/badge.svg)](https://codecov.io/gh/kescobo/FilePatterns.jl)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
[![Aqua QA](https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

FilePatterns.jl finds the files in a directory whose names match a regular
expression or a simple template, and returns one `NamedTuple` per file holding
the file name, its directory, and the value of every named capture. The result
is a [Tables.jl](https://github.com/JuliaData/Tables.jl) row table, ready for
`DataFrame`. Options let you keep only some combinations of capture values
(`select`) and check that every expected combination is present (`require`).
Building sample sheets for sequencing data is the motivating use, but nothing in
the package is specific to it.

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

The same search, written as a template:

```julia
julia> pat = Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")
Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")

julia> filesearch(pat, "fastqs") == filesearch(r"(?<sample>[A-Z0-9]+)_L001_R(?<R>1|2)\.fastq\.gz", "fastqs")
true
```

## Usage

### Regex patterns

Any `Regex` works. Each **named** group becomes a field of the result, in the
order the groups appear. Unnamed groups are ignored. Every capture is a
`String`. A group that did not take part in the match is `""`:

```julia
julia> filesearch(r"(?<sample>[A-Z0-9]+)(?:_L(?<lane>\d+))?_R(?<R>\d)\.fastq\.gz", "lanes")
2-element Vector{@NamedTuple{filename::String, directory::String, sample::String, lane::String, R::String}}:
 (filename = "B0001_L002_R1.fastq.gz", directory = "lanes", sample = "B0001", lane = "002", R = "1")
 (filename = "B0001_R1.fastq.gz", directory = "lanes", sample = "B0001", lane = "", R = "1")
```

A regex without named groups returns only `filename` and `directory`. The full
path of a result `m` is `joinpath(m.directory, m.filename)`.

### Template patterns

`Pattern` builds the regex for you from a template. Text inside angle brackets
is a named capture, and everything else is literal, so `.` is a real dot:

```julia
julia> Pattern("<sample>_L001_R<R>.fastq.gz").regex
r"(?<sample>[^/]+?)_L001_R(?<R>[^/]+?)\.fastq\.gz"
```

Captures match any non-empty text by default. A keyword argument named after a
capture replaces that with a `Regex` or a regex source string:

```julia
julia> Pattern("<sample>_R<R>.fastq.gz"; sample = "[A-Z]\\d+", R = r"1|2")
Pattern("<sample>_R<R>.fastq.gz"; sample = r"[A-Z]\d+", R = r"1|2")
```

Write `<<` for a literal `<`. Capture names must be valid identifiers and may
not repeat.

### Strict and non-strict matching

By default the pattern must match the whole file name. Pass `strict = false` to
accept a match anywhere in the name:

```julia
julia> filesearch(r"(?<sample>A\d+)_R1", "fastqs")
0-element Vector{@NamedTuple{filename::String, directory::String, sample::String}}

julia> [m.sample for m in filesearch(r"(?<sample>A\d+)_L001_R1", "fastqs"; strict = false)]
2-element Vector{String}:
 "A0001"
 "A0002"
```

### Recursion

`recursive = true` also searches subdirectories. `directory` is built from the
`dir` you pass, so a relative `dir` gives relative directories:

```julia
julia> [joinpath(m.directory, m.filename) for m in filesearch(r"(?<run>run\d+)\.csv", "runs"; recursive = true)]
2-element Vector{String}:
 "runs/2024/run1.csv"
 "runs/2025/run2.csv"
```

### Duplicate matches: `distinct`

Two files can produce the same capture values when the pattern skips some of
the text, matches only part of a name (`strict = false`), or finds the same
name in several directories (`recursive = true`). By default `filesearch`
throws a `DuplicateMatchesError` when that happens, wherever the files are,
because a sample sheet with two files for one sample is usually a mistake.
Given `mixed` containing `S1_L001_R1.fastq.gz`, `S1_R1.fastq.gz` and
`S1_R2.fastq.gz`:

```julia
julia> filesearch(r"(?<sample>S\d+)(?:_L\d+)?_R(?<R>\d)\.fastq\.gz", "mixed")
ERROR: DuplicateMatchesError: 1 combination of capture values matches more than one file in "mixed" for pattern r"(?<sample>S\d+)(?:_L\d+)?_R(?<R>\d)\.fastq\.gz":
  (sample = "S1", R = "1")
    mixed/S1_L001_R1.fastq.gz
    mixed/S1_R1.fastq.gz
Pass `distinct = false` to return every match; telling duplicates apart is then up to the caller.
```

With `distinct = false`, every match is returned and handling the duplicates
is up to you. Only named captures are compared. Patterns without named
captures are never checked.

### Selecting matches: `select`

`select` keeps only the matches whose captures take one of the allowed value
combinations. The simplest form maps capture names to allowed values, and
allows every combination of them (their Cartesian product). Values are compared
as strings, so numbers work too:

```julia
julia> [m.filename for m in filesearch(pat, "fastqs"; select = (sample = "A0002", R = 1:2))]
2-element Vector{String}:
 "A0002_L001_R1.fastq.gz"
 "A0002_L001_R2.fastq.gz"
```

An `AbstractDict{Symbol}` works the same way. Any other Tables.jl table, such as
a `DataFrame` or a vector of `NamedTuple`s, lists the allowed combinations row by
row:

```julia
julia> [m.filename for m in filesearch(pat, "fastqs"; select = [(sample = "A0001", R = 1), (sample = "A0002", R = 2)])]
2-element Vector{String}:
 "A0001_L001_R1.fastq.gz"
 "A0002_L001_R2.fastq.gz"
```

### Validating matches: `require`

`require` takes the same forms as `select`. It never removes results. It throws
a `MissingMatchesError` when an expected combination has no matching file:

```julia
julia> filesearch(pat, "fastqs"; require = (sample = ["A0001", "A0002", "A0003"], R = 1:2))
ERROR: MissingMatchesError: 2 expected combinations have no matching file in "fastqs" for pattern Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2"):
  (sample = "A0003", R = "1")
  (sample = "A0003", R = "2")
```

When `require` names only some captures, the check runs separately for each
combination of the others. `require = (R = 1:2,)` therefore means "every sample
has both reads", not merely "R1 and R2 each appear somewhere". Given `reads`
containing `S1_R1.fastq.gz`, `S1_R2.fastq.gz` and `S2_R1.fastq.gz`:

```julia
julia> filesearch(Pattern("<sample>_R<R>.fastq.gz"), "reads"; require = (R = 1:2,))
ERROR: MissingMatchesError: 1 expected combination has no matching file in "reads" for pattern Pattern("<sample>_R<R>.fastq.gz"):
  (sample = "S2", R = "2")
```

An empty search never passes: with no matches, every expected combination is
missing. `select` is applied first, then the `distinct` check, then `require`.

### With DataFrames

```julia
julia> using DataFrames

julia> DataFrame(filesearch(pat, "fastqs"))
4×4 DataFrame
 Row │ filename                directory  sample  R
     │ String                  String     String  String
─────┼───────────────────────────────────────────────────
   1 │ A0001_L001_R1.fastq.gz  fastqs     A0001   1
   2 │ A0001_L001_R2.fastq.gz  fastqs     A0001   2
   3 │ A0002_L001_R1.fastq.gz  fastqs     A0002   1
   4 │ A0002_L001_R2.fastq.gz  fastqs     A0002   2
```

A `DataFrame` can also serve as a `select` or `require` table, for example a
sample sheet listing the files you expect.

## API

### `filesearch`

```julia
filesearch(pattern::Union{Regex, Pattern}, dir::AbstractString = ".";
           recursive = false, strict = true, distinct = true,
           select = nothing, require = nothing)
```

Returns a `Vector` of `NamedTuple`s sorted by `(directory, filename)`, with
fields `filename`, `directory`, then one `String` per named capture. The element
type is concrete even when nothing matches.

| Argument | Meaning |
| --- | --- |
| `pattern` | `Regex` with named groups, or a `Pattern`. Matched against base names only. |
| `dir` | Directory to search. |
| `recursive` | Also search subdirectories (symlinked directories are not followed). |
| `strict` | Require a match of the whole file name. |
| `distinct` | Throw `DuplicateMatchesError` if files share all named capture values. |
| `select` | Keep only the given capture value combinations. |
| `require` | Throw `MissingMatchesError` unless every given combination is matched. |

Throws `ArgumentError` if `dir` is not an existing directory, if the pattern has
a capture named `filename` or `directory`, or if a `select` or `require` key is
not a capture name.

### `Pattern`

```julia
Pattern(template::AbstractString; captures...)
```

A template of literal text and `<name>` captures. Keyword arguments give a
capture's regex as a `Regex` or a source string. Throws `ArgumentError` for an
empty template, an unclosed `<`, an invalid, duplicate or reserved capture
name, a keyword that names no capture, or a capture regex with named groups or
flags. The compiled, unanchored regex is in the `regex` field.

```julia
julia> Pattern("<<<tag>>.txt").regex
r"<(?<tag>[^/]+?)>\.txt"
```

### `MissingMatchesError`

Thrown by `filesearch` when `require` fails. Its `missing` field is a `Vector`
of `NamedTuple`s, one per missing combination, holding the values of the
grouping captures followed by the expected values. The `pattern` and
`directory` fields record what was searched.

```julia
julia> err = try
           filesearch(Pattern("<sample>_R<R>.fastq.gz"), "reads"; require = (R = 1:2,))
       catch e
           e
       end;

julia> err.missing
1-element Vector{@NamedTuple{sample::String, R::String}}:
 (sample = "S2", R = "2")
```

### `DuplicateMatchesError`

Thrown by `filesearch` when `distinct = true` (the default) and two or more
files have the same values for every named capture. Its `duplicates` field maps
each shared combination of capture values to the paths of its files, sorted by
the capture values. The `pattern` and `directory` fields record what was
searched.

```julia
julia> err = try
           filesearch(r"(?<sample>S\d+)(?:_L\d+)?_R(?<R>\d)\.fastq\.gz", "mixed")
       catch e
           e
       end;

julia> err.duplicates
1-element Vector{Pair{@NamedTuple{sample::String, R::String}, Vector{String}}}:
 (sample = "S1", R = "1") => ["mixed/S1_L001_R1.fastq.gz", "mixed/S1_R1.fastq.gz"]
```

## Gotchas

- **Captures are strings.** Parse them yourself, for example
  `parse(Int, m.R)`. A group that did not take part in the match is `""`, the
  same as a group that matched empty text.
- **Only base names are matched.** Directory names are never part of the match;
  use `recursive = true` and the `directory` field instead.
- **A `NamedTuple` is always a product spec**, even a `NamedTuple` of vectors
  (which Tables.jl also considers a column table). To pass it as rows, wrap it in
  `Tables.rowtable`.
- **Symlinked directories are not followed** during recursion. Symlinks to
  files are matched, and broken symlinks are skipped.
- **Flags on capture regexes are unsupported.** `Pattern("<a>"; a = r"x"i)`
  throws rather than silently dropping the `i`.

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

## Development

Run the tests, including the Aqua, JET and ExplicitImports checks, with

```julia
using Pkg
Pkg.test("FilePatterns")
```

Code is formatted with [Runic](https://github.com/fredrikekre/Runic.jl).
Install it as an app with `Pkg.Apps.add("Runic")` (Julia 1.12+), then format
and check with

```sh
runic --inplace .
runic --check --diff .
```

Every example in this README is also run in `test/test_readme.jl`.
