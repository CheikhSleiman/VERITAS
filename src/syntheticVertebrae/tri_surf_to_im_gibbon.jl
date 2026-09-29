function tri_surf_to_im_gibbon(F, V, voxel_size::Real, im_origin, im_size)
    # Direct port of GIBBON triSurf2Im for the scalar-voxel-size, explicit
    # origin, explicit-size call used by createVertebralPhantom.m.
    F, V = clean_unused_vertices(F, V)

    edge_lengths = patch_edge_lengths_gibbon(F, V)
    max_edge = maximum(edge_lengths)

    v = Float64(voxel_size)
    n_raw = max_edge / v
    n_sub = ((n_raw - 1.0) > eps(1.0)) ? ceil(Int, n_raw) : 1

    nI, nJ, nK = Int.(Tuple(im_size))
    surface = falses(nI, nJ, nK)

    ox, oy, oz = Float64(im_origin[1]), Float64(im_origin[2]), Float64(im_origin[3])

    @inline function mark_point!(p)
        # cart2im.m:
        # I = Y/v + 0.5; J = X/v + 0.5; K = Z/v + 0.5
        x = Float64(p[1]) - ox
        y = Float64(p[2]) - oy
        z = Float64(p[3]) - oz

        I = clamp(matlab_round_positive(y/v + 0.5), 1, nI)
        J = clamp(matlab_round_positive(x/v + 0.5), 1, nJ)
        K = clamp(matlab_round_positive(z/v + 0.5), 1, nK)
        surface[I, J, K] = true
        return nothing
    end

    if n_sub == 1
        for p in V
            mark_point!(p)
        end
    else
        # Equivalent geometric sample set to subtri(F,V,n_sub), streamed so
        # the very dense temporary subdivided mesh need not be retained.
        invn = 1.0 / n_sub
        for f in F
            p1 = V[Int(f[1])]
            p2 = V[Int(f[2])]
            p3 = V[Int(f[3])]

            for i in 0:n_sub
                for j in 0:(n_sub-i)
                    k = n_sub - i - j
                    a, b, c = i*invn, j*invn, k*invn
                    p = Point{3,Float64}(
                        a*p1[1] + b*p2[1] + c*p3[1],
                        a*p1[2] + b*p2[2] + c*p3[2],
                        a*p1[3] + b*p2[3] + c*p3[3],
                    )
                    mark_point!(p)
                end
            end
        end
    end

    # bwlabeln(~logicVertices,6) followed by labelExterior=1 is equivalent,
    # for the padded images used here, to flooding the first complement
    # component with 6-connectivity.
    exterior = exterior_fill_6(surface)

    M = zeros(UInt8, size(surface))
    M[surface] .= 0x01
    interior = .!surface .& .!exterior
    M[interior] .= 0x02

    println("  triSurf2Im subdivision factor : ", n_sub)
    println("  surface voxels                : ", count(identity, surface))
    println("  interior voxels               : ", count(identity, interior))

    return M
end

