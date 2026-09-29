"""Run the Mazars multi-loading analysis for a VERITAS case study."""

import argparse
from mpi4py import MPI
import numpy as np
from pathlib import Path
from petsc4py import PETSc
import ufl
from dolfinx import fem, io, mesh as dmesh
from dolfinx.fem import Function
from dolfinx.fem import petsc as fem_petsc
from dolfinx_materials.mfront import MFrontMaterial
from dolfinx_materials.quadrature_map import QuadratureMap
from dolfinx_materials.solvers import NonlinearMaterialProblem
from dolfinx_materials.utils import symmetric_gradient  # Mandel convention
import basix.ufl


# ------------------------------------------------------------------
# MPI
# ------------------------------------------------------------------
comm = MPI.COMM_WORLD
rank = comm.rank
size = comm.size

# ------------------------------------------------------------------
# Case-study inputs and outputs (independent of the working directory)
# ------------------------------------------------------------------
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "--case-dir", type=Path, required=True,
    help="Case study directory containing mesh/ and data/",
)
parser.add_argument(
    "--behaviour-lib", type=Path,
    help="Compiled Mazars library (default: beside this script)",
)
parser.add_argument(
    "--output-dir", type=Path,
    help="Result directory (default: CASE_DIR/output/fenicsx)",
)
args = parser.parse_args()

case_root = args.case_dir.expanduser().resolve()
mesh_dir = case_root / "mesh"
data_dir = case_root / "data"
output_dir = (
    args.output_dir.expanduser().resolve()
    if args.output_dir is not None else case_root / "output" / "fenicsx"
)
behaviour_lib = (
    args.behaviour_lib.expanduser().resolve()
    if args.behaviour_lib is not None
    else Path(__file__).resolve().parent / "libBehaviour.so"
)

tetra_xdmf = mesh_dir / "Tetra.xdmf"
tri_xdmf = mesh_dir / "Tri.xdmf"
lfe_file = data_dir / "lfe.txt"
element_material_ID_file = data_dir / "element_material_ID.txt"
young_file = data_dir / "YoungModulus.txt"
tensile_file = data_dir / "TensileStrength.txt"
gf_file = data_dir / "FractureEnergy.txt"

required_inputs = (
    tetra_xdmf, tri_xdmf, lfe_file, element_material_ID_file,
    young_file, tensile_file, gf_file, behaviour_lib,
)
missing = [str(path) for path in required_inputs if not path.is_file()]
if missing:
    raise FileNotFoundError("Missing VERITAS inputs:\n  " + "\n  ".join(missing))

if rank == 0:
    (output_dir / "fields").mkdir(parents=True, exist_ok=True)
comm.barrier()


# ------------------------------------------------------------------
# Read mesh + meshtags (XDMF)
# ------------------------------------------------------------------

with io.XDMFFile(comm, str(tetra_xdmf), "r") as xdmf:
    domain = xdmf.read_mesh(name="Grid")
    # create entities/connectivity needed for facet tags
    tdim = domain.topology.dim
    fdim = tdim - 1
    domain.topology.create_entities(fdim)
    domain.topology.create_connectivity(fdim, tdim)

    vol_tags = xdmf.read_meshtags(domain, name="Grid", attribute_name="name_to_read")

with io.XDMFFile(comm, str(tri_xdmf), "r") as xdmf:
    surf_tags = xdmf.read_meshtags(domain, name="Grid", attribute_name="name_to_read")

if rank == 0:
    print("tdim:", domain.topology.dim)
    print("vol_tags.dim:", vol_tags.dim)
    print("surf_tags.dim:", surf_tags.dim)


dx = ufl.Measure("dx", domain=domain, subdomain_data=vol_tags)
ds = ufl.Measure("ds", domain=domain, subdomain_data=surf_tags)

# ------------------------------------------------------------------
# Element-wise material fields DG0 from txt files
# ------------------------------------------------------------------
V0 = fem.functionspace(domain, ("DG", 0))

