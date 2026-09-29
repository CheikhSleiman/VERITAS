function resize_contributions(
    in_length::Int,
    out_length::Int,
    scale::Float64,
)

    kernel_width = 2.0

    if scale < 1.0
        kernel_width /= scale
        h = x -> scale * triangle_kernel(scale * x)
    else
        h = triangle_kernel
    end

    P = ceil(Int, kernel_width) + 2

    weights = zeros(Float64, out_length, P)
    indices = Matrix{Int}(undef, out_length, P)

    # MATLAB symmetric boundary handling
    aux = vcat(
        collect(1:in_length),
        collect(in_length:-1:1),
    )

    naux = length(aux)

    for x in 1:out_length

        # MATLAB inverse pixel mapping
        u = x / scale + 0.5 * (1.0 - 1.0 / scale)

        left = floor(Int, u - kernel_width / 2.0)

        weight_sum = 0.0

        for p in 1:P

            ind = left + p - 1
            w = h(u - ind)

            weights[x, p] = w

            indices[x, p] =
                aux[mod(ind - 1, naux) + 1]

            weight_sum += w
        end

        if weight_sum != 0.0
            @views weights[x, :] ./= weight_sum
        end
    end

    return weights, indices
end

