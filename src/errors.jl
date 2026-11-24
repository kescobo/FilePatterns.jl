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

```julia
julia> try
           filesearch(r"(?<sample>\\w+)_R(?<R>\\d)", "reads"; require = (R = 1:2,))
       catch err
           err.missing
       end
2-element Vector{@NamedTuple{sample::String, R::String}}:
 (sample = "sample1", R = "2")
 (sample = "sample5", R = "1")
```
"""
struct MissingMatchesError{T <: NamedTuple, P <: Union{Regex, Pattern}} <: Exception
    missing::Vector{T}
    pattern::P
    directory::String
end

const SHOWN_MISSING = 20

function Base.showerror(io::IO, err::MissingMatchesError)
    n = length(err.missing)
    print(io, "MissingMatchesError: ", n, n == 1 ? " expected combination has" : " expected combinations have")
    print(io, " no matching file in ", repr(err.directory), " for pattern ", err.pattern, ":")
    for entry in first(err.missing, SHOWN_MISSING)
        print(io, "\n  ", entry)
    end
    n > SHOWN_MISSING && print(io, "\n  … and ", n - SHOWN_MISSING, " more")
    return nothing
end
