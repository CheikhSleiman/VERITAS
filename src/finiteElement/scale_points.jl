function scale_points(V, factor::Real)

    s = Float64(factor)

    return [
        Point{3,Float64}(
            s * Float64(v[1]),
            s * Float64(v[2]),
            s * Float64(v[3]),
        )
        for v in V
    ]
end

