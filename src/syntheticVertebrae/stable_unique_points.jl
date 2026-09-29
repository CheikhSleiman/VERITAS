function stable_unique_points(V)
    seen = Dict{NTuple{3,Float64},Int}()
    out = Point{3,Float64}[]
    for p in V
        key = (Float64(p[1]), Float64(p[2]), Float64(p[3]))
        if !haskey(seen, key)
            push!(out, Point{3,Float64}(key))
            seen[key] = length(out)
        end
    end
    return out
end

