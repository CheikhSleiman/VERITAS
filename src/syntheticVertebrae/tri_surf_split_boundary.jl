function tri_surf_split_boundary(F, V, E_boundary, target_n, CF)
    isempty(E_boundary) && error("Edge set is empty")
    length(E_boundary) > target_n && error("Current number of edges exceeds desired number")

    F = copy(F)
    V = copy(V)
    CF = copy(CF)
    E = copy(E_boundary)
    ET = typeof(first(E_boundary))

    while length(E) != target_n
        lengths = [norm(V[Int(e[1])] - V[Int(e[2])]) for e in E]
        ind_max = argmax(lengths)

        old_edges = [(Int(e[1]), Int(e[2])) for e in E]
        npre = length(V)

        F, V, CF = tri_edge_split_gibbon(F, V, E[ind_max], CF)
        npost = length(V)

        Eb = patch_boundary_label_edges_gibbon(F, CF, ET)
        new_nodes = Set((npre+1):npost)
        old_nodes = Set(v for e in old_edges for v in e)

        # Exact MATLAB logic:
        # all(ismember(Eb,E) | ismember(Eb,newNodes),2)
        E = [e for e in Eb if
            ((Int(e[1]) in old_nodes) || (Int(e[1]) in new_nodes)) &&
            ((Int(e[2]) in old_nodes) || (Int(e[2]) in new_nodes))
        ]
    end

    return F, V, E, CF
end

