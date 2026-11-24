const RESERVED = (:filename, :directory)
const NAME = r"^[A-Za-z_][A-Za-z0-9_]*\z"
const DEFAULT_CAPTURE = "[^/]+?"
const DEFAULT_COMPILE_OPTIONS = Regex("").compile_options

"""
    capture_names(regex::Regex) -> Tuple{Vararg{Symbol}}

Names of the named capture groups of `regex`, in group-number order.
Unnamed groups are omitted.
"""
function capture_names(regex::Regex)
    names = Base.PCRE.capture_names(regex.regex)
    return Tuple(Symbol(names[i]) for i in sort!(collect(keys(names))))
end

function _reject_reserved(captures)
    reserved = filter(in(RESERVED), captures)
    isempty(reserved) || throw(
        ArgumentError(
            "capture name(s) $(join(repr.(reserved), ", ")) are reserved for result fields; rename the group(s)",
        ),
    )
    return captures
end

"""
    Pattern(template::AbstractString; captures...)

A file name pattern written as literal text with named captures in angle
brackets, such as `"<sample>_L001_R<R>.fastq.gz"`. Pass a `Pattern` to
[`filesearch`](@ref) in place of a `Regex`.

# Template syntax

- `<name>` is a named capture. `name` must match `[A-Za-z_][A-Za-z0-9_]*`, must
  not repeat, and must not be `filename` or `directory`.
- `<<` is a literal `<`. A `>` outside a capture is literal.
- All other text is literal, including regex metacharacters: `.` matches only a
  dot.

# Capture regexes

By default a capture matches `$(DEFAULT_CAPTURE)` (one or more characters,
lazily). A keyword argument named after a capture replaces that default with a
`Regex` or a regex source string. A capture regex may contain unnamed groups but
not named ones, and may not carry flags such as `r"..."i`.

# Errors

Throws `ArgumentError` for an empty template, an unclosed `<`, an invalid,
duplicate or reserved capture name, a keyword that names no capture, or a
capture regex with named groups or flags. Messages for template errors give the
character position of the problem.

# Examples

```julia
julia> pat = Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")
Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")

julia> filesearch(pat, "fastqs")
```
"""
struct Pattern
    template::String
    captures::Vector{Pair{Symbol, Regex}}
    regex::Regex
end

function Pattern(template::AbstractString; captures...)
    overrides = [name => _capture(regex, name) for (name, regex) in captures]
    names, source = _compile(template, Dict(name => regex.pattern for (name, regex) in overrides))
    unknown = setdiff(first.(overrides), names)
    isempty(unknown) || throw(
        ArgumentError(
            "keyword(s) $(join(unknown, ", ")) name no capture in template $(repr(template)); captures are $(join(names, ", "))",
        ),
    )
    return Pattern(template, overrides, Regex(source))
end

_capture(source::AbstractString, name) = _capture(Regex(source), name)

function _capture(regex::Regex, name)
    regex.compile_options == DEFAULT_COMPILE_OPTIONS || throw(
        ArgumentError("capture regex for `$name` has flags, which are not supported: $(repr(regex))"),
    )
    isempty(capture_names(regex)) || throw(
        ArgumentError("capture regex for `$name` must not contain named groups: $(repr(regex))"),
    )
    return regex
end

_escape(literal::AbstractString) = replace(literal, r"([\\^$.|?*+()\[\]{}])" => s"\\\1")

_position(template, i) = length(template, firstindex(template), i)

function _compile(template::AbstractString, overrides)
    isempty(template) && throw(ArgumentError("template must not be empty"))
    io = IOBuffer()
    names = Symbol[]
    i = firstindex(template)
    while (lt = findnext('<', template, i)) !== nothing
        print(io, _escape(SubString(template, i, prevind(template, lt))))
        next = nextind(template, lt)
        if next <= lastindex(template) && template[next] == '<'
            print(io, '<')
            i = nextind(template, next)
            continue
        end
        gt = findnext('>', template, next)
        gt === nothing && throw(
            ArgumentError("unclosed `<` at position $(_position(template, lt)) in template $(repr(template))"),
        )
        name = SubString(template, next, prevind(template, gt))
        at = "at position $(_position(template, lt)) in template $(repr(template))"
        occursin(NAME, name) || throw(
            ArgumentError("invalid capture name $(repr(name)) $at; names must match [A-Za-z_][A-Za-z0-9_]*"),
        )
        symbol = Symbol(name)
        symbol in names && throw(ArgumentError("duplicate capture name `$name` $at"))
        symbol in RESERVED && throw(ArgumentError("capture name `$name` $at is reserved for result fields"))
        push!(names, symbol)
        print(io, "(?<", name, ">", get(overrides, symbol, DEFAULT_CAPTURE), ")")
        i = nextind(template, gt)
    end
    print(io, _escape(SubString(template, i)))
    return names, String(take!(io))
end

function Base.show(io::IO, pattern::Pattern)
    print(io, "Pattern(", repr(pattern.template))
    separator = "; "
    for (name, regex) in pattern.captures
        print(io, separator, name, " = ", repr(regex))
        separator = ", "
    end
    return print(io, ")")
end
