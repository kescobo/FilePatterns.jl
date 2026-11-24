root = fixture(
    [
        "fastqs/A0001_L001_R1.fastq.gz",
        "fastqs/A0001_L001_R2.fastq.gz",
        "fastqs/A0002_L001_R1.fastq.gz",
        "fastqs/A0002_L001_R2.fastq.gz",
        "fastqs/README.txt",
        "lanes/B0001_L002_R1.fastq.gz",
        "lanes/B0001_R1.fastq.gz",
        "runs/2024/run1.csv",
        "runs/2025/run2.csv",
        "reads/S1_R1.fastq.gz",
        "reads/S1_R2.fastq.gz",
        "reads/S2_R1.fastq.gz",
    ],
)

cd(root) do
    fastq = r"(?<sample>[A-Z0-9]+)_L001_R(?<R>1|2)\.fastq\.gz"
    pat = Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2")

    @testset "quick start" begin
        result = filesearch(fastq, "fastqs")
        @test result == [
            (filename = "A0001_L001_R1.fastq.gz", directory = "fastqs", sample = "A0001", R = "1"),
            (filename = "A0001_L001_R2.fastq.gz", directory = "fastqs", sample = "A0001", R = "2"),
            (filename = "A0002_L001_R1.fastq.gz", directory = "fastqs", sample = "A0002", R = "1"),
            (filename = "A0002_L001_R2.fastq.gz", directory = "fastqs", sample = "A0002", R = "2"),
        ]
        @test eltype(result) == @NamedTuple{filename::String, directory::String, sample::String, R::String}
        @test repr(pat) == "Pattern(\"<sample>_L001_R<R>.fastq.gz\"; R = r\"1|2\")"
        @test filesearch(pat, "fastqs") == result
    end

    @testset "regex patterns" begin
        @test filesearch(r"(?<sample>[A-Z0-9]+)(?:_L(?<lane>\d+))?_R(?<R>\d)\.fastq\.gz", "lanes") == [
            (filename = "B0001_L002_R1.fastq.gz", directory = "lanes", sample = "B0001", lane = "002", R = "1"),
            (filename = "B0001_R1.fastq.gz", directory = "lanes", sample = "B0001", lane = "", R = "1"),
        ]
    end

    @testset "template patterns" begin
        @test Pattern("<sample>_L001_R<R>.fastq.gz").regex == r"(?<sample>[^/]+?)_L001_R(?<R>[^/]+?)\.fastq\.gz"
        @test repr(Pattern("<sample>_R<R>.fastq.gz"; sample = "[A-Z]\\d+", R = r"1|2")) ==
            "Pattern(\"<sample>_R<R>.fastq.gz\"; sample = r\"[A-Z]\\d+\", R = r\"1|2\")"
        @test Pattern("<<<tag>>.txt").regex == r"<(?<tag>[^/]+?)>\.txt"
    end

    @testset "strict and non-strict" begin
        none = filesearch(r"(?<sample>A\d+)_R1", "fastqs")
        @test isempty(none)
        @test eltype(none) == @NamedTuple{filename::String, directory::String, sample::String}
        @test [m.sample for m in filesearch(r"(?<sample>A\d+)_L001_R1", "fastqs"; strict = false)] == ["A0001", "A0002"]
    end

    @testset "recursion" begin
        @test [joinpath(m.directory, m.filename) for m in filesearch(r"(?<run>run\d+)\.csv", "runs"; recursive = true)] ==
            [joinpath("runs", "2024", "run1.csv"), joinpath("runs", "2025", "run2.csv")]
    end

    @testset "select" begin
        @test [m.filename for m in filesearch(pat, "fastqs"; select = (sample = "A0002", R = 1:2))] ==
            ["A0002_L001_R1.fastq.gz", "A0002_L001_R2.fastq.gz"]
        @test [m.filename for m in filesearch(pat, "fastqs"; select = [(sample = "A0001", R = 1), (sample = "A0002", R = 2)])] ==
            ["A0001_L001_R1.fastq.gz", "A0002_L001_R2.fastq.gz"]
    end

    @testset "require" begin
        err = @test_throws MissingMatchesError filesearch(pat, "fastqs"; require = (sample = ["A0001", "A0002", "A0003"], R = 1:2))
        @test sprint(showerror, err.value) == """
            MissingMatchesError: 2 expected combinations have no matching file in "fastqs" for pattern Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2"):
              (sample = "A0003", R = "1")
              (sample = "A0003", R = "2")"""
        err = @test_throws MissingMatchesError filesearch(Pattern("<sample>_R<R>.fastq.gz"), "reads"; require = (R = 1:2,))
        @test sprint(showerror, err.value) == """
            MissingMatchesError: 1 expected combination has no matching file in "reads" for pattern Pattern("<sample>_R<R>.fastq.gz"):
              (sample = "S2", R = "2")"""
        @test err.value.missing == [(sample = "S2", R = "2")]
        @test eltype(err.value.missing) == @NamedTuple{sample::String, R::String}
    end

    @testset "DataFrames" begin
        df = DataFrame(filesearch(pat, "fastqs"))
        @test size(df) == (4, 4)
        @test df.sample == ["A0001", "A0001", "A0002", "A0002"]
        @test df.R == ["1", "2", "1", "2"]
        @test filesearch(pat, "fastqs"; select = df[1:2, [:sample, :R]]) == filesearch(pat, "fastqs")[1:2]
    end
end
