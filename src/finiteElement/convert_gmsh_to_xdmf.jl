function convert_gmsh_to_xdmf(
    converter_path::AbstractString,
    msh_path::AbstractString;
    tetra_name="Tetra.xdmf",
    triangle_name="Tri.xdmf",
)

    isfile(converter_path) ||
        error("XDMF converter not found: $(converter_path)")

    isfile(msh_path) ||
        error("Gmsh mesh not found: $(msh_path)")

    python = resolve_veritas_python()

	base_cmd = Cmd([
		python,
		abspath(converter_path),
		"--input",
		basename(msh_path),
		"--tetra",
		tetra_name,
		"--triangle",
		triangle_name,
	])

	cmd = Cmd(
		base_cmd;
		dir=dirname(abspath(msh_path)),
	)

    println()
    println("Converting Gmsh -> XDMF/H5")
    println("  Python    : ", python)
    println("  Converter : ", converter_path)

    run(cmd)

    expected = [
        joinpath(dirname(msh_path), tetra_name),
        joinpath(dirname(msh_path), replace(tetra_name, r"\.xdmf$" => ".h5")),
        joinpath(dirname(msh_path), triangle_name),
        joinpath(dirname(msh_path), replace(triangle_name, r"\.xdmf$" => ".h5")),
    ]

    for path in expected
        isfile(path) || error("Expected converter output was not created: $(path)")
    end

    return expected
end

