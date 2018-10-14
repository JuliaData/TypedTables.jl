using Documenter
using TypedTables

makedocs(
    modules = [TypedTables]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    deps = Deps.pip("mkdocs", "python-markdown-math"),
    repo = "github.com/FugroRoames/TypedTables.jl.git",
    julia = "1.0",
    osname = "linux"
)
