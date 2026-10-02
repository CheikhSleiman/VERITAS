function get_inner_point_outside_sphere_gibbon(F, V, center, radius;
    search_radius=nothing, voxel_size=nothing)
    if voxel_size === nothing
        voxel_size = mean(Comodo.edgelengths(F, V)) / 2
    end
    if search_radius === nothing
        search_radius = 3 * voxel_size
    end

    xmin = minimum(p[1] for p in V) - 2*voxel_size
    ymin = minimum(p[2] for p in V) - 2*voxel_size
    zmin = minimum(p[3] for p in V) - 2*voxel_size
    xmax = maximum(p[1] for p in V) + 2*voxel_size
    ymax = maximum(p[2] for p in V) + 2*voxel_size
    zmax = maximum(p[3] for p in V) + 2*voxel_size

    nx = max(3, round(Int, (xmax-xmin)/voxel_size) + 1)
    ny = max(3, round(Int, (ymax-ymin)/voxel_size) + 1)
    nz = max(3, round(Int, (zmax-zmin)/voxel_size) + 1)

    xr = range(xmin, step=voxel_size, length=nx)
    yr = range(ymin, step=voxel_size, length=ny)
    zr = range(zmin, step=voxel_size, length=nz)

    M = Comodo.mesh2bool(F, V, xr, yr, zr)
    radius > 0 || error("Exclusion radius must be positive")
    # Exclude the lesion's circumsphere conservatively. This also excludes
    # its inscribed triangulated surface when it is a coarse icosahedron.
    for I in findall(M)
        i, j, k = Tuple(I)
        d2 = (xr[j] - center[1])^2 + (yr[i] - center[2])^2 +
             (zr[k] - center[3])^2
        if d2 <= (radius + voxel_size)^2
            M[I] = false
        end
    end
    any(M) || error("No vertebral interior voxel remains outside the lesion")

    r_vox = ceil(Int, search_radius / voxel_size)
    offsets = NTuple{3,Int}[]
    for di in -r_vox:r_vox, dj in -r_vox:r_vox, dk in -r_vox:r_vox
        d = voxel_size * sqrt(di^2 + dj^2 + dk^2)
        d <= search_radius + eps(Float64) && push!(offsets, (di,dj,dk))
    end

    ni, nj, nk = size(M)
    best_score = -1
    best = nothing

    for I in findall(M)
        i,j,k = Tuple(I)
        score = 0
        for (di,dj,dk) in offsets
            ii, jj, kk = i+di, j+dj, k+dk
            if 1 <= ii <= ni && 1 <= jj <= nj && 1 <= kk <= nk && M[ii,jj,kk]
                score += 1
            end
        end
        if score > best_score
            best_score = score
            best = (i,j,k)
        end
    end

    i,j,k = best
    return Point{3,Float64}(xr[j], yr[i], zr[k])
end