lfe = fem.Function(V0, name="lfe")
EMID = fem.Function(V0, name="EMID")
E = fem.Function(V0, name="Young")
ft = fem.Function(V0, name="TensileStrength")
Gf = fem.Function(V0, name="FractureEnergy")

# -------------------------------------------------------------------
# Load fields
# -------------------------------------------------------------------
if rank == 0:
    lfe_values = np.loadtxt(lfe_file, dtype=np.float64)
    EMID_values = np.loadtxt(element_material_ID_file, dtype=np.float64)
    E_values = np.loadtxt(young_file, dtype=np.float64)
    ft_values = np.loadtxt(tensile_file, dtype=np.float64)
    Gf_values = np.loadtxt(gf_file, dtype=np.float64)
else:
    lfe_values = None
    EMID_values = None
    E_values = None
    ft_values = None
    Gf_values = None

lfe_values = domain.comm.bcast(lfe_values, root=0)
EMID_values = domain.comm.bcast(EMID_values, root=0)
E_values = domain.comm.bcast(E_values, root=0)
ft_values = domain.comm.bcast(ft_values, root=0)
Gf_values = domain.comm.bcast(Gf_values, root=0)

# -------------------------------------------------------------------
# Mesh cell information
# -------------------------------------------------------------------
cell_imap = domain.topology.index_map(tdim)

n_global_cells = cell_imap.size_global
n_local_cells  = cell_imap.size_local
n_ghost_cells  = cell_imap.num_ghosts

if len(lfe_values) != n_global_cells:
    raise RuntimeError(
        f"Mismatch: lfe file has {len(lfe_values)} values, "
        f"mesh has {n_global_cells} cells globally."
    )

if len(EMID_values) != n_global_cells:
    raise RuntimeError(
        f"Mismatch: EMID file has {len(EMID_values)} values, "
        f"mesh has {n_global_cells} cells globally."
    )

if len(E_values) != n_global_cells:
    raise RuntimeError(
        f"Mismatch: YoungModulus file has {len(E_values)} values, "
        f"mesh has {n_global_cells} cells globally."
    )

if len(ft_values) != n_global_cells:
    raise RuntimeError(
        f"Mismatch: TensileStrength file has {len(ft_values)} values, "
        f"mesh has {n_global_cells} cells globally."
    )

if len(Gf_values) != n_global_cells:
    raise RuntimeError(
        f"Mismatch: FractureEnergy file has {len(Gf_values)} values, "
        f"mesh has {n_global_cells} cells globally."
    )

# -------------------------------------------------------------------
# Local cells: owned + ghosts
# -------------------------------------------------------------------
local_cells = np.arange(n_local_cells + n_ghost_cells, dtype=np.int32)

# IMPORTANT:
# These are the original cell indices from the mesh file ordering.
# This is what you want if lfe_values, EMID_values, E_values,
# ft_values, and Gf_values are stored one value per original mesh cell.
global_cells = domain.topology.original_cell_index[:n_local_cells + n_ghost_cells]

# -------------------------------------------------------------------
# Assign cell-wise values to DG0 functions
# -------------------------------------------------------------------
for c_local, c_global in zip(local_cells, global_cells):
    dof = V0.dofmap.cell_dofs(int(c_local))[0]

    lfe.x.array[dof] = float(lfe_values[int(c_global)])
    EMID.x.array[dof] = float(EMID_values[int(c_global)])
    E.x.array[dof] = float(E_values[int(c_global)])
    ft.x.array[dof] = float(ft_values[int(c_global)])
    Gf.x.array[dof] = float(Gf_values[int(c_global)])

# Synchronise ghost values
lfe.x.scatter_forward()
EMID.x.scatter_forward()
E.x.scatter_forward()
ft.x.scatter_forward()
Gf.x.scatter_forward()


# Mechanical properties
Bt = fem.Function(V0, name="Bt")
Bt_expr = E / ft + ((E / ft) * lfe) / (0.8 * Gf * E / ft**2 - lfe)
Bt.interpolate(fem.Expression(Bt_expr, V0.element.interpolation_points))
Bt.x.scatter_forward()


