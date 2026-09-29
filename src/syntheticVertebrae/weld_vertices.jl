function weld_vertices(F, V)

    vertex_map = Dict{NTuple{3, Float64}, Int}()
    old_to_new = Vector{Int}(undef, length(V))

    Vnew = Point{3, Float64}[]

    for i in eachindex(V)

        p = V[i]
        key = (Float64(p[1]), Float64(p[2]), Float64(p[3]))

        idx = get(vertex_map, key, 0)

        if idx == 0
            push!(Vnew, Point{3, Float64}(key))
            idx = length(Vnew)
            vertex_map[key] = idx
        end

        old_to_new[i] = idx
    end

    Fnew = TriangleFace{Int}[
        TriangleFace{Int}(
            old_to_new[Int(f[1])],
            old_to_new[Int(f[2])],
            old_to_new[Int(f[3])],
        )
        for f in F
    ]

    return Fnew, Vnew
end

