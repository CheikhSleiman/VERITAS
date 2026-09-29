function element_centroid(e, V)

    x = 0.0
    y = 0.0
    z = 0.0

    for id in e
        p = V[Int(id)]

        x += p[1]
        y += p[2]
        z += p[3]
    end

    n = length(e)

    return Point{3,Float64}(
        x / n,
        y / n,
        z / n,
    )
end




# =============================================================================
# Helpers: Surface labelling (GIBBON-compatible)
# =============================================================================

