_regex(regex::Regex) = regex
_regex(pattern::Pattern) = pattern.regex

_anchor(regex::Regex) = Regex(string("^(?:", regex.pattern, ")\\z"), regex.compile_options, regex.match_options)

"""
    _walk(dir; recursive) -> iterator of (directory, filename)

Files in `dir` (and its subdirectories when `recursive`), including symlinks to
files and excluding broken symlinks. Symlinked directories are not followed.
"""
function _walk(dir::AbstractString; recursive::Bool)
    entries = if recursive
        ((root, name) for (root, _, names) in walkdir(dir) for name in names)
    else
        ((dir, name) for name in readdir(dir))
    end
    return Iterators.filter(((directory, name),) -> isfile(joinpath(directory, name)), entries)
end

function _match(regex::Regex, entries, ::Val{names}) where {names}
    T = NamedTuple{(:filename, :directory, names...), NTuple{length(names) + 2, String}}
    matches = T[]
    for (directory, filename) in entries
        m = match(regex, filename)
        m === nothing && continue
        push!(matches, T((String(filename), String(directory), map(name -> String(something(m[name], "")), names)...)))
    end
    return sort!(matches; by = m -> (m.directory, m.filename))
end

_reject_duplicates(matches, ::Tuple{}, pattern, dir) = nothing

function _reject_duplicates(matches, captures, pattern, dir)
    paths = Dict{NamedTuple{captures, NTuple{length(captures), String}}, Vector{String}}()
    for m in matches
        push!(get!(Vector{String}, paths, NamedTuple{captures}(m)), joinpath(m.directory, m.filename))
    end
    duplicates = [entry for entry in paths if length(last(entry)) > 1]
    isempty(duplicates) && return nothing
    throw(DuplicateMatchesError(sort!(duplicates), pattern, String(dir)))
end

"""
    filesearch(pattern::Union{Regex, Pattern}, dir::AbstractString = ".";
               recursive = false, strict = true, distinct = true,
               select = nothing, require = nothing)

Find the files in `dir` whose names match `pattern` and return one `NamedTuple`
per file, sorted by `(directory, filename)`.

Each result has the fields `filename` (the file's base name), `directory` (the
directory containing it), and then one `String` field per named capture group of
`pattern`, in the order the groups appear. A group that did not take part in the
match (such as an optional `(?<lane>_L\\d+)?`) is `""`, which cannot be told
apart from a group that matched the empty string. Unnamed groups are ignored.
The full path of a result `m` is `joinpath(m.directory, m.filename)`.

The result is a Tables.jl row table, so `DataFrame(filesearch(...))` works.

# Arguments

- `pattern`: a `Regex` with named capture groups, or a [`Pattern`](@ref). It is
  matched against each file's base name only.
- `dir`: the directory to search. `directory` values are built from it exactly
  as given, so a relative `dir` yields relative directories.
- `recursive`: also search subdirectories. Symlinked directories are not
  followed. Symlinks to files are matched; broken symlinks are skipped.
- `strict`: when `true`, `pattern` must match the whole file name. When `false`,
  a match anywhere in the name is enough.
- `distinct`: when `true`, throw [`DuplicateMatchesError`](@ref) if two or more
  files have the same values for every named capture, wherever they are. When
  `false`, return every match and leave telling them apart to the caller.
  Patterns without named captures are never checked.
- `select`: keep only matches whose captures take one of the given value
  combinations.
- `require`: throw [`MissingMatchesError`](@ref) unless every expected value
  combination is matched. It never removes results.

# `select` and `require` specs

Both accept either form:

- A `NamedTuple` or `AbstractDict{Symbol}` mapping capture names to collections
  of values, meaning every combination of those values (their Cartesian
  product). A string or other scalar counts as a single value. A `NamedTuple` of
  vectors is always read this way; wrap it in `Tables.rowtable` to pass rows.
- Any other Tables.jl table, such as a `DataFrame` or a vector of `NamedTuple`s,
  whose rows are the combinations and whose column names are capture names.

Values are compared as strings after conversion with `string`, so `R = 1:2`
matches captures `"1"` and `"2"`. Captures not named in a spec are
unconstrained.

`require` checks each group of matches separately, where a group is one
combination of the captures *not* named in the spec. With captures `sample` and
`R`, `require = (R = 1:2,)` fails if some sample has an `R = "1"` file but no
`R = "2"` file. When nothing matches, every expected combination is missing.

`select` is applied first, then the `distinct` check, then `require`, so files
removed by `select` cannot count as duplicates.

# Errors

- `ArgumentError` if `dir` is not an existing directory, if `pattern` has a
  capture named `filename` or `directory`, or if a `select` or `require` key is
  not a capture name.
- [`DuplicateMatchesError`](@ref) if `distinct` is `true` and files share all
  capture values.
- [`MissingMatchesError`](@ref) if `require` is not satisfied.

# Examples

```julia
julia> filesearch(r"(?<sample>[A-Z0-9]+)_L001_R(?<R>1|2)\\.fastq\\.gz", "fastqs")
2-element Vector{@NamedTuple{filename::String, directory::String, sample::String, R::String}}:
 (filename = "A0001_L001_R1.fastq.gz", directory = "fastqs", sample = "A0001", R = "1")
 (filename = "A0001_L001_R2.fastq.gz", directory = "fastqs", sample = "A0001", R = "2")

julia> pat = Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2");

julia> filesearch(pat, "fastqs"; recursive = true, require = (sample = ["A0001", "A0002"], R = [1, 2]))
```
"""
function filesearch(
        pattern::Union{Regex, Pattern}, dir::AbstractString = ".";
        recursive::Bool = false, strict::Bool = true, distinct::Bool = true,
        select = nothing, require = nothing,
    )
    isdir(dir) || throw(ArgumentError("`dir` must be an existing directory, got $(repr(dir))"))
    regex = _regex(pattern)
    names = _reject_reserved(capture_names(regex))
    selection = _spec(select, names)
    requirement = _spec(require, names)
    matches = _match(strict ? _anchor(regex) : regex, _walk(dir; recursive), Val(names))
    _select!(matches, selection)
    distinct && _reject_duplicates(matches, names, pattern, dir)
    return _require(matches, requirement, names, pattern, dir)
end
