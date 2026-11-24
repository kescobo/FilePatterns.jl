const FASTQ = r"(?<sample>[A-Z0-9]+)_L001_R(?<R>1|2)\.fastq\.gz"

@testset "matches with a Regex" begin
    dir = fixture(["A0001_L001_R2.fastq.gz", "A0001_L001_R1.fastq.gz", "notes.txt"])
    @test filesearch(FASTQ, dir) == [
        (filename = "A0001_L001_R1.fastq.gz", directory = dir, sample = "A0001", R = "1"),
        (filename = "A0001_L001_R2.fastq.gz", directory = dir, sample = "A0001", R = "2"),
    ]
    @test eltype(filesearch(FASTQ, dir)) ==
        @NamedTuple{filename::String, directory::String, sample::String, R::String}
end

@testset "strict matching" begin
    dir = fixture(["xA0001_L001_R1.fastq.gz", "A0001_L001_R1.fastq.gz.bak"])
    @test isempty(filesearch(FASTQ, dir))
    @test length(filesearch(FASTQ, dir; strict = false, distinct = false)) == 2
    @test only(filesearch(r"(?<n>1|12)", fixture(["12"]))).n == "12"
    @test only(filesearch(r"(?<n>1|12)", fixture(["12"]); strict = false)).n == "1"
end

const SAMPLES = r"(?<sample>s\d+)_R(?<R>\d)"

@testset "distinct" begin
    @testset "non-strict duplicates" begin
        dir = fixture(["sample1_R1.fastq.gz", "mod_sample1_R1.fastq.gz", "sample1_R2.fastq.gz"])
        pattern = r"(?<sample>sample\d+)_R(?<R>\d)"
        err = @test_throws DuplicateMatchesError filesearch(pattern, dir; strict = false)
        @test err.value.duplicates == [
            (sample = "sample1", R = "1") => [joinpath(dir, "mod_sample1_R1.fastq.gz"), joinpath(dir, "sample1_R1.fastq.gz")],
        ]
        message = sprint(showerror, err.value)
        @test occursin("1 combination of capture values matches more than one file", message)
        @test occursin(joinpath(dir, "mod_sample1_R1.fastq.gz"), message)
        @test occursin("Pass `distinct = false`", message)
        @test length(filesearch(pattern, dir; strict = false, distinct = false)) == 3
    end

    @testset "uncaptured text differs" begin
        dir = fixture(["s1_L001_R1", "s1_R1", "s2_R1"])
        pattern = r"(?<sample>s\d)(?:_L\d+)?_R(?<R>\d)"
        err = @test_throws DuplicateMatchesError filesearch(pattern, dir)
        @test only(err.value.duplicates) == ((sample = "s1", R = "1") => [joinpath(dir, "s1_L001_R1"), joinpath(dir, "s1_R1")])
    end

    @testset "same name in different directories" begin
        dir = fixture(["a/s1_R1", "b/s1_R1", "b/s2_R1"])
        @test length(filesearch(SAMPLES, dir; recursive = true, select = (sample = "s2",))) == 1
        err = @test_throws DuplicateMatchesError filesearch(SAMPLES, dir; recursive = true)
        @test only(err.value.duplicates) == ((sample = "s1", R = "1") => [joinpath(dir, "a", "s1_R1"), joinpath(dir, "b", "s1_R1")])
        @test length(filesearch(SAMPLES, dir; recursive = true, distinct = false)) == 3
    end

    @testset "duplicates are sorted and truncated" begin
        names = ["$(prefix)s$(i)_R1" for prefix in ("", "x") for i in 1:22]
        err = @test_throws DuplicateMatchesError filesearch(SAMPLES, fixture(names); strict = false)
        @test [first(entry).sample for entry in err.value.duplicates] == sort(["s$i" for i in 1:22])
        @test occursin("… and 2 more", sprint(showerror, err.value))
    end

    @testset "patterns without named captures are not checked" begin
        @test length(filesearch(r"s\d_R1", fixture(["a/s1_R1", "b/s1_R1"]); recursive = true)) == 2
    end

    @testset "distinct runs before require" begin
        dir = fixture(["s1_R1", "xs1_R1"])
        @test_throws DuplicateMatchesError filesearch(SAMPLES, dir; strict = false, require = (R = 1:2,))
        @test_throws MissingMatchesError filesearch(SAMPLES, dir; strict = false, distinct = false, require = (R = 1:2,))
    end
