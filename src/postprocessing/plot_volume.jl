function plot_volume(B, xr, yr, zr; title="")

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
    )

    # Image storage is Y × X × Z; Makie voxels expects X × Y × Z.
    # Use voxel IDs 0 (empty) and 1 (occupied) to display the binary
    # segmentation directly, without ray-marching a narrow isovalue band.
    A = UInt8.(permutedims(B .!= 0, (2, 1, 3)))

    dx = length(xr) > 1 ? xr[2] - xr[1] : 1.0
    dy = length(yr) > 1 ? yr[2] - yr[1] : 1.0
    dz = length(zr) > 1 ? zr[2] - zr[1] : 1.0

    voxels!(
        ax,
        (first(xr) - dx / 2, last(xr) + dx / 2),
        (first(yr) - dy / 2, last(yr) + dy / 2),
        (first(zr) - dz / 2, last(zr) + dz / 2),
        A;
        color=[:gray80],
        gap=0.0,
    )

    screen = GLMakie.Screen(
        title=isempty(title) ? "VERITAS" : title,
    )

    display(screen, fig)
    push!(FIGURE_SCREENS, screen)

    return fig, ax
end
