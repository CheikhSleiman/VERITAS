function exterior_fill_6(surface::BitArray{3})
    n1, n2, n3 = size(surface)
    N = length(surface)

    surface[1] && error("triSurf2Im: first voxel is on the surface; exterior component cannot be identified")

    exterior = falses(size(surface))
    exterior[1] = true

    # Image sizes in this workflow are safely below typemax(Int32).
    N <= typemax(Int32) || error("Image too large for Int32 flood-fill queue")
    queue = Vector{Int32}()
    sizehint!(queue, min(N, 10_000_000))
    push!(queue, Int32(1))
    head = 1

    stride2 = n1
    stride3 = n1*n2

    while head <= length(queue)
        idx = Int(queue[head])
        head += 1

        i = ((idx - 1) % n1) + 1
        j = (((idx - 1) ÷ n1) % n2) + 1
        k = ((idx - 1) ÷ stride3) + 1

        if i > 1
            q = idx - 1
            if !surface[q] && !exterior[q]
                exterior[q] = true; push!(queue, Int32(q))
            end
        end
        if i < n1
            q = idx + 1
            if !surface[q] && !exterior[q]
                exterior[q] = true; push!(queue, Int32(q))
            end
        end
        if j > 1
            q = idx - stride2
            if !surface[q] && !exterior[q]
                exterior[q] = true; push!(queue, Int32(q))
            end
        end
        if j < n2
            q = idx + stride2
            if !surface[q] && !exterior[q]
                exterior[q] = true; push!(queue, Int32(q))
            end
        end
        if k > 1
            q = idx - stride3
            if !surface[q] && !exterior[q]
                exterior[q] = true; push!(queue, Int32(q))
            end
        end
        if k < n3
            q = idx + stride3
            if !surface[q] && !exterior[q]
                exterior[q] = true; push!(queue, Int32(q))
            end
        end
    end

    return exterior
end

