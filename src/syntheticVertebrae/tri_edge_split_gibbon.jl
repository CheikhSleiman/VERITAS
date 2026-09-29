function tri_edge_split_gibbon(F, V, edge, CF)
    a, b = Int(edge[1]), Int(edge[2])

    split_logic = [(a in f) && (b in f) for f in F]
    keep_idx = findall(.!split_logic)
    rem_idx = findall(split_logic)

    F_keep = F[keep_idx]
    CF_keep = CF[keep_idx]

    old_normals = [face_normal_triangle(F[i], V) for i in rem_idx]

    pa, pb = V[a], V[b]
    Vs = copy(V)
    push!(Vs, Point{3,Float64}(
        0.5*(pa[1]+pb[1]),
        0.5*(pa[2]+pb[2]),
        0.5*(pa[3]+pb[3]),
    ))
    m = length(Vs)

    FT = typeof(first(F))
    F_new = FT[]
    CF_new = eltype(CF)[]

    for (q, i_face) in enumerate(rem_idx)
        f = F[i_face]
        other = only(Int(v) for v in f if Int(v) != a && Int(v) != b)

        candidates = [
            FT(other, a, m),
            FT(other, m, b),
        ]

        for fn in candidates
            nn = face_normal_triangle(fn, Vs)
            if dot(nn, old_normals[q]) < 0
                fn = FT(reverse(Tuple(fn))...)
            end
            push!(F_new, fn)
            push!(CF_new, CF[i_face])
        end
    end

    return vcat(F_keep, F_new), Vs, vcat(CF_keep, CF_new)
end