ed0 = fem.Function(V0, name="ed0")
ed0.x.array[:] = ft.x.array / E.x.array
ed0.x.scatter_forward()

if rank == 0:
    print("ed0 local range:", ed0.x.array.min(), ed0.x.array.max())

# -------------------------------------------------------------------
# Export material fields
# -------------------------------------------------------------------
with io.XDMFFile(domain.comm, str(output_dir / "fields" / "lfe_field.xdmf"), "w") as xdmf:
    xdmf.write_mesh(domain)
    xdmf.write_function(lfe, 0.0)

with io.XDMFFile(domain.comm, str(output_dir / "fields" / "EMID_field.xdmf"), "w") as xdmf:
    xdmf.write_mesh(domain)
    xdmf.write_function(EMID, 0.0)

with io.XDMFFile(domain.comm, str(output_dir / "fields" / "E_field.xdmf"), "w") as xdmf:
    xdmf.write_mesh(domain)
    xdmf.write_function(E, 0.0)

with io.XDMFFile(domain.comm, str(output_dir / "fields" / "ft_field.xdmf"), "w") as xdmf:
    xdmf.write_mesh(domain)
    xdmf.write_function(ft, 0.0)

with io.XDMFFile(domain.comm, str(output_dir / "fields" / "Gf_field.xdmf"), "w") as xdmf:
    xdmf.write_mesh(domain)
    xdmf.write_function(Gf, 0.0)

with io.XDMFFile(domain.comm, str(output_dir / "fields" / "Bt_field.xdmf"), "w") as xdmf:
    xdmf.write_mesh(domain)
    xdmf.write_function(Bt, 0.0)

with io.XDMFFile(domain.comm, str(output_dir / "fields" / "ed0_field.xdmf"), "w") as xdmf:
    xdmf.write_mesh(domain)
    xdmf.write_function(ed0, 0.0)

# ------------------------------------------------------------------
# Function space
# ------------------------------------------------------------------
gdim = domain.geometry.dim

Ue = basix.ufl.element("Lagrange", domain.basix_cell(), degree=1, shape=(gdim,))
V  = fem.functionspace(domain, Ue)

# ------------------------------------------------------------------
# MFront material (Mazars)
# ------------------------------------------------------------------
mat_props = {
    "YoungModulus": E,
    "PoissonRatio": 0.18,
    "Ac": 2.91,
    "At": 0.7,
    "Bc": 5000,
    "Bt": Bt,
    "k": 1.06,
    "ed0": ed0,
    "lfe": lfe,  # DG0 field
}

material = MFrontMaterial(
    path=str(behaviour_lib),
    name="Mazars",
    hypothesis="3d",
    material_properties=mat_props
)

# ------------------------------------------------------------------
# Boundary conditions (markers)
# ------------------------------------------------------------------
bottom_id = 2
top_id    = 1

bottom_facets = surf_tags.find(bottom_id)
top_facets    = surf_tags.find(top_id)

if rank == 0:
    print("Unique surface tags:", np.unique(surf_tags.values))
    print("bottom facets:", len(bottom_facets), "top facets:", len(top_facets))

assert len(bottom_facets) > 0, "No facets found for bottom_id"
assert len(top_facets) > 0, "No facets found for top_id"

# Clamp bottom (all components)
bottom_dofs = fem.locate_dofs_topological(V, fdim, bottom_facets)
zero = np.zeros(gdim, dtype=PETSc.ScalarType)
bc_bottom = fem.dirichletbc(zero, bottom_dofs, V)

# Prescribe only z on top
# ------------------------------------------------------------------
# IMPORTANT:
# Keep the original working constant-BC construction for uniform compression:
#     w_const + fem.dirichletbc(w_const, top_dofs_z_const, V.sub(2))
# For bending, a spatially varying z-displacement is required, so we use a
# collapsed scalar z-space only for the Dirichlet values.
# ------------------------------------------------------------------
Vz = V.sub(2)

