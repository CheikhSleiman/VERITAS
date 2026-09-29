function plot_cortical_surfaces(
    Fq1,
    Vq1,
    Fq2,
    Vq2;
    title="Cortical shell",
)

    fig = Figure(
        size=(1000, 850),
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
    )

    M1 = GeometryBasics.Mesh(
        Vq1,
        Fq1,
    )

    M2 = GeometryBasics.Mesh(
        Vq2,
        Fq2,
    )

    poly!(
        ax,
        M1;
        color=:blue,
        strokecolor=:black,
        strokewidth=0.5,
        stroke_depth_shift=-0.003f0,
        shading=false,
        fxaa=true,
    )

    poly!(
        ax,
        M2;
        color=(:red, 0.20),
        strokecolor=(:black, 0.55),
        strokewidth=0.5,
        stroke_depth_shift=-0.003f0,
        transparency=true,
        shading=false,
        fxaa=true,
    )

    axis_geom!(ax)

    screen = GLMakie.Screen(
        title=title,
    )

    display(screen, fig)

    push!(FIGURE_SCREENS, screen)

    return fig, ax
end
