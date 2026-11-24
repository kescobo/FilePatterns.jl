"""
    FilePatterns

Find files whose names match a regex or a template, and return the matches as
a Tables.jl row table of `NamedTuple`s holding each file's name, its directory,
and the values of the named captures.

See [`filesearch`](@ref), [`Pattern`](@ref), [`MissingMatchesError`](@ref) and
[`DuplicateMatchesError`](@ref).
"""
module FilePatterns

using Tables: Tables

export filesearch, Pattern, MissingMatchesError, DuplicateMatchesError

include("pattern.jl")
include("errors.jl")
include("spec.jl")
include("search.jl")

end