# Original working dof detection for constant compression BC
top_dofs_z_const = fem.locate_dofs_topological(Vz, fdim, top_facets)
w_const = fem.Constant(domain, PETSc.ScalarType(0.0))

# Collapsed z-space for spatially varying bending BC values
Vz_collapsed, _ = Vz.collapse()
w_top_fun = fem.Function(Vz_collapsed, name="top_uz")
w_top_fun.x.array[:] = PETSc.ScalarType(0.0)

# Paired dofs: column 0 = parent/subspace dof, column 1 = collapsed-space dof.
# This is the standard DOLFINx pattern for non-constant values on a subspace.
top_pair_raw = fem.locate_dofs_topological((Vz, Vz_collapsed), fdim, top_facets)

def normalise_paired_dofs(pair_raw, Vz_space, Vz_collapsed_space, facets):
    """Return a two-column int32 array for DOLFINx subspace Dirichlet BCs."""
    if isinstance(pair_raw, (tuple, list)):
        if len(pair_raw) != 2:
            raise RuntimeError("Unexpected paired dof tuple/list length.")
        a = np.asarray(pair_raw[0], dtype=np.int32)
        b = np.asarray(pair_raw[1], dtype=np.int32)
        return np.column_stack((a, b)).astype(np.int32)

    arr = np.asarray(pair_raw, dtype=np.int32)

    if arr.ndim == 2 and arr.shape[1] == 2:
        return arr.astype(np.int32)

    if arr.ndim == 2 and arr.shape[0] == 2:
        return arr.T.copy().astype(np.int32)

    # Fallback for older/odd DOLFINx returns: pair the dofs by their ordering.
    # This is usually valid for CG1 z-subspace and its collapsed counterpart.
    if arr.ndim == 1:
        parent = arr.astype(np.int32)
        collapsed = np.asarray(
            fem.locate_dofs_topological(Vz_collapsed_space, fdim, facets),
            dtype=np.int32,
        )
        if len(parent) != len(collapsed):
            raise RuntimeError(
                f"Could not pair top z dofs: parent has {len(parent)} dofs, "
                f"collapsed has {len(collapsed)} dofs."
            )
        return np.column_stack((parent, collapsed)).astype(np.int32)

    raise RuntimeError(f"Unexpected top z dof format: shape={arr.shape}")


top_dofs_z_pair = normalise_paired_dofs(top_pair_raw, Vz, Vz_collapsed, top_facets)
top_dofs_z = top_dofs_z_pair[:, 0].astype(np.int32)          # parent/subspace dofs for reactions
top_dofs_z_collapsed = top_dofs_z_pair[:, 1].astype(np.int32) # collapsed dofs for prescribing values

# Coordinates associated with the collapsed scalar top z-dofs.
Vz_coords = Vz_collapsed.tabulate_dof_coordinates()
top_coords = Vz_coords[top_dofs_z_collapsed]

if rank == 0:
    print("Constrained dofs: bottom =", len(bottom_dofs), " top(z) =", len(top_dofs_z))

# ------------------------------------------------------------------
# Top-boundary coordinate bounds for linear bending profiles
# ------------------------------------------------------------------
if len(top_coords) > 0:
    local_x_min = np.min(top_coords[:, 0])
    local_x_max = np.max(top_coords[:, 0])
    local_y_min = np.min(top_coords[:, 1])
    local_y_max = np.max(top_coords[:, 1])
else:
    local_x_min = np.inf
    local_x_max = -np.inf
    local_y_min = np.inf
    local_y_max = -np.inf

x_min = comm.allreduce(local_x_min, op=MPI.MIN)
x_max = comm.allreduce(local_x_max, op=MPI.MAX)
y_min = comm.allreduce(local_y_min, op=MPI.MIN)
y_max = comm.allreduce(local_y_max, op=MPI.MAX)

x_range = x_max - x_min
y_range = y_max - y_min

if x_range <= 0.0:
    raise RuntimeError("Invalid top boundary x-range for bending loading.")
