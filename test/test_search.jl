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
    @test length(filesearch(FASTQ, dir; strict = false)) == 2
    @test only(filesearch(r"(?<n>1|12)", fixture(["12"]))).n == "12"
    @test only(filesearch(r"(?<n>1|12)", fixture(["12"]); strict = false)).n == "1"
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
