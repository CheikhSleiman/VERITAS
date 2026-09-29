function dual_lattice_gibbon(E, V, shrink_factor; clad_opt=0)

    clad_opt == 0 || error("This VERITAS port currently implements GIBBON dualLattice for cladOpt=0 only.")
    isempty(E) && return TriangleFace{Int}[], copy(V), Int[]

    # GIBBON patchDetach(E,V,shrinkFactor): detach each tetrahedron and
    # scale its vertices about the element centre.
    nE = length(E)
    Vc = Point{3,Float64}[]
    sizehint!(Vc, 4 * nE)

    detached = Vector{NTuple{4,Int}}(undef, nE)

    for (ie, e) in enumerate(E)
        ids = ntuple(j -> Int(e[j]), 4)
        c = Point{3,Float64}(
            mean(V[i][1] for i in ids),
            mean(V[i][2] for i in ids),
            mean(V[i][3] for i in ids),
        )

        new_ids = ntuple(j -> begin
            p = V[ids[j]]
            push!(Vc, Point{3,Float64}(
                c[1] + shrink_factor * (p[1] - c[1]),
                c[2] + shrink_factor * (p[2] - c[2]),
                c[3] + shrink_factor * (p[3] - c[3]),
            ))
            length(Vc)
        end, 4)

        detached[ie] = new_ids
    end

    # element2patch for Tet4.  The original GIBBON routine subsequently
    # reorders each face so corresponding vertices on neighbouring elements
    # match.  We do that explicitly using the sorted global face key.
    local_faces = (
        (1, 2, 3),
        (1, 4, 2),
        (2, 4, 3),
        (3, 4, 1),
    )

    occurrences = Dict{NTuple{3,Int}, Vector{NTuple{3,Int}}}()

    for (ie, e) in enumerate(E)
        global_ids = ntuple(j -> Int(e[j]), 4)
        local_ids = detached[ie]

        for lf in local_faces
            g = (global_ids[lf[1]], global_ids[lf[2]], global_ids[lf[3]])
            key = Tuple(sort(collect(g)))

            aligned = ntuple(k -> begin
                target = key[k]
                pos = findfirst(==(target), global_ids)
                local_ids[pos]
            end, 3)

            push!(get!(occurrences, key, NTuple{3,Int}[]), aligned)
        end
    end

    VT = copy(Vc)
    FT = TriangleFace{Int}[]
    CT = Int[]

    # GIBBON converts every paired triangular face set to three quads and
    # triangulates each quad.  Boundary faces also receive a cap (CT=2).
    for (key, occs) in occurrences
        length(occs) in (1, 2) || error("Non-manifold tetrahedral face encountered in dualLattice port.")

        A = occs[1]
        B = if length(occs) == 2
            occs[2]
        else
            pts = (V[key[1]], V[key[2]], V[key[3]])
            fc = Point{3,Float64}(
                (pts[1][1] + pts[2][1] + pts[3][1]) / 3,
                (pts[1][2] + pts[2][2] + pts[3][2]) / 3,
                (pts[1][3] + pts[2][3] + pts[3][3]) / 3,
            )

            b = ntuple(j -> begin
                p = pts[j]
                push!(VT, Point{3,Float64}(
                    fc[1] + shrink_factor * (p[1] - fc[1]),
                    fc[2] + shrink_factor * (p[2] - fc[2]),
                    fc[3] + shrink_factor * (p[3] - fc[3]),
                ))
                length(VT)
            end, 3)
            b
        end

        for (j, k) in ((1, 2), (2, 3), (3, 1))
            q1, q2, q3, q4 = A[j], A[k], B[k], B[j]
            push!(FT, TriangleFace{Int}(q1, q2, q3))
            push!(FT, TriangleFace{Int}(q3, q4, q1))
            push!(CT, 1, 1)
        end

        if length(occs) == 1
            push!(FT, TriangleFace{Int}(B[3], B[2], B[1]))
            push!(CT, 2)
        end
    end

    return FT, VT, CT
end

# =============================================================================
# Helpers: Resize and voxel patch
# =============================================================================

triangle_kernel(x) = max(1.0 - abs(x), 0.0)

