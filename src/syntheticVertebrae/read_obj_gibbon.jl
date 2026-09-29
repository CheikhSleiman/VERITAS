function read_obj_gibbon(path)
    V = Point{3,Float64}[]
    F = TriangleFace{Int}[]

    for line in eachline(path)
        line = strip(line)
        isempty(line) && continue
        startswith(line, "#") && continue

        if startswith(line, "v ")
            a = split(line)
            length(a) >= 4 || continue
            push!(V, Point{3,Float64}(
                parse(Float64, a[2]),
                parse(Float64, a[3]),
                parse(Float64, a[4]),
            ))
        elseif startswith(line, "f ")
            a = split(line)[2:end]
            ids = Int[]
            for token in a
                firstfield = split(token, '/')[1]
                idx = parse(Int, firstfield)
                idx < 0 && (idx = length(V) + idx + 1)
                push!(ids, idx)
            end
            length(ids) >= 3 || continue
            for j in 2:(length(ids)-1)
                push!(F, TriangleFace{Int}(ids[1], ids[j], ids[j+1]))
            end
        end
    end

    isempty(V) && error("Vorpalite OBJ contains no vertices: $path")
    isempty(F) && error("Vorpalite OBJ contains no faces: $path")

    return F, V
end

"""
    ggremesh_gibbon(F, V; nb_pts=length(V), anisotropy=0,
                    pre_max_hole_area=100, pre_max_hole_edges=0,
                    post_max_hole_area=100, post_max_hole_edges=0,
                    gradation=0.0, disp_on=false)

Direct Julia reproduction of GIBBON `ggremesh.m`: export OBJ, call Vorpalite
with GIBBON's default options, then import the resulting OBJ.
"""