if y_range <= 0.0:
    raise RuntimeError("Invalid top boundary y-range for bending loading.")

x_c = 0.5 * (x_min + x_max)
y_c = 0.5 * (y_min + y_max)

if rank == 0:
    print("Top boundary bounds:")
    print("  x_min =", x_min, "x_max =", x_max, "x_c =", x_c)
    print("  y_min =", y_min, "y_max =", y_max, "y_c =", y_c)

# Owned scalar dofs on this MPI rank, used to avoid double-counting reactions.
num_owned_dofs = V.dofmap.index_map.size_local * V.dofmap.index_map_bs
owned_top_mask = top_dofs_z < num_owned_dofs

top_dofs_z_owned = top_dofs_z[owned_top_mask]
top_coords_owned = top_coords[owned_top_mask]

# ------------------------------------------------------------------
# PETSc options
# ------------------------------------------------------------------
petsc_options = {
    # Nonlinear solver
    "snes_type": "newtonls",
    "snes_linesearch_type": "bt",           # Backtracking for damage
    "snes_max_it": 150,
    "snes_rtol": 1e-4,                       # Relaxed for damage problems
    "snes_atol": 1e-6,                       # Relaxed absolute tolerance
    "snes_stol": 1e-8,                       # Step tolerance

    # Eisenstat-Walker method for nonlinear solver
    "snes_ksp_ew": 1,                        # Good for ill-conditioned problems
    "snes_ksp_ew_rtol0": 1e-3,               # Initial tolerance for EW
    "snes_ksp_ew_max_it": 5,                 # Max EW iterations

    # Linear solver - DIRECT SOLVER configuration
    "ksp_type": "preonly",                   # Only use preconditioner
    "pc_type": "lu",                         # LU factorization as preconditioner
    "pc_factor_mat_solver_type": "mumps",    # MUMPS for robust factorization

    # MUMPS specific options for ill-conditioned damage matrices
    "mat_mumps_icntl_4": 0,                  # Verbosity level (0-4)
    "mat_mumps_icntl_14": 50,                # Percentage increase in working space
    "mat_mumps_cntl_1": 1e-3,                # Relative pivoting threshold
    "mat_mumps_icntl_24": 1,                 # Detection of null pivots
    "mat_mumps_icntl_35": 1,                 # Enable BLR factorization for large problems

    # Monitoring (optional but useful)
    #"snes_monitor": None,
    #"snes_converged_reason": None,
    #"ksp_monitor": None,
    #"ksp_converged_reason": None,
    #"snes_linesearch_monitor": None,
}

# ------------------------------------------------------------------
# Loading cases
# ------------------------------------------------------------------
# The same displacement amplitude is used in all cases.
# For bending, the prescribed top z-displacement varies linearly from 0 to load_disp*t.
load_cases = [
    {
        "name": "UNICOMP",
        "label": "Uniform compression",
        "profile": "uniform",
        "moment_component": None,
    },
    {
        "name": "BENDF",
        "label": "Sagittal flexion / bending forward",
        "profile": "x_increasing",
        "moment_component": "My",
    },
    {
        "name": "BENDB",
        "label": "Sagittal extension / bending backward",
        "profile": "x_decreasing",
        "moment_component": "My",
    },
    {
        "name": "BENDL",
        "label": "Coronal bending left",
        "profile": "y_increasing",
        "moment_component": "Mx",
    },
    {
        "name": "BENDR",
        "label": "Coronal bending right",
        "profile": "y_decreasing",
        "moment_component": "Mx",
    },
]

# Skip compression because it is already finished
#load_cases = load_cases[1:]
# ------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------
def top_displacement_profile(profile_name: str, coords: np.ndarray) -> np.ndarray:
    """Return spatial scale factor for the prescribed top z-displacement."""
    if profile_name == "uniform":
        return np.ones(coords.shape[0], dtype=np.float64)

    if profile_name == "x_increasing":
        return (coords[:, 0] - x_min) / x_range

    if profile_name == "x_decreasing":
        return (x_max - coords[:, 0]) / x_range

    if profile_name == "y_increasing":
        return (coords[:, 1] - y_min) / y_range

    if profile_name == "y_decreasing":
        return (y_max - coords[:, 1]) / y_range

    raise ValueError(f"Unknown loading profile: {profile_name}")