end

@testset "capture fields" begin
    dir = fixture(["a_1.txt", "b.txt"])
    @test filesearch(r"a_\d\.txt", dir) == [(filename = "a_1.txt", directory = dir)]
    @test filesearch(r"(a)_(?<n>\d)\.txt", dir) == [(filename = "a_1.txt", directory = dir, n = "1")]
    result = filesearch(r"(?<s>[a-z])(?<n>_\d)?\.txt", dir)
    @test [(m.s, m.n) for m in result] == [("a", "_1"), ("b", "")]
    @test fieldtype(eltype(result), :n) == String
end

@testset "reserved capture names" begin
    dir = fixture(["a"])
    @test_throws ArgumentError filesearch(r"(?<filename>a)", dir)
    @test_throws ArgumentError filesearch(r"(?<directory>a)", dir)
end

@testset "empty result has a concrete eltype" begin
    result = filesearch(FASTQ, fixture(String[]))
    @test isempty(result)
    @test isconcretetype(eltype(result))
    @test fieldnames(eltype(result)) == (:filename, :directory, :sample, :R)
end

@testset "directories are not matched" begin
    dir = fixture(["A0001_L001_R1.fastq.gz/inner"])
    @test isempty(filesearch(FASTQ, dir))
end

# Creating symlinks on Windows needs developer mode or elevated rights.
Sys.iswindows() || @testset "symlinks" begin
    dir = fixture(["target.txt"])
    symlink(joinpath(dir, "target.txt"), joinpath(dir, "link.txt"))
    symlink(joinpath(dir, "absent.txt"), joinpath(dir, "broken.txt"))
    for recursive in (false, true)
        @test [m.filename for m in filesearch(r".*\.txt", dir; recursive)] == ["link.txt", "target.txt"]
    end
end

@testset "recursion" begin
    dir = fixture(["a.txt", "sub/b.txt", "sub/deeper/c.txt"])
    @test [m.filename for m in filesearch(r".*\.txt", dir)] == ["a.txt"]
    @test [(m.directory, m.filename) for m in filesearch(r".*\.txt", dir; recursive = true)] == [
        (dir, "a.txt"),
        (joinpath(dir, "sub"), "b.txt"),
        (joinpath(dir, "sub", "deeper"), "c.txt"),
    ]
end

@testset "invalid dir" begin
    dir = fixture(["file.txt"])
    @test_throws ArgumentError filesearch(FASTQ, joinpath(dir, "absent"))
    @test_throws ArgumentError filesearch(FASTQ, joinpath(dir, "file.txt"))
end

@testset "relative and absolute dir" begin
    dir = fixture(["sub/a.txt"])
    cd(dir) do
        @test only(filesearch(r"a\.txt", "sub")).directory == "sub"
        @test only(filesearch(r"a\.txt", "."; recursive = true)).directory == joinpath(".", "sub")
    end
    @test only(filesearch(r"a\.txt", joinpath(dir, "sub"))).directory == joinpath(dir, "sub")
end

@testset "Pattern and Regex agree" begin
    dir = fixture(["A1_L001_R1.fastq.gz", "A1_L001_R2.fastq.gz", "A1_L001_R3.fastq.gz", "x.txt"])
    @test filesearch(Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2"), dir) == filesearch(FASTQ, dir)
end

@testset "Tables integration" begin
    dir = fixture(["A0001_L001_R1.fastq.gz", "A0002_L001_R1.fastq.gz"])
    result = filesearch(FASTQ, dir)
    @test Tables.istable(result)
    @test Tables.columntable(result).sample == ["A0001", "A0002"]
    df = DataFrame(result)
    @test names(df) == ["filename", "directory", "sample", "R"]
    @test df.R == ["1", "1"]
end
