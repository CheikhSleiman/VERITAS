function dilate_sphere(B, radius::Int)
    # MATLAB imdilate on a numeric image uses the neighbourhood maximum.
    # This matters for triSurf2Im images because they contain 0/1/2 labels.
    out = fill(zero(eltype(B)), size(B))

    n1, n2, n3 = size(B)

    for di in -radius:radius
        for dj in -radius:radius
            for dk in -radius:radius
                di^2 + dj^2 + dk^2 <= radius^2 || continue

                src1 = max(1, 1-di):min(n1, n1-di)
                src2 = max(1, 1-dj):min(n2, n2-dj)
                src3 = max(1, 1-dk):min(n3, n3-dk)

                dst1 = (first(src1)+di):(last(src1)+di)
                dst2 = (first(src2)+dj):(last(src2)+dj)
                dst3 = (first(src3)+dk):(last(src3)+dk)

                @views out[dst1, dst2, dst3] .= max.(
                    out[dst1, dst2, dst3],
                    B[src1, src2, src3],
                )
            end
        end
    end

    return out
end