def make_top_bc(profile_name: str):
    """Create the top z-Dirichlet BC for one loading case."""
    if profile_name == "uniform":
        w_const.value = PETSc.ScalarType(0.0)
        return fem.dirichletbc(w_const, top_dofs_z_const, Vz)

    w_top_fun.x.array[:] = PETSc.ScalarType(0.0)
    w_top_fun.x.scatter_forward()
    return fem.dirichletbc(w_top_fun, (top_dofs_z, top_dofs_z_collapsed), Vz)


def update_top_displacement(profile_name: str, disp_value: float):
    """Update the top z-displacement Dirichlet data."""
    if profile_name == "uniform":
        # Exact same style as your original working compression script.
        w_const.value = PETSc.ScalarType(disp_value)
        return

    # Spatially varying bending displacement in the collapsed scalar z-space.
    w_top_fun.x.array[:] = PETSc.ScalarType(0.0)

    factors = top_displacement_profile(profile_name, top_coords)
    values = disp_value * factors

    w_top_fun.x.array[top_dofs_z_collapsed] = values.astype(PETSc.ScalarType)
    w_top_fun.x.scatter_forward()


def build_problem_for_load_case(load_name: str, bc_top):
    """
    Build a fresh nonlinear material problem for each load case.

    This is important because Mazars damage is history-dependent. Recreating
    u, qmap, and the NonlinearMaterialProblem prevents damage/internal variables
    from one load case being carried into the next one.
    """
    u = fem.Function(V, name="Displacement")
    du = ufl.TrialFunction(V)
    v = ufl.TestFunction(V)

    qmap = QuadratureMap(domain, deg=2, material=material)
    qmap.register_gradient("Strain", symmetric_gradient(ufl.grad(u)))

    stress = qmap.fluxes["Stress"]
    eps_v = symmetric_gradient(ufl.grad(v))

    R = ufl.dot(stress, eps_v) * qmap.dx
    J = qmap.derivative(R, u, du)

    problem = NonlinearMaterialProblem(
        qmap=qmap,
        F=R,
        u=u,
        J=J,
        bcs=[bc_bottom, bc_top],
        petsc_options_prefix=f"mazars_{load_name}_",
        petsc_options=petsc_options,
    )

    residual_form = fem.form(R)

    return u, qmap, problem, residual_form


def compute_reactions_and_moments(residual_form):
    """
    Compute top reaction force and bending moments from the assembled residual.

    The reaction force is reported positive upward. If the mesh coordinates are
    in metres, moments are in N.m. If the mesh coordinates are in millimetres,
    moments are in N.mm.
    """
    residual_vec = fem_petsc.assemble_vector(residual_form)

    residual_vec.ghostUpdate(
        addv=PETSc.InsertMode.ADD_VALUES,
        mode=PETSc.ScatterMode.REVERSE
    )

    # Raw residual contribution at constrained z-dofs.
    raw_z_local = residual_vec.array[top_dofs_z_owned].copy()

    residual_vec.destroy()

    # Reaction on the structure is opposite to the internal residual.
    reaction_z_local = -raw_z_local

    local_raw_force_z = np.sum(raw_z_local)
    global_raw_force_z = comm.allreduce(local_raw_force_z, op=MPI.SUM)

    reaction_force_up = -global_raw_force_z

    if len(top_coords_owned) > 0:
        x = top_coords_owned[:, 0]
        y = top_coords_owned[:, 1]

        # Moment of vertical reactions around the superior endplate centre:
        # M = r x F, with F = (0, 0, Rz)
        local_moment_x = np.sum((y - y_c) * reaction_z_local)
        local_moment_y = np.sum(-(x - x_c) * reaction_z_local)
    else:
        local_moment_x = 0.0
        local_moment_y = 0.0

    moment_x = comm.allreduce(local_moment_x, op=MPI.SUM)
    moment_y = comm.allreduce(local_moment_y, op=MPI.SUM)

    return global_raw_force_z, reaction_force_up, moment_x, moment_y


