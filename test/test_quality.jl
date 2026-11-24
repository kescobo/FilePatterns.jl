using Aqua: Aqua
using ExplicitImports: check_no_implicit_imports, check_no_stale_explicit_imports
using JET: JET

Aqua.test_all(FilePatterns)

@test check_no_implicit_imports(FilePatterns) === nothing
@test check_no_stale_explicit_imports(FilePatterns) === nothing

JET.test_package(FilePatterns; target_modules = (FilePatterns,))
