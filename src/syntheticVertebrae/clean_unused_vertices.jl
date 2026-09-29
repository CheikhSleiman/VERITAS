function clean_unused_vertices(F, V)
    used = sort(unique(Int(v) for f in F for v in f))
    old_to_new = zeros(Int, length(V))
    for (j, i) in enumerate(used)
        old_to_new[i] = j
    end

    FT = typeof(first(F))
    Fc = [FT(ntuple(k -> old_to_new[Int(f[k])], length(f))...) for f in F]
    Vc = V[used]
    return Fc, Vc
end

