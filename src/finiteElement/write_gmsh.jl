using Printf

"""
    write_gmsh(file_name, E, V, CE, Fb, Cb)

Julia translation of the MATLAB/GIBBON `writeGmsh.m`.

Inputs
------
file_name : output Gmsh .msh file

E   : tetrahedral elements
V   : mesh vertices
CE  : tetrahedral material/region IDs
Fb  : boundary triangular faces
Cb  : boundary surface markers

Writes Gmsh Version 2.2 ASCII format.
"""
function write_gmsh(
    file_name::AbstractString,
    E,
    V,
    CE,
    Fb,
    Cb,
)

    # ========================================================
    # Equivalent to:
    #
    # triangleMat = [facesBoundary boundaryMarker];
    # triangleMatSort = sortrows(triangleMat,4);
    # ========================================================

    surface_order = sortperm(Cb)

    Fb_sorted = Fb[surface_order]
    Cb_sorted = Cb[surface_order]


    # ========================================================
    # Equivalent to:
    #
    # tetMat = [elements elementMaterialID];
    # tetMat = sortrows(tetMat,5);
    # ========================================================

    volume_order = sortperm(CE)

    E_sorted  = E[volume_order]
    CE_sorted = CE[volume_order]


    # ========================================================
    # Basic checks
    # ========================================================

    length(Fb) == length(Cb) ||
        error("Cb must contain one marker per boundary face.")

    length(E) == length(CE) ||
        error("CE must contain one material ID per tetrahedron.")


    # ========================================================
    # Open output file
    # ========================================================

    open(file_name, "w") do io

        # ====================================================
        # Mesh format
        #
        # MATLAB:
        # $MeshFormat
        # 2.2 0 8
        # $EndMeshFormat
        # ====================================================

        println(io, "\$MeshFormat")
        println(io, "2.2 0 8")
        println(io, "\$EndMeshFormat")


        # ====================================================
        # Physical names
        # ====================================================

        println(io)
        println(io, "\$PhysicalNames")

        labelled_vols  = maximum(Int.(CE))
        labelled_surfs = maximum(Int.(Cb))

        println(
            io,
            labelled_vols + labelled_surfs,
        )


        # ----------------------------------------------------
        # Surface physical names
        #
        # MATLAB:
        #
        # for i=1:max(boundaryMarker)
        #     fprintf(fid,'%d %d "%d"\n',2,i,i);
        # end
        #
        # Dimension 2 = surface
        # ----------------------------------------------------

        for i in 1:labelled_surfs

            println(
                io,
                "2 ",
                i,
                " \"",
                i,
                "\"",
            )

        end


        # ----------------------------------------------------
        # Volume physical names
        #
        # Dimension 3 = volume
        # ----------------------------------------------------

        for i in 1:labelled_vols

            println(
                io,
                "3 ",
                i,
                " \"",
                i,
                "\"",
            )

        end

        println(io, "\$EndPhysicalNames")


        # ====================================================
        # Nodes
        # ====================================================

        println(io, "\$Nodes")
        println(io, length(V))

        for (i, v) in enumerate(V)

            @printf(
                io,
                "%d %.16f %.16f %.16f\n",
                i,
                Float64(v[1]),
                Float64(v[2]),
                Float64(v[3]),
            )

        end

        println(io, "\$EndNodes")


        # ====================================================
        # Elements
        # ====================================================

        println(io, "\$Elements")

        n_surface = length(Fb_sorted)
        n_volume  = length(E_sorted)

        println(
            io,
            n_surface + n_volume,
        )


        # ====================================================
        # Boundary triangles
        #
        # Gmsh element type:
        # 2 = 3-node triangle
        #
        # Two tags:
        # physical entity
        # geometrical entity
        #
        # Both are set to boundary marker, exactly like MATLAB.
        # ====================================================

        for i in eachindex(Fb_sorted)

            f = Fb_sorted[i]

            marker = Int(Cb_sorted[i])

            println(
                io,
                i, " ",
                2, " ",
                2, " ",
                marker, " ",
                marker, " ",
                Int(f[1]), " ",
                Int(f[2]), " ",
                Int(f[3]),
            )

        end


        # ====================================================
        # Tetrahedra
        #
        # Gmsh element type:
        # 4 = 4-node tetrahedron
        #
        # Again physical + geometrical entity both use CE.
        # ====================================================

        for i in eachindex(E_sorted)

            e = E_sorted[i]

            region = Int(CE_sorted[i])

            element_id = n_surface + i

            println(
                io,
                element_id, " ",
                4, " ",
                2, " ",
                region, " ",
                region, " ",
                Int(e[1]), " ",
                Int(e[2]), " ",
                Int(e[3]), " ",
                Int(e[4]),
            )

        end

        println(io, "\$EndElements")

    end


    # ========================================================
    # Same role as MATLAB GmshStatus
    # ========================================================

    println()
    println("Gmsh Version 2 ASCII written correctly")
    println("File: ", abspath(file_name))

    return true
end