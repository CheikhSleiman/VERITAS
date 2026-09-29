function plot_subtet_refinement(E, V; title="Cortical subTet refinement")
    Fb = Comodo.boundaryfaces(E)

    fig = Figure(size=(1000,850), backgroundcolor=:white)
    ax = Comodo.AxisGeom(fig[1,1]; title=title)
    ax.viewmode = :free

    poly!(
        ax,
        GeometryBasics.Mesh(V, Fb);
        color=(:green, 0.71),
        strokecolor=:black,
        strokewidth=0.5,
        stroke_depth_shift=-0.003f0,
        shading=false,
        transparency=true,
        fxaa=true,
    )

    screen = GLMakie.Screen(title=title)
    display(screen, fig)
    push!(FIGURE_SCREENS, screen)
    return fig, ax
end

