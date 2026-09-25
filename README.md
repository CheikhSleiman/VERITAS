# VERITAS

VERITAS is organised as a complete computational pipeline, with reusable source code in `src/` and individual simulation cases in `caseStudies/`.

## Repository architecture

```text
VERITAS/
├── caseStudies/
│   ├── reference/
│   │   ├── input/
│   │   ├── main.jl
│   │   ├── mesh/
│   │   ├── images/
│   │   └── data/
│   │
│   ├── blastic_centered/
│   │   ├── input/
│   │   ├── main.jl
│   │   ├── mesh/
│   │   ├── images/
│   │   └── data/
│   │
│   ├── blastic_noncentered/
│   │   ├── input/
│   │   ├── main.jl
│   │   ├── mesh/
│   │   ├── images/
│   │   └── data/
│   │
│   ├── lytic_centered/
│   │   ├── input/
│   │   ├── main.jl
│   │   ├── mesh/
│   │   ├── images/
│   │   └── data/
│   │
│   └── lytic_noncentered/
│       ├── input/
│       ├── main.jl
│       ├── mesh/
│       ├── images/
│       └── data/
│
├── src/
│   ├── syntheticVertebrae/
│   ├── homogenisation/
│   ├── finiteElement/
│   └── postprocessing/
│
├── Project.toml
├── Manifest.toml
├── LICENSE
└── README.md
```

## Structure

### `caseStudies/`

Each case study contains its own `main.jl` file and its associated inputs and outputs.

- `input/` — input geometry and case-specific data
- `main.jl` — case-specific configuration and pipeline execution
- `mesh/` — generated surface and volumetric meshes
- `images/` — generated images and visual outputs
- `data/` — numerical and auxiliary output data

The five initial cases are:

- `reference`
- `blastic_centered`
- `blastic_noncentered`
- `lytic_centered`
- `lytic_noncentered`

### `src/`

Reusable functions shared by all case studies are organised according to the main VERITAS pipeline stages:

- `syntheticVertebrae/` — synthetic vertebra generation and mesh construction
- `homogenisation/` — material homogenisation and property mapping
- `finiteElement/` — finite-element models and solvers
- `postprocessing/` — analysis, visualisation and result processing

Each `main.jl` case-study script should call the common functions in `src/` rather than duplicate the implementation.
