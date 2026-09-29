function write_obj_gibbon(path, F, V)
    open(path, "w") do io
        for p in V
            @printf(io, "v %.17g %.17g %.17g\n",
                    Float64(p[1]), Float64(p[2]), Float64(p[3]))
        end
        for f in F
            @printf(io, "f %d %d %d\n", Int(f[1]), Int(f[2]), Int(f[3]))
        end
    end
end

