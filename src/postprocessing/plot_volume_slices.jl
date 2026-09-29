function plot_volume_slices(B, voxel_size; title="")

    # Image storage is Y × X × Z
    A = Float32.(permutedims(B, (2, 1, 3)))

    nx, ny, nz = size(A)

    x = LinRange(
        0.0f0,
        Float32((nx - 1) * voxel_size),
        nx,
    )

    y = LinRange(
        0.0f0,
        Float32((ny - 1) * voxel_size),
        ny,
    )

    z = LinRange(
        0.0f0,
        Float32((nz - 1) * voxel_size),
        nz,
    )

    fig = Figure(
        size=(1200, 900),
        backgroundcolor=:white,
    )

    ax = Axis3(
        fig[1, 1];
        title=title,
        xlabel="X",
        ylabel="Y",
        zlabel="Z",
        aspect=:data,
        viewmode=:free,
        perspectiveness=0.0,
        azimuth=deg2rad(-37.5),
        elevation=deg2rad(30.0),
        limits=(first(x), last(x), first(y), last(y), first(z), last(z)),
    )

    p = volumeslices!(
        ax,
        x,
        y,
        z,
        A;
        colorrange=extrema(A),
    )

    p[:update_yz][](
        round(Int, nx / 2)
    )

    p[:update_xz][](
        round(Int, ny / 2)
    )

    p[:update_xy][](
        round(Int, nz / 2)
    )

    screen = GLMakie.Screen(
        title=isempty(title) ? "VERITAS" : title,
    )

    display(screen, fig)

    push!(FIGURE_SCREENS, screen)

    return fig, ax
end
