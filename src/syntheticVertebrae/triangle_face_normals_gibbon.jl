function triangle_face_normals_gibbon(F, V)
    N = Vector{Point{3,Float64}}(undef, length(F))
    for (i,f) in enumerate(F)
        p1, p2, p3 = V[Int(f[1])], V[Int(f[2])], V[Int(f[3])]
        # For triangles this is equivalent in direction to GIBBON's
        # patchEdgeCrossProduct followed by vecnormalize.
        n = cross(p2-p1, p3-p1)
        d = norm(n)
        d > 0 || error("Degenerate triangle encountered in patchNormal equivalent")
        N[i] = Point{3,Float64}(n[1]/d, n[2]/d, n[3]/d)
    end
    return N
end

# =============================================================================
# Helpers: GIBBON patchThick
# =============================================================================

