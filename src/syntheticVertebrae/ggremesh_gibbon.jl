function ggremesh_gibbon(
    F,
    V;
    nb_pts::Integer=length(V),
    anisotropy::Real=0,
    pre_max_hole_area::Real=100,
    pre_max_hole_edges::Integer=0,
    post_max_hole_area::Real=100,
    post_max_hole_edges::Integer=0,
    gradation::Real=0.0,
    disp_on::Bool=false,
)
    vorpalite = resolve_vorpalite()

    return mktempdir() do tmp
        input_file = joinpath(tmp, "temp.obj")
        output_file = joinpath(tmp, "temp_out.obj")

        write_obj_gibbon(input_file, F, V)

        # Same option structure/defaults used by GIBBON ggremesh.m.
        args = String[
            vorpalite,
            input_file,
            output_file,
            "nb_pts=$(Int(nb_pts))",
            "anisotropy=$(Float64(anisotropy))",
            "pre:max_hole_area=$(Float64(pre_max_hole_area))",
            "pre:max_hole_edges=$(Int(pre_max_hole_edges))",
            "post:max_hole_area=$(Float64(post_max_hole_area))",
            "post:max_hole_edges=$(Int(post_max_hole_edges))",
            "remesh:gradation=$(Float64(gradation))",
        ]

        cmd = Cmd(args)

        if disp_on
            run(cmd)
        else
            run(pipeline(cmd, stdout=devnull, stderr=devnull))
        end

        isfile(output_file) || error("Vorpalite did not create $output_file")
        return read_obj_gibbon(output_file)
    end
end

# =============================================================================
# Helpers: Mesh and image utilities
# =============================================================================

