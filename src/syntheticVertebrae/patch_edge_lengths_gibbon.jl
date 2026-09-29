function patch_edge_lengths_gibbon(F, V)
    d = Float64[]
    sizehint!(d, 3 * length(F))
    for f in F
        a, b, c = Int(f[1]), Int(f[2]), Int(f[3])
        push!(d, norm(V[a] - V[b]))
        push!(d, norm(V[b] - V[c]))
        push!(d, norm(V[c] - V[a]))
    end
    return d
end

# MATLAB round() rounds positive half-integers away from zero.  Coordinates
# are positive after the origin shift in triSurf2Im.
matlab_round_positive(x::Real) = floor(Int, Float64(x) + 0.5)