def plot_curves(case_dir: Path, is_bending: bool):
    """Create force-displacement and, for bending, moment-displacement plots."""
    if rank != 0:
        return

    try:
        import matplotlib.pyplot as plt

        data = np.loadtxt(case_dir / "force_disp.csv", delimiter=",", skiprows=1)

        if data.ndim == 1:
            data = data.reshape(1, -1)

        disp = data[:, 3]   # positive downward displacement
        force = data[:, 5]  # positive upward reaction force

        plt.figure()
        plt.plot(disp, force, marker="o")
        plt.xlabel("Prescribed displacement downward [m]")
        plt.ylabel("Reaction force upward [N]")
        plt.grid(True)
        plt.tight_layout()
        plt.savefig(case_dir / "force_displacement_curve.png", dpi=300)
        plt.close()

        if is_bending:
            moment_data = np.loadtxt(case_dir / "moment_disp.csv", delimiter=",", skiprows=1)
            if moment_data.ndim == 1:
                moment_data = moment_data.reshape(1, -1)

            disp_m = moment_data[:, 3]
            moment = moment_data[:, 8]
            moment_abs = np.abs(moment)

            plt.figure()
            plt.plot(disp_m, moment_abs, marker="o")
            plt.xlabel("Prescribed displacement downward [m]")
            plt.ylabel("Bending moment magnitude")
            plt.grid(True)
            plt.tight_layout()
            plt.savefig(case_dir / "bending_moment_curve.png", dpi=300)
            plt.close()

    except Exception as e:
        print(f"Could not generate plots for {case_dir}: {e}")


# ------------------------------------------------------------------
# Time stepping parameters
# ------------------------------------------------------------------
n_steps   = 75
load_disp = -3e-4   # negative => downward
dt_base   = 0.75 / n_steps

results_root = output_dir / f"results{n_steps}"

if rank == 0:
    results_root.mkdir(parents=True, exist_ok=True)

comm.barrier()

# ------------------------------------------------------------------
# Loop over loading cases
# ------------------------------------------------------------------
if rank == 0:
    print(f"Running on {size} MPI ranks")
    print(f"Writing all load cases to: {results_root}")

summary_rows = []

