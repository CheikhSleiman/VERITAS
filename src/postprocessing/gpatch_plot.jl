function gpatch_plot(
    F,
    V;
    facecolor=:white,
    edgecolor=:black,
    facealpha=1.0,
    edgealpha=1.0,
    linewidth=0.5,
    title="",
)

    fig = Figure(
        size=(1200, 900),
        fontsize=15,
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

        backgroundcolor=:white,

        xautolimitmargin=(0.02, 0.02),
        yautolimitmargin=(0.02, 0.02),
        zautolimitmargin=(0.02, 0.02),

        xypanelvisible=false,
        xzpanelvisible=false,
        yzpanelvisible=false,

        xgridvisible=true,
        ygridvisible=true,
        zgridvisible=true,

        xgridcolor=(:black, 0.10),
        ygridcolor=(:black, 0.10),
        zgridcolor=(:black, 0.10),

        xgridwidth=0.6,
        ygridwidth=0.6,
        zgridwidth=0.6,

        xticklabelsize=12,
        yticklabelsize=12,
        zticklabelsize=12,

        xlabelsize=14,
        ylabelsize=14,
        zlabelsize=14,
    )

    M = GeometryBasics.Mesh(V, F)

    poly!(
        ax,
        M;
        color=(facecolor, facealpha),
        strokecolor=(edgecolor, edgealpha),
        strokewidth=linewidth,
        stroke_depth_shift=-0.003f0,
        shading=false,
        transparency=facealpha < 1.0,
        fxaa=true,
    )

    axis_geom!(ax)

    screen = GLMakie.Screen(
        title=isempty(title) ? "VERITAS" : title,
    )

    display(screen, fig)

    push!(FIGURE_SCREENS, screen)

    return fig, ax
end
