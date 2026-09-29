function vertex_normals_gibbon(F, V)
    Nf = triangle_face_normals_gibbon(F, V)
    acc = [zeros(Float64, 3) for _ in eachindex(V)]

    for (i, f) in enumerate(F)
        n = Nf[i]
        for v in f
            a = acc[Int(v)]
            a[1] += n[1]
            a[2] += n[2]
            a[3] += n[3]
        end
    end

    Nv = Vector{Point{3,Float64}}(undef, length(V))
    for i in eachindex(V)
        a = acc[i]
        s = sqrt(a[1]^2 + a[2]^2 + a[3]^2)
        s > 0 || error("Zero vertex normal at vertex $i")
        Nv[i] = Point{3,Float64}(a[1]/s, a[2]/s, a[3]/s)
    end
    return Nv
end

