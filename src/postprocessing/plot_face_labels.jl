function plot_face_labels(
    F,
    V,
    C;
    title="Surface labels",
    alpha=1.0,
)

    fig = Figure(
        size=(1000, 850),
        backgroundcolor=:white,
    )

    # Use Comodo's actual AxisGeom
    ax = Comodo.AxisGeom(
        fig[1, 1];
        title=title,
    )
    ax.viewmode = :free

    colour_range = (
        minimum(Float64.(C)),
        maximum(Float64.(C)),
    )

    if colour_range[1] == colour_range[2]
        colour_range = (
            colour_range[1],
            colour_range[1] + 1.0,
        )
    end

    for c in sort(unique(C))

        logic = C .== c

        any(logic) || continue

        poly!(
            ax,
            GeometryBasics.Mesh(
                V,
                F[logic],
            );
            color=Float64(c),
            colormap=:jet,
            colorrange=colour_range,
            strokecolor=:black,
            strokewidth=0.5,
            stroke_depth_shift=-0.003f0,
            shading=false,
            transparency=alpha < 1.0,
            alpha=alpha,
            fxaa=true,
        )
    end

    Colorbar(
        fig[1, 2];
        limits=colour_range,
        colormap=:jet,
        label="Surface label",
    )

    screen = GLMakie.Screen(
        title=title,
    )

    display(screen, fig)

    push!(
        FIGURE_SCREENS,
        screen,
    )

    return fig, ax
end

