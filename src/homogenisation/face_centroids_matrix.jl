function face_centroids_matrix(F, V)
    G = Matrix{Float64}(undef, 3, length(F))

    Threads.@threads for i in eachindex(F)
        f = F[i]
        n = length(f)

        sx = 0.0
        sy = 0.0
        sz = 0.0

        @inbounds for q in f
            p = V[Int(q)]
            sx += p[1]
            sy += p[2]
            sz += p[3]
        end

        G[1, i] = sx / n
        G[2, i] = sy / n
        G[3, i] = sz / n
    end

    return G
end

