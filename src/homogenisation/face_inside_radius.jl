function face_inside_radius(f, V, x, y, z, radius2)
    @inbounds for q in f
        p = V[Int(q)]

        dx = p[1] - x
        dy = p[2] - y
        dz = p[3] - z

        if dx*dx + dy*dy + dz*dz > radius2
            return false
        end
    end

    return true
end

