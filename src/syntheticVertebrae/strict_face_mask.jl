function strict_face_mask(F, logic)
    # MATLAB:
    # indNotInLogic = unique(F(~logic,:));
    # logic = logic & ~any(ismember(F,indNotInLogic),2);
    bad_vertices = Set{Int}()
    for i in eachindex(F)
        if !logic[i]
            for v in F[i]
                push!(bad_vertices, Int(v))
            end
        end
    end

    out = copy(logic)
    for i in eachindex(F)
        if out[i]
            out[i] = !any(Int(v) in bad_vertices for v in F[i])
        end
    end
    return out
end

