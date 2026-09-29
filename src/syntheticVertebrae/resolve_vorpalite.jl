# =============================================================================
# VERITAS - Synthetic vertebrae helper functions
# Extracted unchanged from the validated reference createVertebralPhantom.jl
# =============================================================================

# =============================================================================
# Helpers: GIBBON ggremesh / Vorpalite
# =============================================================================

function resolve_vorpalite()
    candidates = String[]

    if haskey(ENV, "VORPALITE")
        push!(candidates, ENV["VORPALITE"])
    end

    p = Sys.which("vorpalite")
    p !== nothing && push!(candidates, p)

    push!(candidates,
        joinpath(homedir(), "src", "geogram", "build",
                 "Linux64-gcc-dynamic-Release", "bin", "vorpalite"),
    )

    for c in candidates
        isfile(c) && return c
    end

    build_root = joinpath(homedir(), "src", "geogram", "build")
    if isdir(build_root)
        for (root, _, files) in walkdir(build_root)
            if "vorpalite" in files
                return joinpath(root, "vorpalite")
            end
        end
    end

    error("Could not locate vorpalite. Set ENV[\"VORPALITE\"] to the executable path.")
end

