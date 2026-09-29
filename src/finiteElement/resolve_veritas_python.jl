function resolve_veritas_python()

    candidates = String[]

    if haskey(ENV, "VERITAS_PYTHON")
        push!(candidates, ENV["VERITAS_PYTHON"])
    end

    push!(
        candidates,
        joinpath(
            homedir(),
            "miniforge3",
            "envs",
            "veritas",
            "bin",
            "python",
        ),
    )

    for candidate in candidates
        if isfile(candidate)
            return candidate
        end
    end

    error(
        "Could not find the VERITAS Python interpreter. " *
        "Expected ~/miniforge3/envs/veritas/bin/python or set ENV[\"VERITAS_PYTHON\"]."
    )
end

