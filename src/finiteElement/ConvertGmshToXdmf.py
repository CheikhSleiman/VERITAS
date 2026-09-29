"""Convert a Gmsh mesh into separate tetrahedral and boundary XDMF meshes."""

import argparse
from pathlib import Path

import meshio


def extract_cells(mesh, cell_type):
    cells = mesh.get_cells_type(cell_type)
    if len(cells) == 0:
        raise ValueError(f"Input mesh has no {cell_type} cells")
    tags = mesh.get_cell_data("gmsh:physical", cell_type)
    return meshio.Mesh(
        points=mesh.points,
        cells=[(cell_type, cells)],
        cell_data={"name_to_read": [tags]},
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--tetra", required=True)
    parser.add_argument("--triangle", required=True)
    args = parser.parse_args()

    mesh = meshio.read(args.input)
    meshio.write(args.tetra, extract_cells(mesh, "tetra"))
    meshio.write(args.triangle, extract_cells(mesh, "triangle"))
    for path in (args.tetra, args.triangle):
        if not Path(path).is_file():
            raise RuntimeError(f"Missing converter output: {path}")


if __name__ == "__main__":
    main()
