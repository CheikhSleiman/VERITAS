# =============================================================================
# VERITAS - Homogenisation and material mapping functions
# Extracted unchanged from the validated reference createVertebralPhantom.jl
# =============================================================================

# =============================================================================
# Main pipeline
# =============================================================================

# -----------------------------------------------------------------------------
# Homogenisation / BVTV
# -----------------------------------------------------------------------------

function tet_centroids(E, V)
    G = Matrix{Float64}(undef, 3, length(E))

    Threads.@threads for i in eachindex(E)
        e = E[i]
        p1 = V[Int(e[1])]
        p2 = V[Int(e[2])]
        p3 = V[Int(e[3])]
        p4 = V[Int(e[4])]

        G[1, i] = (p1[1] + p2[1] + p3[1] + p4[1]) / 4.0
        G[2, i] = (p1[2] + p2[2] + p3[2] + p4[2]) / 4.0
        G[3, i] = (p1[3] + p2[3] + p3[3] + p4[3]) / 4.0
    end

    return G
end

