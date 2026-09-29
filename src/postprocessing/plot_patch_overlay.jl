function plot_patch_overlay(
    F,
    V,
    C,
    Fsurf,
    Vsurf;
    facealpha=0.8,
    surfacealpha=0.5,
    title="",
    colorrange=nothing,
)

    fig = Figure(
        size=(1100, 850),
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

    if colorrange === nothing
        colorrange = extrema(C)
    end

    # -------------------------------------------------------------------------
    # Coloured voxel faces
    # -------------------------------------------------------------------------

    face_colors = GeometryBasics.FaceView(
        Float32.(C),
        [
            typeof(F[i])(
                ntuple(_ -> i, length(F[i]))...
            )
            for i in eachindex(F)
        ],
    )

    patch_mesh = GeometryBasics.mesh(
        V,
        F;
        color=face_colors,
    )

    hp = mesh!(
        ax,
        patch_mesh;
        colormap=:viridis,
        colorrange=colorrange,
        alpha=facealpha,
        transparency=facealpha < 1.0,
        shading=NoShading,
        interpolate=false,
        fxaa=true,
    )

    # -------------------------------------------------------------------------
    # Vertebral surface
    # -------------------------------------------------------------------------

    surface_mesh = GeometryBasics.Mesh(
        Vsurf,
        Fsurf,
    )

    poly!(
        ax,
        surface_mesh;
        color=(:white, surfacealpha),
        strokecolor=(:black, 0.65),
        strokewidth=0.5,
        stroke_depth_shift=-0.003f0,
        transparency=surfacealpha < 1.0,
        shading=false,
        fxaa=true,
    )

    # -------------------------------------------------------------------------
    # Geometry axes
    # -------------------------------------------------------------------------

    axis_geom!(ax)

    # -------------------------------------------------------------------------
    # Colour bar
    # -------------------------------------------------------------------------

    Colorbar(
        fig[1, 2],
        hp;
        label="Voxel value",
    )

    # -------------------------------------------------------------------------
    # Window
    # -------------------------------------------------------------------------

    screen = GLMakie.Screen(
        title=isempty(title) ? "VERITAS" : title,
    )

    display(screen, fig)

    push!(
        FIGURE_SCREENS,
        screen,
    )

    return fig, ax
end
