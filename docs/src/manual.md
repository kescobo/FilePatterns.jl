# Manual

```@meta
DocTestSetup = :(using FilePatterns)
```

The examples on this page search these directories, which are in the
package's `docs/` folder:

```
fastqs/  A0001_L001_R1.fastq.gz  A0001_L001_R2.fastq.gz
         A0002_L001_R1.fastq.gz  A0002_L001_R2.fastq.gz  README.txt
lanes/   B0001_L002_R1.fastq.gz  B0001_R1.fastq.gz
runs/    2024/run1.csv  2025/run2.csv
reads/   S1_R1.fastq.gz  S1_R2.fastq.gz  S2_R1.fastq.gz
mixed/   S1_L001_R1.fastq.gz  S1_R1.fastq.gz  S1_R2.fastq.gz
```

## Regex patterns

Any `Regex` works. Each **named** group becomes a field of the result, in the
order the groups appear. Unnamed groups are ignored. Every capture is a
`String`. A group that did not take part in the match is `""`:

```jldoctest manual
julia> filesearch(r"(?<sample>[A-Z0-9]+)(?:_L(?<lane>\d+))?_R(?<R>\d)\.fastq\.gz", "lanes")
2-element Vector{@NamedTuple{filename::String, directory::String, sample::String, lane::String, R::String}}:
 (filename = "B0001_L002_R1.fastq.gz", directory = "lanes", sample = "B0001", lane = "002", R = "1")
 (filename = "B0001_R1.fastq.gz", directory = "lanes", sample = "B0001", lane = "", R = "1")
```

A regex without named groups returns only `filename` and `directory`. The full
path of a result `m` is `joinpath(m.directory, m.filename)`.

## Template patterns

[`Pattern`](@ref) builds the regex for you from a template. Text inside angle
brackets is a named capture, and everything else is literal, so `.` is a real
dot:

```jldoctest manual
julia> Pattern("<sample>_L001_R<R>.fastq.gz").regex
r"(?<sample>[^/]+?)_L001_R(?<R>[^/]+?)\.fastq\.gz"
```

Captures match any non-empty text by default. A keyword argument named after a
capture replaces that with a `Regex` or a regex source string:

```jldoctest manual
julia> Pattern("<sample>_R<R>.fastq.gz"; sample = "[A-Z]\\d+", R = r"1|2")
Pattern("<sample>_R<R>.fastq.gz"; sample = r"[A-Z]\d+", R = r"1|2")
```

Write `<<` for a literal `<`. Capture names must be valid identifiers (letters,
digits and underscores, not starting with a digit, as PCRE requires) and may
not repeat.

## Strict and non-strict matching

By default the pattern must match the whole file name. Pass `strict = false` to
accept a match anywhere in the name:

```jldoctest manual
julia> filesearch(r"(?<sample>A\d+)_R1", "fastqs")
@NamedTuple{filename::String, directory::String, sample::String}[]

julia> [m.sample for m in filesearch(r"(?<sample>A\d+)_L001_R1", "fastqs"; strict = false)]
2-element Vector{String}:
 "A0001"
 "A0002"
```

## Recursion

`recursive = true` also searches subdirectories. `directory` is built from the
`dir` you pass, so a relative `dir` gives relative directories:

```jldoctest manual
julia> [joinpath(m.directory, m.filename) for m in filesearch(r"(?<run>run\d+)\.csv", "runs"; recursive = true)]
2-element Vector{String}:
 "runs/2024/run1.csv"
 "runs/2025/run2.csv"
```

Symlinked directories are not followed. Symlinks to files are matched, and
broken symlinks are skipped.

## Duplicate matches: `distinct`

Two files can produce the same capture values when the pattern skips some of
the text, matches only part of a name (`strict = false`), or finds the same
name in several directories (`recursive = true`). By default `filesearch`
throws a [`DuplicateMatchesError`](@ref) when that happens, wherever the files
are, because a sample sheet with two files for one sample is usually a mistake:

```jldoctest manual
julia> filesearch(r"(?<sample>S\d+)(?:_L\d+)?_R(?<R>\d)\.fastq\.gz", "mixed")
ERROR: DuplicateMatchesError: 1 combination of capture values matches more than one file in "mixed" for pattern r"(?<sample>S\d+)(?:_L\d+)?_R(?<R>\d)\.fastq\.gz":
  (sample = "S1", R = "1")
    mixed/S1_L001_R1.fastq.gz
    mixed/S1_R1.fastq.gz
Pass `distinct = false` to return every match; telling duplicates apart is then up to the caller.
```

