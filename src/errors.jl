"""
    MissingMatchesError <: Exception

Thrown by [`filesearch`](@ref) when the `require` option expects combinations
of capture values that no matched file provides.

# Fields

- `missing::Vector{<:NamedTuple}`: one entry per missing combination. Each entry
  holds the values of the captures that define its group (the captures not named
  in `require`), followed by the expected values of the captures named in
  `require`. When nothing matched at all, entries hold only the latter.
- `pattern::Union{Regex, Pattern}`: the pattern that was searched for.
- `directory::String`: the directory that was searched.

# Examples

With a directory `reads` holding `S1_R1.fastq.gz`, `S1_R2.fastq.gz` and
`S2_R1.fastq.gz`:

```jldoctest
julia> err = try
           filesearch(r"(?<sample>\\w+)_R(?<R>\\d)\\.fastq\\.gz", "reads"; require = (R = 1:2,))
       catch e
           e
       end;

julia> err.missing
1-element Vector{@NamedTuple{sample::String, R::String}}:
 (sample = "S2", R = "2")
```
"""
struct MissingMatchesError{T <: NamedTuple, P <: Union{Regex, Pattern}} <: Exception
    missing::Vector{T}
    pattern::P
    directory::String
end

const SHOWN = 20

function Base.showerror(io::IO, err::MissingMatchesError)
    n = length(err.missing)
    print(io, "MissingMatchesError: ", n, n == 1 ? " expected combination has" : " expected combinations have")
    print(io, " no matching file in ", repr(err.directory), " for pattern ", err.pattern, ":")
    for entry in first(err.missing, SHOWN)
        print(io, "\n  ", entry)
    end
    n > SHOWN && print(io, "\n  … and ", n - SHOWN, " more")
    return nothing
end

"""
    DuplicateMatchesError <: Exception

Thrown by [`filesearch`](@ref) when two or more matched files have the same
values for every named capture, for example `sample1_R1.fastq.gz` and
`mod_sample1_R1.fastq.gz` with `strict = false`, or files with the same name in
different directories with `recursive = true`. Pass `distinct = false` to
`filesearch` to return every match instead.

# Fields

- `duplicates::Vector{<:Pair{<:NamedTuple, Vector{String}}}`: one entry per
  shared combination of capture values, mapping it to the paths of the files
  that have it, sorted by the capture values.
- `pattern::Union{Regex, Pattern}`: the pattern that was searched for.
- `directory::String`: the directory that was searched.

# Examples

With a directory `mixed` holding `S1_L001_R1.fastq.gz`, `S1_R1.fastq.gz` and
`S1_R2.fastq.gz`:

```jldoctest
julia> err = try
           filesearch(r"(?<sample>S\\d+)(?:_L\\d+)?_R(?<R>\\d)\\.fastq\\.gz", "mixed")
       catch e
           e
       end;

julia> err.duplicates
1-element Vector{Pair{@NamedTuple{sample::String, R::String}, Vector{String}}}:
 (sample = "S1", R = "1") => ["mixed/S1_L001_R1.fastq.gz", "mixed/S1_R1.fastq.gz"]
```
"""
struct DuplicateMatchesError{T <: NamedTuple, P <: Union{Regex, Pattern}} <: Exception
    duplicates::Vector{Pair{T, Vector{String}}}
    pattern::P
    directory::String
end

function Base.showerror(io::IO, err::DuplicateMatchesError)
    n = length(err.duplicates)
    print(io, "DuplicateMatchesError: ", n, n == 1 ? " combination of capture values matches" : " combinations of capture values match")
    print(io, " more than one file in ", repr(err.directory), " for pattern ", err.pattern, ":")
    for (captures, paths) in first(err.duplicates, SHOWN)
        print(io, "\n  ", captures)
        for path in paths
            print(io, "\n    ", path)
        end
    end
    n > SHOWN && print(io, "\n  … and ", n - SHOWN, " more")
    print(io, "\nPass `distinct = false` to return every match; telling duplicates apart is then up to the caller.")
    return nothing
end
