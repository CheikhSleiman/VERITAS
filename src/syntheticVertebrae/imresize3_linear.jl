function imresize3_linear(
    A,
    scale::Float64,
)

    input_size = size(A)

    output_size = ntuple(
        d -> ceil(Int, scale * input_size[d]),
        3,
    )

    B = Float64.(A)

    B = resize_dimension(
        B,
        output_size[1],
        1,
        scale,
    )

    B = resize_dimension(
        B,
        output_size[2],
        2,
        scale,
    )

    B = resize_dimension(
        B,
        output_size[3],
        3,
        scale,
    )

    return B
end

