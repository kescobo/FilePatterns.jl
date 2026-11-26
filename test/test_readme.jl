root = fixture(
    [
        "fastqs/A0001_L001_R1.fastq.gz",
        "fastqs/A0001_L001_R2.fastq.gz",
        "fastqs/A0002_L001_R1.fastq.gz",
        "fastqs/A0002_L001_R2.fastq.gz",
        "fastqs/README.txt",
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
    end

    @testset "sample sheet check" begin
        err = @test_throws MissingMatchesError filesearch(pat, "fastqs"; require = (sample = ["A0001", "A0002", "A0003"], R = 1:2))
        @test sprint(showerror, err.value) == """
            MissingMatchesError: 2 expected combinations have no matching file in "fastqs" for pattern Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2"):
              (sample = "A0003", R = "1")
              (sample = "A0003", R = "2")"""
    end
end
