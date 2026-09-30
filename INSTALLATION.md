# Installing VERITAS

VERITAS has two stages. Julia/Comodo builds the reference vertebra mesh and material fields. Python/FEniCSx loads those outputs and runs the Mazars multi-loading analysis. This guide targets **Ubuntu 24.04 on WSL 2**, the platform used for the working VERITAS setup.

## Tested setup

The working environment recorded during development used:

| Component | Recorded version or location |
| --- | --- |
| Ubuntu | 24.04 (WSL distribution named `VERITAS`) |
| Python | 3.12.13, in the Miniforge environment `veritas` |
| DOLFINx | 0.10.0 |
| MPICH | 5.0.1 |
| MFront/TFEL | 5.1.0 |
| MGIS | 3.1 series |
| Julia | 1.10.12 |
| Geogram/Vorpalite | Native Linux build; Geogram source commit `b745badadd5a4c9631f03623f5dfab1f16720fbf` |

These are observations from the working machine. The separate `VERITAS-installer-v2` bundle additionally records Miniforge `26.7.2-0` and generates exact dependency locks on installation. Keep `Project.toml` and `Manifest.toml` together when reproducing the Julia environment. The FEniCSx stage also requires a compatible `dolfinx_materials` installation and the committed Linux `src/finiteElement/libBehaviour.so`.

## Automated installation, when the installer is included

The installer bundle contains `install.sh`, `environment.yml`, and the complete `install/` directory. Place these at the root of a Linux checkout (`~/VERITAS`), then run:

```bash
cd ~/VERITAS
bash install.sh
```

The installer checks Ubuntu 24.04 x86-64, installs system packages, Miniforge, the `veritas` Conda environment, `dolfinx_materials`, Julia, and native Geogram/Vorpalite, then checks imports, MPI and a compiled MFront behaviour. It requires `sudo`, internet access and a Linux filesystem path outside `/mnt/`. Open a new shell after installation. The bundle is a separate artifact: these commands apply only if **all** of its files have been added to the repository. The manual procedure below also works without that bundle.

The installer pins packages in `environment.yml` and `install/versions.env`. On the first run, it resolves the current upstream commits for `dolfinx_materials`, Comodo, Geogram.jl and Geogram, writing `install/locks/source-revisions.env`. It also writes `install/locks/conda-linux-64.lock` and `install/locks/installed-versions.txt`. Preserve and commit the generated source and Conda locks after a successful fresh install to make that installation reproducible. Until those locks are committed, fresh installs can resolve newer upstream revisions.

## 1. Prepare Ubuntu

In PowerShell, check that the WSL distribution is available:

```powershell
wsl --list --verbose
wsl -d VERITAS
```

For a fresh machine, install Ubuntu with `wsl --install -d Ubuntu-24.04` and launch `wsl -d Ubuntu-24.04` instead. The custom name `VERITAS` describes the tested machine; it is not required by the code.

Inside Ubuntu, install the build and graphics prerequisites:

```bash
sudo apt update
sudo apt install -y git curl wget ca-certificates build-essential gcc g++ gfortran \
  cmake ninja-build pkg-config unzip zip dos2unix libglu1-mesa libgl1-mesa-dri \
  libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libtbb-dev
```

Clone this repository into the Linux filesystem, for example `~/VERITAS`, then run all remaining commands from that directory unless stated otherwise. A WSLg graphical session is needed to open the GLMakie figures.

## 2. Install the Python environment

