function homogenise_bvtv(
    E,
    Vm,
    element_material_id,
    Fpatch,
    Vpatch,
    Cpatch;
    radius=3.0,
)
    length(E) == length(element_material_id) ||
        error("Element/material-ID count mismatch")

    length(Fpatch) == length(Cpatch) ||
        error("Patch face/color count mismatch")

    println()
    println("Building homogenisation search structure")
    println("  patch vertices : ", length(Vpatch))
    println("  patch faces    : ", length(Fpatch))
    println("  search radius  : ", radius)

    # MATLAB: gc = mean(reshape(Vm(E',:),4,[],3),1)
    gc = tet_centroids(E, Vm)

    # MATLAB builds a KD tree on patch vertices and then retains faces for
    # which all vertices lie in the radius.  Querying patch-face centroids
    # first is an exact candidate filter: if all vertices of a face are in a
    # Euclidean ball, its centroid is also in that ball.
    fc = face_centroids_matrix(Fpatch, Vpatch)
    tree = KDTree(fc; leafsize=25)

    original_id = Float64.(element_material_id)
    local_mean = copy(original_id)

    found_faces = zeros(Int, length(E))
    radius2 = radius^2

    Threads.@threads for i in eachindex(E)
        # MATLAB preserves cortical marker 2 later. It still performs the
        # search for all elements, but skipping it here cannot change output.
        if original_id[i] == 2.0
            continue
        end

        x = gc[1, i]
        y = gc[2, i]
        z = gc[3, i]

        candidates = inrange(
            tree,
            @view(gc[:, i]),
            radius,
        )

        csum = 0.0
        nfaces = 0

        @inbounds for fi in candidates
            if face_inside_radius(
                Fpatch[fi],
                Vpatch,
                x,
                y,
                z,
                radius2,
            )
                csum += Float64(Cpatch[fi])
                nfaces += 1
            end
        end

        if nfaces > 0
            local_mean[i] = csum / nfaces
            found_faces[i] = nfaces
        end
    end

    # MATLAB:
    # CE = meshOutput.elementMaterialID;
    # ... CE(i) = mean(Csub);
    # if meshOutput.elementMaterialID(i) ~= 2
    #     meshOutput.elementMaterialID(i) = CE(i)-1;
    # end
    bvtv_material_id = copy(original_id)

    Threads.@threads for i in eachindex(bvtv_material_id)
        if original_id[i] != 2.0
            bvtv_material_id[i] = local_mean[i] - 1.0
        end
    end

    return bvtv_material_id, local_mean, found_faces, gc
end

# -----------------------------------------------------------------------------
# Material property fields
# -----------------------------------------------------------------------------

