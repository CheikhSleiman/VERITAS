function tri_surf_logic_sharp_fix(F, L, dir_opt::Int=3)
    length(F) == length(L) || error("length(F) != length(L)")

    if dir_opt == 1
        in_vertices = Set{Int}()
        for i in eachindex(F)
            L[i] || continue
            for v in F[i]
                push!(in_vertices, Int(v))
            end
        end
        return BitVector([all(Int(v) in in_vertices for v in f) for f in F])

    elseif dir_opt == 2
        out_vertices = Set{Int}()
        for i in eachindex(F)
            L[i] && continue
            for v in F[i]
                push!(out_vertices, Int(v))
            end
        end
        return BitVector([L[i] && !all(Int(v) in out_vertices for v in F[i]) for i in eachindex(F)])

    elseif dir_opt == 3
        return tri_surf_logic_sharp_fix(F,
            tri_surf_logic_sharp_fix(F, L, 1), 2)

    elseif dir_opt == 4
        return tri_surf_logic_sharp_fix(F,
            tri_surf_logic_sharp_fix(F, L, 2), 1)

    else
        error("dir_opt must be 1, 2, 3, or 4")
    end
end

