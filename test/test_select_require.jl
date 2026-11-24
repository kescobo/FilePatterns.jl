const READS = r"(?<sample>[a-z0-9]+)_R(?<R>\d)"
const LANES = r"(?<sample>[a-z0-9]+)(?:_L(?<lane>\d))?_R(?<R>\d)"

filenames(result) = [m.filename for m in result]

@testset "select" begin
    dir = fixture(["s1_R1", "s1_R2", "s2_R1", "s2_R2", "s3_R1"])

    @testset "product form" begin
        @test filenames(filesearch(READS, dir; select = (R = "2",))) == ["s1_R2", "s2_R2"]
        @test filenames(filesearch(READS, dir; select = Dict(:R => "2"))) == ["s1_R2", "s2_R2"]
        @test filenames(filesearch(READS, dir; select = (sample = ["s1", "s3"], R = 1))) == ["s1_R1", "s3_R1"]
        @test filenames(filesearch(READS, dir; select = Dict(:sample => ["s1", "s3"], :R => 1:2))) ==
            ["s1_R1", "s1_R2", "s3_R1"]
        @test filenames(filesearch(READS, dir; select = (R = 1:2,))) == filenames(filesearch(READS, dir))
    end

    @testset "table form" begin
        rows = [(sample = "s1", R = 1), (sample = "s2", R = 2)]
        @test filenames(filesearch(READS, dir; select = rows)) == ["s1_R1", "s2_R2"]
        @test filenames(filesearch(READS, dir; select = DataFrame(rows))) == ["s1_R1", "s2_R2"]
    end

    @testset "NamedTuple of vectors is a product unless wrapped" begin
        spec = (sample = ["s1", "s2"], R = ["1", "2"])
        @test filenames(filesearch(READS, dir; select = spec)) == ["s1_R1", "s1_R2", "s2_R1", "s2_R2"]
        @test filenames(filesearch(READS, dir; select = Tables.rowtable(spec))) == ["s1_R1", "s2_R2"]
    end

    @testset "invalid specs" begin
        @test_throws r"unknown capture name.*:lane.*valid names are :sample, :R" filesearch(READS, dir; select = (lane = 1,))
        @test_throws ArgumentError filesearch(READS, dir; select = (filename = "s1_R1",))
        @test_throws ArgumentError filesearch(READS, dir; select = [(lane = 1,)])
        @test_throws ArgumentError filesearch(READS, dir; select = 1)
    end

    @testset "non-participating captures" begin
        lanes = fixture(["a_L1_R1", "a_R1", "b_L2_R1"])
        @test filenames(filesearch(LANES, lanes; select = (lane = "",))) == ["a_R1"]
    end
end

@testset "require" begin
    @testset "satisfied" begin
        dir = fixture(["s1_R1", "s1_R2", "s5_R1", "s5_R2", "s5_R3", "other.txt"])
        @test filesearch(READS, dir; require = (R = 1:2,)) == filesearch(READS, dir)
        @test filenames(filesearch(READS, dir; require = (sample = ["s1", "s5"], R = 1:2))) ==
            ["s1_R1", "s1_R2", "s5_R1", "s5_R2", "s5_R3"]
    end

    @testset "missing combinations, all keys" begin
        dir = fixture(["s1_R1", "s1_R2", "s2_R1"])
        err = @test_throws MissingMatchesError filesearch(READS, dir; require = (sample = ["s1", "s2"], R = 1:2))
        @test err.value.missing == [(sample = "s2", R = "2")]
        message = sprint(showerror, err.value)
        @test occursin("1 expected combination has no matching file", message)
        @test occursin("(sample = \"s2\", R = \"2\")", message)
        @test occursin(repr(dir), message)
    end

    @testset "groups by the remaining captures" begin
        dir = fixture(["sample1_R1", "sample5_R2"])
        err = @test_throws MissingMatchesError filesearch(READS, dir; require = (R = 1:2,))
        @test err.value.missing == [(sample = "sample1", R = "2"), (sample = "sample5", R = "1")]
    end

    @testset "two group captures" begin
        dir = fixture(["a_L1_R1", "a_L1_R2", "a_L2_R1", "b_L1_R1", "b_L1_R2"])
        err = @test_throws MissingMatchesError filesearch(LANES, dir; require = (R = 1:2,))
        @test err.value.missing == [(sample = "a", lane = "2", R = "2")]
    end

    @testset "non-participating capture is its own group" begin
        dir = fixture(["a_L1_R1", "a_L1_R2", "a_R1"])
        err = @test_throws MissingMatchesError filesearch(LANES, dir; require = (R = 1:2,))
        @test err.value.missing == [(sample = "a", lane = "", R = "2")]
    end

    @testset "no matches" begin
        dir = fixture(["other.txt"])
        err = @test_throws MissingMatchesError filesearch(READS, dir; require = (R = 1:2,))
        @test err.value.missing == [(R = "1",), (R = "2",)]
        dir = fixture(["s1_R1"])
        err = @test_throws MissingMatchesError filesearch(READS, dir; select = (R = 2,), require = (R = 1,))
        @test err.value.missing == [(R = "1",)]
    end

    @testset "table form" begin
        dir = fixture(["s1_R1", "s1_R2", "s2_R1"])
        rows = [(sample = "s1", R = 1), (sample = "s2", R = 2)]
        err = @test_throws MissingMatchesError filesearch(READS, dir; require = rows)
        @test err.value.missing == [(sample = "s2", R = "2")]
        err = @test_throws MissingMatchesError filesearch(READS, dir; require = [(R = 1,), (R = 2,)])
        @test err.value.missing == [(sample = "s2", R = "2")]
        @test length(filesearch(READS, dir; require = DataFrame(R = [1]))) == 3
    end

    @testset "with select" begin
        dir = fixture(["s1_R1", "s1_R2", "s2_R1", "s3_R1", "s3_R2"])
        result = filesearch(READS, dir; select = (sample = ["s1", "s3"],), require = (R = 1:2,))
        @test filenames(result) == ["s1_R1", "s1_R2", "s3_R1", "s3_R2"]
        err = @test_throws MissingMatchesError filesearch(READS, dir; select = (R = 1,), require = (R = 1:2,))
        @test length(err.value.missing) == 3
    end

    @testset "message is truncated" begin
        dir = fixture(["s_R1"])
        err = @test_throws MissingMatchesError filesearch(READS, dir; require = (R = 1:8, sample = ["s", "t", "u"]))
        message = sprint(showerror, err.value)
        @test occursin("23 expected combinations", message)
        @test occursin("… and 3 more", message)
    end
end