for load_case in load_cases:

    load_name = load_case["name"]
    load_label = load_case["label"]
    profile_name = load_case["profile"]
    moment_component = load_case["moment_component"]
    is_bending = moment_component is not None

    case_dir = results_root / load_name

    if rank == 0:
        case_dir.mkdir(parents=True, exist_ok=True)
        print("\n" + "-" * 72)
        print(f"Running load case: {load_label} [{load_name}]")
        print("-" * 72)

    comm.barrier()

    # Fresh top BC and fresh problem for each load case.
    # This avoids carrying damage/internal variables between cases, and keeps
    # the compression BC identical to your original working FEniCSx script.
    bc_top = make_top_bc(profile_name)
    u, qmap, problem, residual_form = build_problem_for_load_case(load_name, bc_top)

    # Output files for this load case.
    u_out   = io.XDMFFile(comm, str(case_dir / "mazars_displacement.xdmf"), "w")
    d_out   = io.XDMFFile(comm, str(case_dir / "mazars_damage.xdmf"), "w")
    cod_out = io.XDMFFile(comm, str(case_dir / "crack_opening_wk.xdmf"), "w")

    for xdmf in (u_out, d_out, cod_out):
        xdmf.write_mesh(domain)

    # CSV output.
    force_csv = case_dir / "force_disp.csv"
    moment_csv = case_dir / "moment_disp.csv"

    if rank == 0:
        with open(force_csv, "w") as f:
            f.write(
                "step,t,prescribed_uz_max_m,displacement_down_m,"
                "raw_residual_z_N,reaction_force_up_N,"
                "moment_x,moment_y,selected_bending_moment\n"
            )

        if is_bending:
            with open(moment_csv, "w") as f:
                f.write(
                    "step,t,prescribed_uz_max_m,displacement_down_m,"
                    "raw_residual_z_N,reaction_force_up_N,"
                    "moment_x,moment_y,selected_bending_moment\n"
                )

    peak_force = 0.0
    peak_moment = 0.0
    final_dmax = 0.0

    for step in range(1, n_steps + 1):

        t = step * dt_base
        disp_value = load_disp * t
        abs_disp = -disp_value

        if rank == 0:
            print(
                f"\n[{load_name}] Step {step}/{n_steps}: "
                f"t = {t:.6f}, max displacement = {abs_disp:.6e}"
            )

        update_top_displacement(profile_name, disp_value)

        problem.solve()

        # ----------------------------------------------------------
        # Reaction force and bending moments
        # ----------------------------------------------------------
        raw_force_z, reaction_force_up, moment_x, moment_y = \
            compute_reactions_and_moments(residual_form)

        if moment_component == "Mx":
            selected_moment = moment_x
        elif moment_component == "My":
            selected_moment = moment_y
        else:
            selected_moment = 0.0

        peak_force = max(peak_force, abs(reaction_force_up))
        peak_moment = max(peak_moment, abs(selected_moment))

        if rank == 0:
            with open(force_csv, "a") as f:
                f.write(
                    f"{step},{t:.16e},{disp_value:.16e},{abs_disp:.16e},"
                    f"{raw_force_z:.16e},{reaction_force_up:.16e},"
                    f"{moment_x:.16e},{moment_y:.16e},{selected_moment:.16e}\n"
                )

            if is_bending:
                with open(moment_csv, "a") as f:
                    f.write(
                        f"{step},{t:.16e},{disp_value:.16e},{abs_disp:.16e},"
                        f"{raw_force_z:.16e},{reaction_force_up:.16e},"
                        f"{moment_x:.16e},{moment_y:.16e},{selected_moment:.16e}\n"
                    )

            print(f"  reaction_force_up = {reaction_force_up:.6e} N")
            if is_bending:
                print(
                    f"  Mx = {moment_x:.6e}, My = {moment_y:.6e}, "
                    f"selected {moment_component} = {selected_moment:.6e}"
                )

        # ----------------------------------------------------------
        # Field outputs
        # ----------------------------------------------------------
        u_out.write_function(u, t)

        d_proj = qmap.project_on("d", interp=("DG", 0))
        d_proj.name = "Damage"
        d_out.write_function(d_proj, t)

        cod = qmap.project_on("wk", interp=("DG", 0))
        cod.name = "CrackOpening"
        cod_out.write_function(cod, t)

        local_max = float(np.max(d_proj.x.array))
        final_dmax = comm.allreduce(local_max, op=MPI.MAX)

        if rank == 0:
            print(f"  d_max = {final_dmax:.3e}")

    u_out.close()
    d_out.close()
    cod_out.close()

    comm.barrier()

    plot_curves(case_dir, is_bending)

    if rank == 0:
        summary_rows.append(
            {
                "load_name": load_name,
                "load_label": load_label,
                "peak_reaction_force_up_N": peak_force,
                "peak_selected_bending_moment": peak_moment,
                "final_damage_max": final_dmax,
            }
        )

if rank == 0:
    summary_file = results_root / "load_case_summary.csv"

    with open(summary_file, "w") as f:
        f.write(
            "load_name,load_label,peak_reaction_force_up_N,"
            "peak_selected_bending_moment,final_damage_max\n"
        )
        for row in summary_rows:
            f.write(
                f"{row['load_name']},{row['load_label']},"
                f"{row['peak_reaction_force_up_N']:.16e},"
                f"{row['peak_selected_bending_moment']:.16e},"
                f"{row['final_damage_max']:.16e}\n"
            )

    print("\nDone.")
    print(f"Summary written to: {summary_file}")
