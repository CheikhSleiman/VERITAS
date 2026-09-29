function resize_dimension(
    A::Array{Float64,3},
    out_length::Int,
    dim::Int,
    scale::Float64,
)

    perm = Tuple(
        vcat(
            dim,
            [d for d in 1:3 if d != dim],
        )
    )

    Ap = permutedims(A, perm)

    in_length = size(Ap, 1)

    weights, indices = resize_contributions(
        in_length,
        out_length,
        scale,
    )

    trailing_size = size(Ap)[2:end]

    X = reshape(
        Ap,
        in_length,
        :,
    )

    Y = Matrix{Float64}(
        undef,
        out_length,
        size(X, 2),
    )

    P = size(weights, 2)

    Threads.@threads for i in 1:out_length

        for column in axes(X, 2)

            value = 0.0

            @inbounds for p in 1:P
                value +=
                    weights[i, p] *
                    X[indices[i, p], column]
            end

            Y[i, column] = value
        end
    end

    Bp = reshape(
        Y,
        (out_length, trailing_size...),
    )

    inverse_perm = invperm(collect(perm))

    return permutedims(
        Bp,
        Tuple(inverse_perm),
    )
end

