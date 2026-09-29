function write_numeric_vector(path, x)

    open(path, "w") do io
        for v in x
            if v isa Integer
                println(io, v)
            else
                @printf(io, "%.17g\n", Float64(v))
            end
        end
    end
end

