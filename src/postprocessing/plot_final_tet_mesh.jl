function plot_final_tet_mesh(
    E,
    V,
    CE,
    Fb,
    Cb;
    title="Final multidomain tetrahedral mesh",
    cut_axis=:x,
    cut_fraction=0.50,
)
    # Categorical colours: discrete labels, no colour bar.
    surface_palette = [
        :dodgerblue,
        :limegreen,
        :red,
        :orange,
        :mediumpurple,
        :cyan4,
        :gold,
        :deeppink,
    ]

    material_palette = [
        :cornflowerblue,
        :tomato,
        :mediumseagreen,
        :goldenrod,
        :mediumpurple,
        :deepskyblue3,
        :orchid,
        :sienna,
    ]

    boundary_labels = sort(unique(Int.(Cb)))
    material_labels = sort(unique(Int.(CE)))

    println()
    println("Volumetric mesh plot")
    println("  boundary labels : ", boundary_labels)
    println("  material labels : ", material_labels)
    for label in material_labels
        println("    material ", label, " tetrahedra : ", count(==(label), Int.(CE)))
    end

    boundary_color = Dict(
        label => surface_palette[mod1(i, length(surface_palette))]
        for (i, label) in enumerate(boundary_labels)
    )

    material_color = Dict(
        label => material_palette[mod1(i, length(material_palette))]
        for (i, label) in enumerate(material_labels)
    )

    fig = Figure(
        size=(1650, 820),
        backgroundcolor=:white,
    )

    # -------------------------------------------------------------------------
    # Left: preserve the labelled boundary surface
    # -------------------------------------------------------------------------
    ax1 = Comodo.AxisGeom(
        fig[1, 1];
        title="Input boundary labels",
    )
    ax1.viewmode = :free

    legend_elements = PolyElement[]
    legend_names = String[]

    for label in boundary_labels
        logic = Int.(Cb) .== label
        any(logic) || continue

        poly!(
            ax1,
            GeometryBasics.Mesh(V, Fb[logic]);
            color=boundary_color[label],
            strokecolor=:black,
            strokewidth=0.5,
            stroke_depth_shift=-0.003f0,
            shading=false,
            fxaa=true,
        )

        push!(
            legend_elements,
            PolyElement(
                color=boundary_color[label],
                strokecolor=:black,
                strokewidth=1,
            ),
        )
        push!(legend_names, "Boundary $(label)")
    end

    # -------------------------------------------------------------------------
    # Right: true multidomain tetrahedral cutaway
    # Each material is cut and surfaced independently. This avoids losing
    # nested/internal domains and guarantees that CE controls the colours.
    # -------------------------------------------------------------------------
    ax2 = Comodo.AxisGeom(
        fig[1, 2];
        title="Tetrahedral domains",
    )
    ax2.viewmode = :free

    axis_index =
        cut_axis === :x ? 1 :
        cut_axis === :y ? 2 :
        cut_axis === :z ? 3 :
        error("cut_axis must be :x, :y, or :z")

    centres_all = Comodo.simplexcenter(E, V)
    coords_all = Float64[p[axis_index] for p in centres_all]
    cut_position = quantile(coords_all, cut_fraction)

    # Very light complete outer mesh for spatial context.
    poly!(
        ax2,
        GeometryBasics.Mesh(V, Fb);
        color=(:gray85, 0.05),
        strokecolor=(:black, 0.08),
        strokewidth=0.12,
        shading=false,
        transparency=true,
        fxaa=true,
    )

    CE_int = Int.(CE)

    for label in material_labels
        idx_label = findall(==(label), CE_int)
        isempty(idx_label) && continue

        E_label = E[idx_label]
        centres_label = centres_all[idx_label]
        coords_label = Float64[p[axis_index] for p in centres_label]

        keep_local = coords_label .<= cut_position
        E_visible = E_label[keep_local]

        if isempty(E_visible)
            @warn "Material is outside the selected cut half" label cut_axis cut_fraction
            continue
        end

        # Boundary of this material after the cut. This includes the newly
        # exposed cut plane and material interfaces, not just the exterior.
        F_visible = Comodo.boundaryfaces(E_visible)

        poly!(
            ax2,
            GeometryBasics.Mesh(V, F_visible);
            color=material_color[label],
            strokecolor=:black,
            strokewidth=0.5,
            stroke_depth_shift=-0.003f0,
            shading=false,
            fxaa=true,
        )

        push!(
            legend_elements,
            PolyElement(
                color=material_color[label],
                strokecolor=:black,
                strokewidth=1,
            ),
        )
        push!(legend_names, "Material $(label)")
    end

    # One categorical legend; no colour bar.
    Legend(
        fig[1, 3],
        legend_elements,
        legend_names;
        title="Labels",
        framevisible=false,
        patchsize=(28, 18),
        rowgap=8,
    )

    Label(
        fig[0, 1:3],
        title;
        fontsize=20,
    )

    screen = GLMakie.Screen(title=title)
    display(screen, fig)
    push!(FIGURE_SCREENS, screen)

    return fig, ax1, ax2
end

# -----------------------------------------------------------------------------
# GIBBON subTet, splitMethod = 2
# -----------------------------------------------------------------------------