Install [Miniforge](https://github.com/conda-forge/miniforge) for Linux x86-64 if it is not already installed. For exact reproduction of the installer bundle, download release `26.7.2-0` and check SHA-256 `281b0ac7d550802efc81af633225a5e6116d29ae72f3ab4eae7168c3931a4c05` before running it:

```bash
curl -L -o /tmp/Miniforge3-26.7.2-0-Linux-x86_64.sh \
  https://github.com/conda-forge/miniforge/releases/download/26.7.2-0/Miniforge3-26.7.2-0-Linux-x86_64.sh
echo '281b0ac7d550802efc81af633225a5e6116d29ae72f3ab4eae7168c3931a4c05  /tmp/Miniforge3-26.7.2-0-Linux-x86_64.sh' | sha256sum -c -
bash /tmp/Miniforge3-26.7.2-0-Linux-x86_64.sh -b -p "$HOME/miniforge3"
source "$HOME/miniforge3/etc/profile.d/conda.sh"
```

Initialize Conda when prompted and open a fresh shell. Create the environment from conda-forge:

```bash
mamba create -n veritas -c conda-forge --strict-channel-priority -y \
  python=3.12.13 fenics-dolfinx=0.10.0 mpi=1.0=mpich mpich=5.0.1 \
  mfront=5.1.0 'mgis=3.1.*' mpi4py jax jaxlib gmsh meshio pyvista \
  numpy scipy h5py matplotlib pip
conda activate veritas
```

Install `dolfinx_materials` into this environment. Obtain the [upstream source](https://github.com/bleyerj/dolfinx_materials), record its Git commit, and install it without replacing the Conda MPI/FEniCSx stack:

```bash
git clone https://github.com/bleyerj/dolfinx_materials.git ~/src/dolfinx_materials
git -C ~/src/dolfinx_materials rev-parse HEAD
python -m pip install --no-deps -e ~/src/dolfinx_materials
```

The exact `dolfinx_materials` commit from the working machine was not preserved in this guide. Verify the imports below before running a simulation; commit the resolved revision when it has passed the verification.

The earlier MFront build needed `TFELHOME` set to the active Conda prefix. Save that setting for this environment:

```bash
conda env config vars set -n veritas TFELHOME="$CONDA_PREFIX"
conda deactivate
conda activate veritas
tfel-config --include-path
```

Check the Python and material stack:

```bash
python - <<'PY'
import dolfinx, meshio, mpi4py, mgis.behaviour, jax
from dolfinx_materials.mfront import MFrontMaterial
from dolfinx_materials.quadrature_map import QuadratureMap
print("DOLFINx:", dolfinx.__version__)
print("Python, meshio, MPI, MGIS, JAX and dolfinx_materials: OK")
PY
ldd src/finiteElement/libBehaviour.so
```

`ldd` must not report missing libraries. The committed `.so` was built for Linux and must be compatible with the installed TFEL/MGIS libraries. The source for the Mazars behaviour is needed to rebuild it for a different toolchain.

## 3. Install Julia packages

Run Julia from a shell without an active Conda environment. If Conda is currently active, run `conda deactivate` first; repeat if environments are stacked, until `CONDA_PREFIX` is unset.

Install [Juliaup](https://docs.julialang.org/en/v1/manual/installation/) and select the version used for VERITAS:

```bash
curl -fsSL https://install.julialang.org | sh
juliaup add 1.10.12
juliaup default 1.10.12
cd ~/VERITAS
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```

Open a new shell if `julia` is not yet on `PATH`. The reference case imports `Comodo`, `GeometryBasics`, `FileIO`, `MeshIO`, `GLMakie`, `TiffImages`, `ImageCore` and `NearestNeighbors`; the repository's Julia environment should resolve these without adding packages to the global Julia environment.

```bash
julia --project=. -e 'using Comodo, GeometryBasics, FileIO, MeshIO, GLMakie, TiffImages, ImageCore, NearestNeighbors; @assert isdefined(Comodo, :mesh2bool); println("Julia imports: OK")'
```

If `Pkg.instantiate()` cannot resolve the required Comodo functionality, install Comodo from a recorded Git revision, as the installer does, rather than using Comodo release 1.0.3. Record the revision in `install/locks/source-revisions.env` if using the installer bundle.

## 4. Build Vorpalite for remeshing

The reference case calls the native `vorpalite` executable. Build Geogram with the **system GCC toolchain**, outside the Conda environment:

```bash
conda deactivate
mkdir -p ~/src
git clone --recurse-submodules https://github.com/BrunoLevy/geogram.git ~/src/geogram
cd ~/src/geogram
git checkout b745badadd5a4c9631f03623f5dfab1f16720fbf
git submodule update --init --recursive
env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  CC=/usr/bin/gcc CXX=/usr/bin/g++ ./configure.sh Linux64-gcc-dynamic
cmake --build build/Linux64-gcc-dynamic-Release --target vorpalite -j 8
test -x build/Linux64-gcc-dynamic-Release/bin/vorpalite
```

The pipeline checks `VORPALITE`, then `PATH`, then `~/src/geogram/build/Linux64-gcc-dynamic-Release/bin/vorpalite`. If you use another build location, set `VORPALITE` to its executable:

```bash
export VORPALITE="$HOME/src/geogram/build/Linux64-gcc-dynamic-Release/bin/vorpalite"
```

The working setup also installed `Geogram.jl` and linked its `ext/geogram/lin64/bin/vorpalite` to this native executable. That link is needed for Geogram.jl's own wrapper; the current reference script resolves the executable directly.

## 5. Check the case study inputs

The reference case expects:

```text
caseStudies/reference/input/vertebra.stl
src/finiteElement/ConvertGmshToXdmf.py
src/finiteElement/run_mazars.py
src/finiteElement/libBehaviour.so
```

The Julia stage writes `SpineVertebraePhantom.msh`, `Tetra.xdmf`, `Tetra.h5`, `Tri.xdmf` and `Tri.h5` to `caseStudies/reference/mesh/`. It writes `lfe.txt`, `element_material_ID.txt`, `YoungModulus.txt`, `TensileStrength.txt` and `FractureEnergy.txt` to `caseStudies/reference/data/`. Keep each XDMF file next to its referenced HDF5 file.

```bash
cd ~/VERITAS
test -f caseStudies/reference/input/vertebra.stl
test -f src/finiteElement/ConvertGmshToXdmf.py
test -f src/finiteElement/libBehaviour.so
test -f src/finiteElement/run_mazars.py
export VERITAS_PYTHON="$HOME/miniforge3/envs/veritas/bin/python"
test -x "$VERITAS_PYTHON"
```

`VERITAS_PYTHON` tells the Julia mesh converter which Python interpreter contains `meshio`. The default resolver checks `~/miniforge3/envs/veritas/bin/python`, so this explicit setting is optional for the standard installation. If Miniforge or the environment is installed elsewhere, use the full path of that environment's Python executable. The converter invokes Python directly; Conda activation is not required for the Julia stage.

## 6. Run the pipeline

First generate the mesh and material fields using Julia, **without an active Conda environment**. Open a fresh shell, or deactivate Conda as described in Section 3.

```bash
cd ~/VERITAS
julia --project=. caseStudies/reference/main.jl
```

The mesh converter uses the `veritas` Python interpreter directly, as described in Section 5.

Under the working WSLg graphics configuration, `GALLIUM_DRIVER=d3d12 julia --project=. caseStudies/reference/main.jl` was used for accelerated GLMakie. The Julia process waits for its figure windows to close after the pipeline completes.

Then **activate the `veritas` Conda environment** and run the FEniCSx/MFront stage:

```bash
cd ~/VERITAS
conda activate veritas
python src/finiteElement/run_mazars.py --case-dir caseStudies/reference
```

The solver reads `mesh/` and `data/`, loads `libBehaviour.so` from beside `run_mazars.py`, and writes field exports and load-case results under `caseStudies/reference/output/fenicsx/`. Use `--behaviour-lib PATH` or `--output-dir PATH` to override those defaults. The solver is a multi-step, multi-load nonlinear analysis; the full run can take substantial time and memory.

## Troubleshooting

- **Vorpalite not found:** check `test -x "$VORPALITE"` or export the executable path shown above.
- **Python converter not found:** make sure `src/finiteElement/ConvertGmshToXdmf.py` is present and `VERITAS_PYTHON` points to the `veritas` environment's Python executable. Activating Conda is not required for Julia's converter.
- **XDMF/HDF5 read error:** keep `Tetra.xdmf` with `Tetra.h5`, and `Tri.xdmf` with `Tri.h5`.
- **`libBehaviour.so` fails to load:** run `ldd src/finiteElement/libBehaviour.so`, activate `veritas`, and check `TFELHOME` and the installed MFront/MGIS versions.
- **GLMakie window does not open under WSL:** use a WSLg session and try `GALLIUM_DRIVER=d3d12`.

Reference documentation: [DOLFINx 0.10 installation](https://docs.fenicsproject.org/dolfinx/v0.10.0/python/installation.html), [dolfinx_materials](https://github.com/bleyerj/dolfinx_materials), [Julia installation](https://docs.julialang.org/en/v1/manual/installation/), [Geogram.jl](https://github.com/COMODO-research/Geogram.jl).
