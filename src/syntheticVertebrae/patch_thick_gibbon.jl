function patch_thick_gibbon(Fp1, Vp1, dir_set, layer_thickness, num_steps)
    num_steps >= 1 || error("num_steps must be >= 1")

    Nv = if dir_set isa Number
        [Point{3,Float64}(dir_set*n[1], dir_set*n[2], dir_set*n[3])
         for n in vertex_normals_gibbon(Fp1, Vp1)]
    else
        length(dir_set) == length(Vp1) || error("Number of offset vectors must match number of vertices")
        [Point{3,Float64}(d[1], d[2], d[3]) for d in dir_set]
    end

    Vp2 = [Point{3,Float64}(
        Vp1[i][1] + layer_thickness*Nv[i][1],
        Vp1[i][2] + layer_thickness*Nv[i][2],
        Vp1[i][3] + layer_thickness*Nv[i][3],
    ) for i in eachindex(Vp1)]

    nV = length(Vp1)
    VE = Point{3,Float64}[]
    sizehint!(VE, nV * (num_steps + 1))

    # GIBBON linspacen followed by X(:),Y(:),Z(:): layer-major ordering.
    for s in 0:num_steps
        t = s / num_steps
        for i in eachindex(Vp1)
            a, b = Vp1[i], Vp2[i]
            push!(VE, Point{3,Float64}(
                (1-t)*a[1] + t*b[1],
                (1-t)*a[2] + t*b[2],
                (1-t)*a[3] + t*b[3],
            ))
        end
    end

    E_shell = Vector{NTuple{6,Int}}()
    sizehint!(E_shell, length(Fp1) * num_steps)

    for s in 0:(num_steps-1)
        off1 = s*nV
        off2 = (s+1)*nV
        for f in Fp1
            a, b, c = Int(f[1]), Int(f[2]), Int(f[3])
            push!(E_shell, (a+off1, b+off1, c+off1,
                            a+off2, b+off2, c+off2))
        end
    end

    Fq1 = [TriangleFace{Int}(Int(f[1]), Int(f[2]), Int(f[3])) for f in Fp1]
    off = num_steps*nV
    Fq2 = [TriangleFace{Int}(Int(f[1])+off, Int(f[2])+off, Int(f[3])+off) for f in Fp1]

    return E_shell, VE, Fq1, Fq2
end

# Helper
