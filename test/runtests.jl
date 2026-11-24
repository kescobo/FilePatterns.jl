using DataFrames: DataFrame
using FilePatterns
using Tables: Tables
using Test

"""
    fixture(names) -> String

A new temporary directory containing empty files at the relative paths `names`.
"""
function fixture(names)
    dir = mktempdir()
    for name in names
        path = joinpath(dir, name)
        mkpath(dirname(path))
        touch(path)
    end
    return dir
end

@testset "FilePatterns" begin
    @testset "Pattern" include("test_pattern.jl")
    @testset "filesearch" include("test_search.jl")
    @testset "select and require" include("test_select_require.jl")
    @testset "README" include("test_readme.jl")
    @testset "quality" include("test_quality.jl")
end
