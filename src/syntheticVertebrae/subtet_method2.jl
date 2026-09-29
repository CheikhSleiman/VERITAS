function subtet_method2(E, V)
    isempty(E) && return typeof(E)(), copy(V)

    T = typeof(first(E))
    Es = Vector{T}(undef, 4*length(E))
    Vn = Point{3,Float64}[]
    sizehint!(Vn, length(E))

    local_faces = (
        (1, 2, 3),
        (1, 4, 2),
        (2, 4, 3),
        (3, 4, 1),
    )

    nV = length(V)
    q = 1
    for (ie, e) in enumerate(E)
        ids = ntuple(j -> Int(e[j]), 4)
        c = Point{3,Float64}(
            mean(V[i][1] for i in ids),
            mean(V[i][2] for i in ids),
            mean(V[i][3] for i in ids),
        )
        push!(Vn, c)
        centre_id = nV + ie

        for lf in local_faces
            Es[q] = T(ids[lf[1]], ids[lf[2]], ids[lf[3]], centre_id)
            q += 1
        end
    end

    return Es, vcat(copy(V), Vn)
end

