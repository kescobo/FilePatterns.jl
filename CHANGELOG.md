# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

### Added

- `filesearch` returns the files in a directory whose names match a `Regex` or
  `Pattern`, as a sorted vector of `NamedTuple`s with `filename`, `directory`
  and one `String` field per named capture.
- `Pattern` templates with `<name>` captures and per-capture regexes.
- `strict` and `recursive` options.
- `distinct` option, on by default, throwing `DuplicateMatchesError` when two or
  more files share the values of every named capture.
- `select` and `require` options taking a Cartesian-product spec or a Tables.jl
  table, with `MissingMatchesError` for unmet requirements.
- Documenter.jl documentation with a manual and doctested examples.
