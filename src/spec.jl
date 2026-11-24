"""
    Spec

A `select` or `require` option normalized against a pattern's capture names:
the constrained capture names, in capture order, and the allowed or expected
value combinations as rows of strings in the same order.
"""
struct Spec
    fields::Vector{Symbol}
    rows::Vector{Vector{String}}
end

_spec(::Nothing, captures) = nothing
_spec(spec::NamedTuple, captures) = _product(pairs(spec), captures)
_spec(spec::AbstractDict{Symbol}, captures) = _product(pairs(spec), captures)

function _spec(table, captures)
    Tables.istable(table) || throw(
        ArgumentError(
            "`select` and `require` take a NamedTuple, an AbstractDict{Symbol}, or a Tables.jl table; got $(typeof(table))",
        ),
    )
    fields = _order(Tables.columnnames(Tables.columns(table)), captures)
    rows = [[string(Tables.getcolumn(row, field)) for field in fields] for row in Tables.rows(table)]
    return Spec(fields, unique!(rows))
end

function _product(spec, captures)
    choices = Dict(field => _choices(choice) for (field, choice) in spec)
    fields = _order(keys(choices), captures)
    rows = [collect(row) for row in Iterators.product((choices[field] for field in fields)...)]
    return Spec(fields, unique(vec(rows)))
end

_choices(choice::AbstractString) = [String(choice)]
_choices(choices) = [string(choice) for choice in choices]

function _order(fields, captures)
    fields = Symbol.(collect(fields))
    unknown = setdiff(fields, captures)
    isempty(unknown) || throw(
        ArgumentError(
            "unknown capture name(s) $(join(repr.(unknown), ", ")); valid names are $(isempty(captures) ? "(none)" : join(repr.(captures), ", "))",
        ),
    )
    return filter(in(fields), collect(captures))
end

_project(m::NamedTuple, fields) = [getfield(m, field) for field in fields]

_select!(matches, ::Nothing) = matches

function _select!(matches, spec::Spec)
    allowed = Set(spec.rows)
    return filter!(m -> _project(m, spec.fields) in allowed, matches)
end

_require(matches, ::Nothing, captures, pattern, dir) = matches

function _require(matches, spec::Spec, captures, pattern, dir)
    groupfields = filter(!in(spec.fields), collect(captures))
    found = Set((_project(m, groupfields), _project(m, spec.fields)) for m in matches)
    groups = unique(_project(m, groupfields) for m in matches)
    if isempty(groups)
        groupfields = Symbol[]
        push!(groups, String[])
    end
    absent = [(group, row) for group in groups for row in spec.rows if (group, row) ∉ found]
    isempty(absent) && return matches
    fields = (groupfields..., spec.fields...)
    entries = [NamedTuple{fields}((group..., row...)) for (group, row) in absent]
    throw(MissingMatchesError(entries, pattern, String(dir)))
end
