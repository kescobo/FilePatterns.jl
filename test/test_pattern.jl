using FilePatterns: capture_names

@testset "compiles to a regex" begin
    pat = Pattern("<sample>_L001_R<R>.fastq.gz")
    @test pat.regex == r"(?<sample>[^/]+?)_L001_R(?<R>[^/]+?)\.fastq\.gz"
    @test capture_names(pat.regex) == (:sample, :R)
    @test capture_names(Pattern("plain.txt").regex) == ()
end

@testset "literal text is escaped" begin
    dir = fixture(["a.b", "axb", "x(1)+[2]{3}^\$.txt"])
    @test [m.filename for m in filesearch(Pattern("a.b"), dir)] == ["a.b"]
    @test length(filesearch(Pattern("x(1)+[2]{3}^\$.txt"), dir)) == 1
    literal = "a|b?c*d\\e"
    @test occursin(FilePatterns._anchor(Pattern(literal).regex), literal)
end

@testset "<< is a literal <, lone > is literal" begin
    @test match(Pattern("<<a>_<n>").regex, "<a>_1")[:n] == "1"
    @test match(Pattern("a>b_<n>").regex, "a>b_2")[:n] == "2"
    @test Pattern("x<<y").regex == r"x<y"
end

@testset "custom capture regexes" begin
    dir = fixture(["s_R1.txt", "s_R2.txt", "s_R3.txt"])
    expected = ["s_R1.txt", "s_R2.txt"]
    @test [m.filename for m in filesearch(Pattern("<s>_R<R>.txt"; R = r"1|2"), dir)] == expected
    @test [m.filename for m in filesearch(Pattern("<s>_R<R>.txt"; R = "1|2"), dir)] == expected
    @test length(filesearch(Pattern("<s>_R<R>.txt"; R = r"(1|2)"), dir)) == 2
end

@testset "errors" begin
    @test_throws ArgumentError Pattern("")
    @test_throws r"unclosed `<` at position 3" Pattern("ab<cd")
    @test_throws r"invalid capture name \"1x\" at position 1" Pattern("<1x>")
    @test_throws r"invalid capture name \"\"" Pattern("<>")
    @test_throws r"duplicate capture name `a` at position 5" Pattern("<a>_<a>")
    @test_throws r"`filename`.*reserved" Pattern("<filename>")
    @test_throws r"`directory`.*reserved" Pattern("<directory>.txt")
    @test_throws r"name no capture" Pattern("<a>"; b = r"x")
    @test_throws r"must not contain named groups" Pattern("<a>"; a = r"(?<b>x)")
    @test_throws r"must not contain named groups" Pattern("<a>"; a = "(?<b>x)")
    @test_throws r"flags" Pattern("<a>"; a = r"x"i)
end

@testset "show round-trips" begin
    for pat in (
            Pattern("<sample>_L001_R<R>.fastq.gz"; R = r"1|2"),
            Pattern("<a>-<b>.\$txt"; a = "[0-9]+", b = r"x|y"),
            Pattern("<<literal"),
        )
        shown = repr(pat)
        parsed = eval(Meta.parse(shown))
        @test repr(parsed) == shown
        @test parsed.regex == pat.regex
    end
    @test repr(Pattern("<s>_R<R>"; R = r"1|2")) == "Pattern(\"<s>_R<R>\"; R = r\"1|2\")"
end
