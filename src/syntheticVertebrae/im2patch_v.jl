function im2patch_v(M, mask)
    # Faithful implementation of im2patch(M,mask,"v") for 3-D images.
    # GIBBON creates six unshared quad faces per selected voxel, then removes
    # all unused corner-grid vertices and renumbers the face matrix.
    ni, nj, nk = size(M)
    nvi, nvj, nvk = ni + 1, nj + 1, nk + 1

    vertex_id(i, j, k) = i + (j - 1)*nvi + (k - 1)*nvi*nvj

    vox = findall(mask)  # MATLAB find(): column-major order
    nvox = length(vox)

    # Hex8 node order from im2patch.m:
    # 1:(I,J,K), 2:(I+1,J,K), 3:(I+1,J+1,K), 4:(I,J+1,K),
    # 5:(I,J,K+1), 6:(I+1,J,K+1), 7:(I+1,J+1,K+1), 8:(I,J+1,K+1)
    hexes = Vector{NTuple{8,Int}}(undef, nvox)
    voxel_colours = Vector{Float64}(undef, nvox)

    for (q, I) in enumerate(vox)
        i, j, k = Tuple(I)
        h = (
            vertex_id(i,   j,   k),
            vertex_id(i+1, j,   k),
            vertex_id(i+1, j+1, k),
            vertex_id(i,   j+1, k),
            vertex_id(i,   j,   k+1),
            vertex_id(i+1, j,   k+1),
            vertex_id(i+1, j+1, k+1),
            vertex_id(i,   j+1, k+1),
        )
        hexes[q] = h
        voxel_colours[q] = Float64(M[I])
    end

    # element2patch(...,'hex8') face sets.  Face orientation does not affect
    # the later BV/TV search, but these are consistently outward for the
    # image-space hexahedron convention above.
    face_nodes = (
        (1, 4, 3, 2),
        (5, 6, 7, 8),
        (1, 2, 6, 5),
        (4, 8, 7, 3),
        (1, 5, 8, 4),
        (2, 3, 7, 6),
    )

    Fglobal = Vector{NTuple{4,Int}}(undef, 6*nvox)
    C = Vector{Float64}(undef, 6*nvox)

    # GIBBON's element2patch groups each local face over all elements; its
    # colour array is correspondingly repmat(C,6,1).
    q = 1
    for lf in face_nodes
        for e in 1:nvox
            h = hexes[e]
            Fglobal[q] = (h[lf[1]], h[lf[2]], h[lf[3]], h[lf[4]])
            C[q] = voxel_colours[e]
            q += 1
        end
    end

    # patchCleanUnused logic used by im2patch.m: ascending global indices.
    used = sort(unique(v for f in Fglobal for v in f))
    remap = Dict{Int,Int}(old => new for (new, old) in enumerate(used))

    F = QuadFace{Int}[
        QuadFace{Int}(remap[f[1]], remap[f[2]], remap[f[3]], remap[f[4]])
        for f in Fglobal
    ]

    V = Vector{Point{3,Float64}}(undef, length(used))
    plane = nvi*nvj
    for (q, id) in enumerate(used)
        k = (id - 1) ÷ plane + 1
        r = id - (k - 1)*plane
        j = (r - 1) ÷ nvi + 1
        i = r - (j - 1)*nvi

        # im2patch.m: Iv=I-0.5; Jv=J-0.5; Kv=K-0.5; V=[Jv Iv Kv]
        V[q] = Point{3,Float64}(j - 0.5, i - 0.5, k - 0.5)
    end

    return F, V, C
end

# =============================================================================
# Helpers: GIBBON surface normals
# =============================================================================