With `distinct = false`, every match is returned and handling the duplicates
is up to you:

```jldoctest manual
julia> [m.filename for m in filesearch(r"(?<sample>S\d+)(?:_L\d+)?_R(?<R>\d)\.fastq\.gz", "mixed"; distinct = false)]
3-element Vector{String}:
 "S1_L001_R1.fastq.gz"
 "S1_R1.fastq.gz"
 "S1_R2.fastq.gz"
```

Only named captures are compared. Patterns without named captures are never
checked.

## Selecting matches: `select`

`select` keeps only the matches whose captures take one of the allowed value
combinations. The simplest form maps capture names to allowed values, and
allows every combination of them (their Cartesian product). Values are compared
as strings, so numbers work too:

```jldoctest manual
julia> pat = Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2");

julia> [m.filename for m in filesearch(pat, "fastqs"; select = (sample = "A0002", R = 1:2))]
2-element Vector{String}:
 "A0002_L001_R1.fastq.gz"
 "A0002_L001_R2.fastq.gz"
```

An `AbstractDict{Symbol}` works the same way. Any other Tables.jl table, such as
a `DataFrame` or a vector of `NamedTuple`s, lists the allowed combinations row by
row:

```jldoctest manual
julia> [m.filename for m in filesearch(pat, "fastqs"; select = [(sample = "A0001", R = 1), (sample = "A0002", R = 2)])]
2-element Vector{String}:
 "A0001_L001_R1.fastq.gz"
 "A0002_L001_R2.fastq.gz"
```

A `NamedTuple` of vectors is always read as a product, even though Tables.jl
also considers it a column table. To pass it as rows, wrap it in
`Tables.rowtable`.

## Validating matches: `require`

`require` takes the same forms as `select`. It never removes results. It throws
a [`MissingMatchesError`](@ref) when an expected combination has no matching
file:

```jldoctest manual
julia> filesearch(pat, "fastqs"; require = (sample = ["A0001", "A0002", "A0003"], R = 1:2))
ERROR: MissingMatchesError: 2 expected combinations have no matching file in "fastqs" for pattern Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2"):
  (sample = "A0003", R = "1")
  (sample = "A0003", R = "2")
```

When `require` names only some captures, the check runs separately for each
combination of the others. `require = (R = 1:2,)` therefore means "every sample
has both reads", not merely "R1 and R2 each appear somewhere":

```jldoctest manual
julia> filesearch(Pattern("<sample>_R<R>.fastq.gz"), "reads"; require = (R = 1:2,))
ERROR: MissingMatchesError: 1 expected combination has no matching file in "reads" for pattern Pattern("<sample>_R<R>.fastq.gz"):
  (sample = "S2", R = "2")
```

An empty search never passes: with no matches, every expected combination is
missing. `select` is applied first, then the `distinct` check, then `require`.

## With DataFrames

```jldoctest manual
julia> using DataFrames

julia> df = DataFrame(filesearch(pat, "fastqs"));

julia> df.sample
4-element Vector{String}:
 "A0001"
 "A0001"
 "A0002"
 "A0002"
```

A `DataFrame` can also serve as a `select` or `require` table, for example a
sample sheet listing the files you expect:

```jldoctest manual
julia> sheet = DataFrame(sample = ["A0001", "A0002", "A0003"]);

julia> filesearch(pat, "fastqs"; require = sheet)
ERROR: MissingMatchesError: 2 expected combinations have no matching file in "fastqs" for pattern Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2"):
  (R = "1", sample = "A0003")
  (R = "2", sample = "A0003")
```

## Gotchas

- **Captures are strings.** Parse them yourself, for example
  `parse(Int, m.R)`. A group that did not take part in the match is `""`, the
  same as a group that matched empty text.
- **Only base names are matched.** Directory names are never part of the match;
  use `recursive = true` and the `directory` field instead.
- **A `NamedTuple` is always a product spec**, even a `NamedTuple` of vectors.
  Wrap it in `Tables.rowtable` to pass rows.
- **Symlinked directories are not followed** during recursion.
- **Flags on capture regexes are unsupported.** `Pattern("<a>"; a = r"x"i)`
  throws rather than silently dropping the `i`.
