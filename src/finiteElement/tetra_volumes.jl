# =============================================================================
# VERITAS - Finite-element mesh export and conversion functions
# Extracted unchanged from the validated reference createVertebralPhantom.jl
# =============================================================================

# Helpers: Final mesh export
# -----------------------------------------------------------------------------

function tetra_volumes(E, V)

    Vol = Vector{Float64}(undef, length(E))

    Threads.@threads for i in eachindex(E)

        e = E[i]

        p1 = V[Int(e[1])]
        p2 = V[Int(e[2])]
        p3 = V[Int(e[3])]
        p4 = V[Int(e[4])]

        a1 = Float64(p2[1] - p1[1])
        a2 = Float64(p2[2] - p1[2])
        a3 = Float64(p2[3] - p1[3])

        b1 = Float64(p3[1] - p1[1])
        b2 = Float64(p3[2] - p1[2])
        b3 = Float64(p3[3] - p1[3])

        c1 = Float64(p4[1] - p1[1])
        c2 = Float64(p4[2] - p1[2])
        c3 = Float64(p4[3] - p1[3])

        cx = a2*b3 - a3*b2
        cy = a3*b1 - a1*b3
        cz = a1*b2 - a2*b1

        Vol[i] = abs(cx*c1 + cy*c2 + cz*c3) / 6.0
    end

    return Vol
end

