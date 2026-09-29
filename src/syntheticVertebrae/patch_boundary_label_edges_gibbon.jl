function patch_boundary_label_edges_gibbon(F, CF, ET)
    # patchEdges(F,1): unique patch edges, orientation from first occurrence.
    edge_first = Dict{Tuple{Int,Int},Tuple{Int,Int}}()
    for f in F
        ids = (Int(f[1]), Int(f[2]), Int(f[3]))
        for (a,b) in ((ids[1],ids[2]), (ids[2],ids[3]), (ids[3],ids[1]))
            key = a < b ? (a,b) : (b,a)
            get!(edge_first, key, (a,b))
        end
    end

    boundary_keys = Set{Tuple{Int,Int}}()
    for c in unique(CF)
        counts = Dict{Tuple{Int,Int},Int}()
        for (i,f) in enumerate(F)
            CF[i] == c || continue
            ids = (Int(f[1]), Int(f[2]), Int(f[3]))
            for (a,b) in ((ids[1],ids[2]), (ids[2],ids[3]), (ids[3],ids[1]))
                key = a < b ? (a,b) : (b,a)
                counts[key] = get(counts,key,0) + 1
            end
        end
        for (key,n) in counts
            n == 1 && push!(boundary_keys,key)
        end
    end

    return [ET(edge_first[key]...) for key in keys(edge_first) if key in boundary_keys]
end

