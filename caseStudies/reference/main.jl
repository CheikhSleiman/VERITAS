# =============================================================================
# VERITAS - Vertebral phantom
# =============================================================================
# Julia translation of createVertebralPhantom.m
# GIBBON-parity implementation for remeshing, voxelisation, surface labelling,
# cortical refinement, homogenisation, material fields, and mesh export.
#
# Structure:
#   1. Imports and constants
#   2. Helper functions
#   3. Main pipeline
#   4. Figure wait at end
# =============================================================================

using Comodo
using GeometryBasics
using FileIO
using MeshIO
using GLMakie
using TiffImages
using ImageCore
using LinearAlgebra
using Statistics
using NearestNeighbors
using Printf

GLMakie.activate!()

# =============================================================================
# Case-study paths
# =============================================================================

const CASE_DIR = @__DIR__
const REPO_ROOT = normpath(joinpath(CASE_DIR, "..", ".."))

const INPUT_DIR  = joinpath(CASE_DIR, "input")
const MESH_DIR   = joinpath(CASE_DIR, "mesh")
const IMAGES_DIR = joinpath(CASE_DIR, "images")
const DATA_DIR   = joinpath(CASE_DIR, "data")

for dir in (INPUT_DIR, MESH_DIR, IMAGES_DIR, DATA_DIR)
    mkpath(dir)
end

const FIGURE_SCREENS = GLMakie.Screen[]

# =============================================================================
# Shared VERITAS functions
# =============================================================================

include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "resolve_vorpalite.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "write_obj_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "read_obj_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "ggremesh_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "weld_vertices.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "clean_unused_vertices.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "patch_edge_lengths_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "exterior_fill_6.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "tri_surf_to_im_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "dilate_sphere.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "save_tiff_stack.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "get_inner_point_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "dual_lattice_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "resize_contributions.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "resize_dimension.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "imresize3_linear.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "im2patch_v.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "triangle_face_normals_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "vertex_normals_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "patch_thick_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "element_centroid.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "strict_face_mask.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "tri_surf_logic_sharp_fix.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "face_normal_triangle.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "tri_edge_split_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "patch_boundary_label_edges_gibbon.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "tri_surf_split_boundary.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "dilate_by_boundary_pc.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "tet_vol_mean_est.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "subtet_method2.jl"))
include(joinpath(REPO_ROOT, "src", "syntheticVertebrae", "stable_unique_points.jl"))
include(joinpath(REPO_ROOT, "src", "homogenisation", "tet_centroids.jl"))
include(joinpath(REPO_ROOT, "src", "homogenisation", "face_centroids_matrix.jl"))
include(joinpath(REPO_ROOT, "src", "homogenisation", "face_inside_radius.jl"))
include(joinpath(REPO_ROOT, "src", "homogenisation", "homogenise_bvtv.jl"))
include(joinpath(REPO_ROOT, "src", "homogenisation", "build_material_fields.jl"))
include(joinpath(REPO_ROOT, "src", "finiteElement", "write_gmsh.jl"))
include(joinpath(REPO_ROOT, "src", "finiteElement", "tetra_volumes.jl"))
include(joinpath(REPO_ROOT, "src", "finiteElement", "scale_points.jl"))
include(joinpath(REPO_ROOT, "src", "finiteElement", "resolve_veritas_python.jl"))
include(joinpath(REPO_ROOT, "src", "finiteElement", "convert_gmsh_to_xdmf.jl"))
include(joinpath(REPO_ROOT, "src", "finiteElement", "validate_element_fields.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "axis_geom!.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "gpatch_plot.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "plot_volume.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "plot_patch_overlay.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "plot_volume_slices.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "plot_cortical_surfaces.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "plot_face_labels.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "plot_final_tet_mesh.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "plot_subtet_refinement.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "write_numeric_vector.jl"))
include(joinpath(REPO_ROOT, "src", "postprocessing", "print_material_summary.jl"))

function main()

# =============================================================================
# 01. Surface preparation
# =============================================================================
# =============================================================================
# Load vertebra
# =============================================================================

mesh_stl = load(
    joinpath(INPUT_DIR, "vertebra.stl");
    pointtype=Point{3, Float64},
    facetype=TriangleFace{Int64},
)

Vd = collect(coordinates(mesh_stl))
Fd = collect(faces(mesh_stl))

println()
println("Loaded vertebra.stl")
println("  vertices : ", length(Vd))
println("  faces    : ", length(Fd))

# STL files often repeat the same vertices for each triangle
Fd, Vd = weld_vertices(Fd, Vd)

println()
println("Connected surface")
println("  vertices : ", length(Vd))
println("  faces    : ", length(Fd))

# =============================================================================
# Rotate geometry
# =============================================================================

rot_angle = deg2rad(-6.0)

R = [
     cos(rot_angle)  0.0  sin(rot_angle)
     0.0             1.0  0.0
    -sin(rot_angle)  0.0  cos(rot_angle)
]

Vd = [
    Point{3, Float64}(R' * v)
    for v in Vd
]

# =============================================================================
# Original surface
# =============================================================================

fig1, ax1 = gpatch_plot(
    Fd,
    Vd;
    facecolor=:white,
    edgecolor=:black,
    facealpha=1.0,
    edgealpha=1.0,
    linewidth=0.5,
    title="Original vertebra",
)

# =============================================================================
# Remeshing
# =============================================================================

point_spacing = 2.0

target_spacing = point_spacing * 2.0

nb_pts = spacing2numvertices(
    Fd,
    Vd,
    target_spacing,
)

println()
println("Remeshing")
println("  point spacing   : ", point_spacing)
println("  target spacing  : ", target_spacing)
println("  target vertices : ", nb_pts)

Fd, Vd = ggremesh_gibbon(
    Fd,
    Vd;
    nb_pts=nb_pts,
    anisotropy=0,
    disp_on=true,
)

println()
println("Remeshed vertebra")
println("  vertices : ", length(Vd))
println("  faces    : ", length(Fd))

# Save for later
Fdr = copy(Fd)
Vdr = copy(Vd)

# =============================================================================
# Remeshed surface
# =============================================================================

fig2, ax2 = gpatch_plot(
    Fd,
    Vd;
    facecolor=:white,
    edgecolor=:black,
    facealpha=1,
    edgealpha=1,
    linewidth=0.5,
    title="Remeshed vertebra",
)

# =============================================================================
# 02. Voxelisation, first TetGen mesh, lattice, labelled image
# =============================================================================
# =============================================================================
# Surface to segmented image
# =============================================================================

voxel_size = 0.2

xmin = minimum(v[1] for v in Vd)
ymin = minimum(v[2] for v in Vd)
zmin = minimum(v[3] for v in Vd)

xmax = maximum(v[1] for v in Vd)
ymax = maximum(v[2] for v in Vd)
zmax = maximum(v[3] for v in Vd)

im_origin = Point{3, Float64}(
    xmin - 10 * voxel_size,
    ymin - 10 * voxel_size,
    zmin - 10 * voxel_size,
)

im_max = Point{3, Float64}(
    xmax + 10 * voxel_size,
    ymax + 10 * voxel_size,
    zmax + 10 * voxel_size,
)

im_size_xyz = round.(
    Int,
    [
        (im_max[1] - im_origin[1]) / voxel_size,
        (im_max[2] - im_origin[2]) / voxel_size,
        (im_max[3] - im_origin[3]) / voxel_size,
    ],
)

nx, ny, nz = im_size_xyz

println()
println("Voxelisation")
println("  voxel size : ", voxel_size)
println("  origin     : ", im_origin)
println("  dimensions : ", (ny, nx, nz))

# MATLAB convention:
# image dimensions are I,J,K = Y,X,Z

xr = im_origin[1] .+ (0:nx-1) .* voxel_size
yr = im_origin[2] .+ (0:ny-1) .* voxel_size
zr = im_origin[3] .+ (0:nz-1) .* voxel_size

Md = tri_surf_to_im_gibbon(
    Fd,
    Vd,
    voxel_size,
    im_origin,
    (ny, nx, nz),
)

println("  nonzero voxels  : ", count(!=(0), Md))

# =============================================================================
# Visualise segmented image
# =============================================================================

fig3, ax3 = plot_volume(
    Md,
    xr,
    yr,
    zr;
    title="Voxelised vertebra",
)

# =============================================================================
# Dilate binary image
# =============================================================================

dilatedMd = dilate_sphere(
    Md,
    2,
)

# =============================================================================
# Save binary images
# =============================================================================

save_tiff_stack(
    Md,
    joinpath(IMAGES_DIR, "BinaryTiffFilled"),
)

save_tiff_stack(
    dilatedMd,
    joinpath(IMAGES_DIR, "BinaryTiffFilledDilated"),
)

println()
println("TIFF stacks saved")
println("  BinaryTiffFilled")
println("  BinaryTiffFilledDilated")

# =============================================================================
# Volumetric mesh
# =============================================================================

# Single surface domain
F = Fd
V = Vd

# Region point
V_region1 = get_inner_point_gibbon(Fd, Vd)

V_regions = [V_region1]

# GIBBON tetVolMeanEst equivalent
edge_lengths = Comodo.edgelengths(Fd, Vd)

edge_length_mean =
    sum(edge_lengths) / length(edge_lengths)

vol1 =
    edge_length_mean^3 /
    (6.0 * sqrt(2.0))

region_tet_volumes = [vol1]

println()
println("Volumetric meshing")
println("  region point      : ", V_region1)
println("  mean edge length  : ", edge_length_mean)
println("  target tet volume : ", vol1)




# TetGen
E, V, CE, Fb, Cb = Comodo.tetgenmesh(
    F,
    V;
    V_regions=V_regions,
    region_vol=region_tet_volumes,
    stringOpt="pq1.2AaY",
)

# MATLAB sets all material IDs to 1 at this stage
CE .= 1

# All tetrahedral faces
Fall = Comodo.element2faces(E)

println()
println("Volume mesh complete")
println("  nodes          : ", length(V))
println("  tetrahedra     : ", length(E))
println("  boundary faces : ", length(Fb))
println("  all tet faces  : ", length(Fall))
println("  region IDs     : ", unique(CE))

# =============================================================================
# Dual lattice (faithful GIBBON cladOpt=0 port)
# =============================================================================

clad_opt = 0
shrink_factor = 0.1

FT, VT, CT = dual_lattice_gibbon(
    E,
    V,
    shrink_factor;
    clad_opt=clad_opt,
)

println()
println("Dual lattice")
println("  input tetrahedra : ", length(E))
println("  vertices         : ", length(VT))
println("  faces            : ", length(FT))
println("  labels           : ", sort(unique(CT)))

fig4, ax4 = gpatch_plot(
    FT,
    VT;
    facecolor=:gray,
    edgecolor=:black,
    facealpha=1.0,
    edgealpha=1.0,
    linewidth=0.5,
    title="Dual lattice",
)

fig5, ax5 = gpatch_plot(
    FT,
    VT;
    facecolor=:white,
    edgecolor=:black,
    facealpha=1.0,
    edgealpha=1.0,
    linewidth=0.5,
    title="Dual lattice surface",
)

# MATLAB: Vd=VT; Fd=FT; triSurf2Im(...)
Fd = FT
Vd = VT

Md1 = tri_surf_to_im_gibbon(
    Fd,
    Vd,
    voxel_size,
    im_origin,
    (ny, nx, nz),
)

println()
println("Lattice voxelisation")
println("  dimensions      : ", size(Md1))
println("  nonzero voxels  : ", count(!=(0), Md1))

fig6, ax6 = plot_volume(
    Md1,
    xr,
    yr,
    zr;
    title="Cancellous lattice",
)

save_tiff_stack(
    Md1,
    joinpath(IMAGES_DIR, "BinaryTiff"),
)

println()
println("Saved BinaryTiff")

# =============================================================================
# Final labelled volume
# =============================================================================

# Cortical shell
cortical = Int16.(dilatedMd) .- Int16.(Md)
cortical[cortical .== 1] .= 2

# Cancellous lattice
# MATLAB: Md1(Md1==2)=1;
cancellous = Int16.(Md1)
cancellous[cancellous .== 2] .= 1

# Combine cortical and cancellous regions
vertebrae = cortical .+ cancellous

vertebrae[vertebrae .== 3] .= 2
vertebrae[vertebrae .== 2] .= 3
vertebrae[vertebrae .== 1] .= 2
vertebrae[vertebrae .== 0] .= 1

# Recreate the dilated outer vertebral mask
Md_binary = Md .!= 0

dilatedMd_final = dilate_sphere(
    Md_binary,
    2,
)

# Remove everything outside the vertebra
vertebrae .*= Int16.(dilatedMd_final)

println()
println("Synthetic vertebra")
println("  dimensions : ", size(vertebrae))
println("  label 0    : ", count(==(0), vertebrae))
println("  label 1    : ", count(==(1), vertebrae))
println("  label 2    : ", count(==(2), vertebrae))
println("  label 3    : ", count(==(3), vertebrae))

# =============================================================================
# Save synthetic vertebra TIFF stack
# =============================================================================

# MATLAB divides by 255 before imwrite so that label values 0,1,2,3
# become grayscale intensities 0,1,2,3 in the written 8-bit TIFF.
ImBinary = Float64.(vertebrae) ./ 255.0

save_tiff_stack(
    ImBinary,
    joinpath(IMAGES_DIR, "syntheticVertebrae"),
)

println()
println("Saved syntheticVertebrae")

# =============================================================================
# 03. Downscale and voxel patch
# =============================================================================
# =============================================================================
# Downscale
# =============================================================================

scaleFactor = 0.4

println()
println("Downscaling synthetic vertebra")
println("  original size : ", size(vertebrae))
println("  scale factor  : ", scaleFactor)

vertebraeScaled = imresize3_linear(
    vertebrae,
    scaleFactor,
)

println("  scaled size   : ", size(vertebraeScaled))
println("  value range   : ", extrema(vertebraeScaled))

# =============================================================================
# im2patch
# =============================================================================

M = vertebraeScaled

mask =
    (M .>= 1.0) .&
    (M .< 2.0)

println()
println("im2patch")
println("  selected voxels : ", count(mask))

F, V, C = im2patch_v(
    M,
    mask,
)

println("  vertices        : ", length(V))
println("  faces           : ", length(F))
println("  colour range    : ", extrema(C))

# Scale image coordinates
image_scale =
    voxel_size / scaleFactor

V = [
    Point{3,Float64}(
        v[1] * image_scale,
        v[2] * image_scale,
        v[3] * image_scale,
    )
    for v in V
]

# =============================================================================
# Remesh original surface
# =============================================================================

pointSpacing = 1.0

target_spacing =
    pointSpacing * 2.0

nb_pts = spacing2numvertices(
    Fdr,
    Vdr,
    target_spacing,
)

Fdr, Vdr = ggremesh_gibbon(
    Fdr,
    Vdr;
    nb_pts=nb_pts,
    anisotropy=0,
    disp_on=true,
)

# Move original vertebra into image coordinate system
Vdrn = [
    Point{3,Float64}(
        v[1] - im_origin[1],
        v[2] - im_origin[2],
        v[3] - im_origin[3],
    )
    for v in Vdr
]

println()
println("Overlay surface")
println("  vertices : ", length(Vdrn))
println("  faces    : ", length(Fdr))

# =============================================================================
# Plot image patch + surface mesh
# =============================================================================

fig7, ax7 = plot_patch_overlay(
    F,
    V,
    C,
    Fdr,
    Vdrn;
    facealpha=0.8,
    surfacealpha=0.5,
    title="patch type: v",
    colorrange=extrema(M),
)

# =============================================================================
# 04. Cortical shell
# =============================================================================
# =============================================================================
# Visualisation 2
# =============================================================================

Mflip = reverse(
    M;
    dims=2,
)

fig8, ax8 = plot_volume_slices(
    Mflip,
    voxel_size;
    title="Synthetic vertebra slices",
)

# =============================================================================
# Visualisation 3
# =============================================================================

Z = getindex.(V, 3)

faceMask = [
    all(
        Z[Int(i)] < 20.0
        for i in f
    )
    for f in F
]

F_sub = F[faceMask]
C_sub = C[faceMask]

println()
println("Visualisation 3")
println("  selected faces : ", length(F_sub))

fig9, ax9 = plot_patch_overlay(
    F_sub,
    V,
    C_sub,
    Fdr,
    Vdrn;
    facealpha=0.8,
    surfacealpha=0.5,
    title="Patch section Z < 20",
    colorrange=extrema(M),
)

# =============================================================================
# Cortical bone layer
# =============================================================================

layerThickness = 1.0
numSteps = 4
dirSet = 1

println()
println("Cortical bone layer")
println("  thickness : ", layerThickness)
println("  steps     : ", numSteps)
println("  direction : ", dirSet)

E_shell, VE, Fq1_raw, Fq2_raw = patch_thick_gibbon(
    Fdr,
    Vdrn,
    dirSet,
    layerThickness,
    numSteps,
)

# =============================================================================
# Visualise cortical surfaces
# =============================================================================

fig10, ax10 = plot_cortical_surfaces(
    Fq1_raw,
    VE,
    Fq2_raw,
    VE;
    title="Cortical shell before remeshing",
)

# =============================================================================
# Remesh inner cortical surface
# =============================================================================

nb_pts_shell = length(Vdrn)

println()
println("Remeshing inner cortical surface")
println("  target vertices : ", nb_pts_shell)

Fq1, Vq1 = ggremesh_gibbon(
    Fq1_raw,
    VE;
    nb_pts=nb_pts_shell,
    anisotropy=0,
    disp_on=true,
)

Fq1, Vq1 = ggremesh_gibbon(
    Fq1,
    Vq1;
    nb_pts=nb_pts_shell,
    anisotropy=0,
    disp_on=true,
)

# =============================================================================
# Remesh outer cortical surface
# =============================================================================

println()
println("Remeshing outer cortical surface")
println("  target vertices : ", nb_pts_shell)

Fq2, Vq2 = ggremesh_gibbon(
    Fq2_raw,
    VE;
    nb_pts=nb_pts_shell,
    anisotropy=0,
    disp_on=true,
)

Fq2, Vq2 = ggremesh_gibbon(
    Fq2,
    Vq2;
    nb_pts=nb_pts_shell,
    anisotropy=0,
    disp_on=true,
)

println()
println("Cortical surfaces")
println("  inner vertices : ", length(Vq1))
println("  inner faces    : ", length(Fq1))
println("  outer vertices : ", length(Vq2))
println("  outer faces    : ", length(Fq2))

# =============================================================================
# Visualise remeshed cortical surfaces
# =============================================================================

fig11, ax11 = plot_cortical_surfaces(
    Fq1,
    Vq1,
    Fq2,
    Vq2;
    title="Cortical shell after remeshing",
)

# =============================================================================
# 05. Surface labels and combined domains
# =============================================================================
# =============================================================================
# Surface mesh labelling
# =============================================================================

# The Julia/Vorpalite remesh gives slightly different local face normals from
# the MATLAB/GIBBON mesh. 18° reproduces the top endplate well; 25° is used
# for the bottom endplate to reproduce the MATLAB-labelled inferior surface.
angularThresholdTop = deg2rad(18.0)
angularThresholdBottom = deg2rad(25.0)
distanceThreshold = 250.0

Fd = copy(Fq2)
Vd = copy(Vq2)

# Face centres
VdF = Comodo.facecentroid(
    Fd,
    Vd,
)

# Face normals. For triangular faces this follows GIBBON patchNormal's
# oriented cross-product normal convention.
N = triangle_face_normals_gibbon(Fd, Vd)

a = [
    acos(
        clamp(
            Float64(n[3]),
            -1.0,
            1.0,
        )
    )
    for n in N
]

# Distance from Z-axis
D = [
    hypot(
        p[1],
        p[2],
    )
    for p in VdF
]

logicTop =
    (D .< distanceThreshold) .&
    (a .< angularThresholdTop)

logicTop = strict_face_mask(
    Fd,
    logicTop,
)

logicTop = tri_surf_logic_sharp_fix(
    Fd,
    logicTop,
    3,
)

logicBottom =
    (D .< distanceThreshold) .&
    (a .> (π - angularThresholdBottom))

logicBottom = strict_face_mask(
    Fd,
    logicBottom,
)

logicBottom = tri_surf_logic_sharp_fix(
    Fd,
    logicBottom,
    3,
)

# -----------------------------------------------------------------------------
# Face labels
# -----------------------------------------------------------------------------

Cd = zeros(
    Int,
    length(Fd),
)

Cd[logicTop] .= 1
Cd[logicBottom] .= 2

println()
println("Initial surface labels")
println("  wall   : ", count(==(0), Cd))
println("  top    : ", count(==(1), Cd))
println("  bottom : ", count(==(2), Cd))

# =============================================================================
# Boundary curves
# =============================================================================

Eb1 = Comodo.boundaryedges(
    Fd[Cd .== 1],
)

indList1 = Comodo.edges2curve(
    Eb1;
    remove_last=true,
)

Eb2 = Comodo.boundaryedges(
    Fd[Cd .== 2],
)

indList2 = Comodo.edges2curve(
    Eb2;
    remove_last=true,
)

n1 = length(indList1)
n2 = length(indList2)

println()
println("Boundary vertices")
println("  top    : ", n1)
println("  bottom : ", n2)

# =============================================================================
# Equalise top/bottom boundary counts (GIBBON triSurfSplitBoundary)
# =============================================================================

if n1 > n2
    nn = n1 - n2
    println("Splitting bottom boundary from ", n2, " to ", n2 + nn, " points")
    Fd, Vd, Eb2, Cd = tri_surf_split_boundary(
        Fd, Vd, Eb2, length(Eb2) + nn, Cd,
    )
elseif n2 > n1
    nn = n2 - n1
    println("Splitting top boundary from ", n1, " to ", n1 + nn, " points")
    Fd, Vd, Eb1, Cd = tri_surf_split_boundary(
        Fd, Vd, Eb1, length(Eb1) + nn, Cd,
    )
end

# Recompute boundaries after splitting
Eb1 = Comodo.boundaryedges(
    Fd[Cd .== 1],
)

indList1 = Comodo.edges2curve(
    Eb1;
    remove_last=true,
)

Eb2 = Comodo.boundaryedges(
    Fd[Cd .== 2],
)

indList2 = Comodo.edges2curve(
    Eb2;
    remove_last=true,
)

println()
println("Equalised boundaries")
println(
    "  top    : ",
    length(indList1),
)
println(
    "  bottom : ",
    length(indList2),
)

# =============================================================================
# Visualise initial labels
# =============================================================================

fig12, ax12 = plot_face_labels(
    Fd,
    Vd,
    Cd;
    title="Top and bottom surface labels",
    alpha=1.0,
)

# =============================================================================
# Dilate marked surfaces
# =============================================================================

growRings = 4

Con = Comodo.meshconnectivity(
    Fd,
    Vd,
)

Cff = Con.face_face

seedTop =
    findall(==(1), Cd)

seedBottom =
    findall(==(2), Cd)

for r in 1:growRings

    # Grow top without invading bottom
    seedTop = dilate_by_boundary_pc(
        Cff,
        seedTop,
        seedBottom,
    )

    Cd[seedTop] .= 1

    # Grow bottom without invading grown top
    seedBottom = dilate_by_boundary_pc(
        Cff,
        seedBottom,
        seedTop,
    )

    Cd[seedBottom] .= 2

    println(
        "Growth ring ",
        r,
        " | top=",
        length(seedTop),
        " bottom=",
        length(seedBottom),
    )
end

# MATLAB computes these again after growth
logicTop =
    Cd .== 1

logicBottom =
    Cd .== 2

logicTop = tri_surf_logic_sharp_fix(Fd, logicTop, 3)

logicBottom = tri_surf_logic_sharp_fix(Fd, logicBottom, 3)

# =============================================================================
# Visualise grown labels
# =============================================================================

fig13, ax13 = plot_face_labels(
    Fd,
    Vd,
    Cd;
    title="Surface labels after four-ring growth",
    alpha=1.0,
)

println()
println("Grown surface labels")
println("  wall   : ", count(==(0), Cd))
println("  top    : ", count(==(1), Cd))
println("  bottom : ", count(==(2), Cd))

# =============================================================================
# Combine cortical domains
# =============================================================================
println()
println("===== JULIA COMBINED SURFACE CHECK =====")
println("Fq1 faces    : ", length(Fq1))
println("Vq1 vertices : ", length(Vq1))
println("Fd faces     : ", length(Fd))
println("Vd vertices  : ", length(Vd))
println("Fv expected  : ", length(Fq1) + length(Fd))
println("========================================")

Cq1 = fill(
    3,
    length(Fq1),
)

Fv, Vv, _ = Comodo.joingeom(
    Fq1,
    Vq1,
    Fd,
    Vd,
)

# Preserve MATLAB face markers
Cv = vcat(
    Cq1,
    Cd,
)

println()
println("Combined surfaces")
println("  vertices : ", length(Vv))
println("  faces    : ", length(Fv))
println("  markers  : ", sort(unique(Cv)))

# =============================================================================
# Visualise combined domains
# =============================================================================

fig14, ax14 = plot_face_labels(
    Fv,
    Vv,
    Cv;
    title="Combined cortical domains",
    alpha=0.5,
)

# =============================================================================
# 06. Final two-region TetGen mesh
# =============================================================================

# Seed inside cortical shell
shell_element = E_shell[cld(length(E_shell), 2)]

V_region1 = element_centroid(
    shell_element,
    VE,
)

# Seed inside cancellous compartment
V_region2 = get_inner_point_gibbon(
    Fq1,
    Vq1,
)

V_regions_final = [
    V_region1,
    V_region2,
]

vol1_final = tet_vol_mean_est(
    Fd,
    Vd,
)

vol2_final = tet_vol_mean_est(
    Fq1,
    Vq1,
)

region_vol_final = [
    vol1_final,
    vol2_final,
]

println()
println("Final two-region TetGen mesh")
println("  cortical region point   : ", V_region1)
println("  cancellous region point : ", V_region2)
println("  cortical target volume  : ", vol1_final)
println("  cancellous target volume: ", vol2_final)
println("  input faces             : ", length(Fv))
println("  input vertices          : ", length(Vv))
println("  face markers            : ", sort(unique(Cv)))

E, Vm, CE_raw, Fb, Cb = Comodo.tetgenmesh(
    Fv,
    Vv;
    facetmarkerlist=Cv,
    V_regions=V_regions_final,
    region_vol=region_vol_final,
    stringOpt="pq1.2AaY",
)

CE = Int.(round.(abs.(CE_raw)))

println("  raw region IDs          : ", sort(unique(CE)))

# MATLAB performs these assignments sequentially:
# CE(CE==1)=3; CE(CE==2)=1; CE(CE==3)=2;
CE[CE .== 1] .= 3
CE[CE .== 2] .= 1
CE[CE .== 3] .= 2

println("  remapped material IDs   : ", sort(unique(CE)))
println("  nodes                   : ", length(Vm))
println("  tetrahedra              : ", length(E))
println("  boundary faces          : ", length(Fb))

# =============================================================================
# Visualise final volume mesh
# =============================================================================

fig15, ax15a, ax15b = plot_final_tet_mesh(
    E,
    Vm,
    CE,
    Fb,
    Cb;
    title="Final two-region tetrahedral mesh",
)

# =============================================================================
# 07. Cortical subTet refinement and final TetGen rerun
# =============================================================================

E2 = E[CE .== 2]

println()
println("Cortical subTet refinement")
println("  cortical tetrahedra : ", length(E2))

E1, V1 = subtet_method2(E2, Vm)

println("  refined tetrahedra  : ", length(E1))
println("  refined vertices    : ", length(V1))
println("  new centroid nodes  : ", length(V1) - length(Vm))

fig16, ax16 = plot_subtet_refinement(
    E1,
    V1;
    title="subTet method 2 - cortical refinement",
)

# MATLAB: Vall = unique([Vm; V1], 'rows', 'stable')
Vall = stable_unique_points(vcat(Vm, V1))

println()
println("TetGen rerun with cortical centroid points")
println("  input nodes : ", length(Vall))

E, Vm, CE_raw, Fb, Cb = Comodo.tetgenmesh(
    Fv,
    Vall;
    facetmarkerlist=Cv,
    V_regions=V_regions_final,
    region_vol=region_vol_final,
    stringOpt="pq1.2AaY",
)

CE = Int.(round.(abs.(CE_raw)))
CE[CE .== 1] .= 3
CE[CE .== 2] .= 1
CE[CE .== 3] .= 2

println("  nodes             : ", length(Vm))
println("  tetrahedra        : ", length(E))
println("  boundary faces    : ", length(Fb))
println("  material IDs      : ", sort(unique(CE)))

fig17, ax17a, ax17b = plot_final_tet_mesh(
    E,
    Vm,
    CE,
    Fb,
    Cb;
    title="Final mesh after cortical subTet refinement",
)

# =============================================================================
# 08. Homogenisation / local BVTV
# =============================================================================

homogenisation_radius = 3.0

println()
println("Homogenisation / BVTV")
println("  tetrahedra      : ", length(E))
println("  patch faces     : ", length(F))
println("  radius          : ", homogenisation_radius)
println("  Julia threads   : ", Threads.nthreads())

# CE at this point is the final TetGen material marker field:
#   2 = cortical marker
#   1 = cancellous region marker
# The MATLAB homogenisation replaces non-cortical markers by local
# mean patch value minus 1, which yields the local BV/TV field.

println()
println("========== PRE-HOMOGENISATION CHECK ==========")

println("Final CE labels: ", sort(unique(CE)))

for id in sort(unique(CE))
    println(
        "  CE = ", id,
        " : ", count(==(id), CE),
        " tetrahedra"
    )
end

println()
println("Patch values C:")
println("  min  = ", minimum(C))
println("  mean = ", mean(C))
println("  max  = ", maximum(C))

println("  C < 2 : ", count(<(2.0), C), " / ", length(C))

println("==============================================")


elementMaterialID, _, homogenisation_face_count, _ = homogenise_bvtv(
    E,
    Vm,
    CE,
    F,
    V,
    C;
    radius=homogenisation_radius,
)

is_cortical_hom = elementMaterialID .== 2.0
is_bvtv_hom = .!is_cortical_hom

n_no_faces = count(
    i -> is_bvtv_hom[i] && homogenisation_face_count[i] == 0,
    eachindex(E),
)

println()
println("Homogenisation complete")
println("  cortical elements          : ", count(is_cortical_hom))
println("  BV/TV elements             : ", count(is_bvtv_hom))
println("  non-cortical with no faces : ", n_no_faces)

if any(is_bvtv_hom)
    bvtv_values = elementMaterialID[is_bvtv_hom]

    println("  BV/TV min                  : ", minimum(bvtv_values))
    println("  BV/TV mean                 : ", mean(bvtv_values))
    println("  BV/TV max                  : ", maximum(bvtv_values))
end

# =============================================================================
# 09. Material classes and apparent mechanical properties
# =============================================================================

println()
println("Material fields")

material_fields = build_material_fields(elementMaterialID)

if any(material_fields.is_unclassified)
    unclassified_values = sort(unique(elementMaterialID[material_fields.is_unclassified]))
    @warn "Some elements were not classified" values=unclassified_values
end

print_material_summary(material_fields)

YoungModulus = material_fields.YoungModulus
TensileStrength = material_fields.TensileStrength
FractureEnergy = material_fields.FractureEnergy
BVTV_clean = material_fields.BVTV_clean
MaterialClass = material_fields.MaterialClass

# Preserve the homogenised BV/TV field as floating-point data.  The MATLAB
# source uses %d for this file, which would destroy non-integer BV/TV values;
# VERITAS writes full precision because the following property laws require it.
write_numeric_vector(joinpath(DATA_DIR, "element_material_ID.txt"), elementMaterialID)
write_numeric_vector(joinpath(DATA_DIR, "YoungModulus.txt"), YoungModulus)
write_numeric_vector(joinpath(DATA_DIR, "TensileStrength.txt"), TensileStrength)
write_numeric_vector(joinpath(DATA_DIR, "FractureEnergy.txt"), FractureEnergy)
write_numeric_vector(joinpath(DATA_DIR, "BVTV_clean.txt"), BVTV_clean)
write_numeric_vector(joinpath(DATA_DIR, "MaterialClass.txt"), MaterialClass)

println()
println("Saved material fields")
println("  element_material_ID.txt")
println("  YoungModulus.txt")
println("  TensileStrength.txt")
println("  FractureEnergy.txt")
println("  BVTV_clean.txt")
println("  MaterialClass.txt")

# =============================================================================
# 10. Final mesh export
# =============================================================================

validate_element_fields(
    length(E),
    [
        "elementMaterialID" => elementMaterialID,
        "YoungModulus" => YoungModulus,
        "TensileStrength" => TensileStrength,
        "FractureEnergy" => FractureEnergy,
        "BVTV_clean" => BVTV_clean,
        "MaterialClass" => MaterialClass,
    ],
)

# MATLAB scales the final vertebra mesh before Gmsh export.
mesh_scale = 0.0006
V_export = scale_points(Vm, mesh_scale)

println()
println("Final mesh scaling")
println("  scale factor : ", mesh_scale)
println("  nodes        : ", length(V_export))
println("  tetrahedra   : ", length(E))
println("  boundaries   : ", length(Fb))

# In the MATLAB source the heterogeneous BV/TV/material data are stored in
# separate text files, then meshOutput.elementMaterialID is deliberately reset
# to ones before writeGmsh.  Preserve that convention here so XDMF tetrahedra
# remain a single physical volume and the per-element fields remain external.
gmsh_volume_id = ones(Int, length(E))

msh_path = joinpath(MESH_DIR, "SpineVertebraePhantom.msh")

write_gmsh(
    msh_path,
    E,
    V_export,
    gmsh_volume_id,
    Fb,
    Cb,
)

# Convert the Gmsh 2.2 mesh using the existing Im2Sim meshio workflow.
converter_path = joinpath(REPO_ROOT, "src", "finiteElement", "ConvertGmshToXdmf.py")

xdmf_outputs = convert_gmsh_to_xdmf(
    converter_path,
    msh_path;
    tetra_name="Tetra.xdmf",
    triangle_name="Tri.xdmf",
)

# MATLAB computes lfe from the already-scaled final mesh:
# lfe = tetrahedron_volume^(1/3)
Vol = tetra_volumes(E, V_export)

all(isfinite, Vol) || error("Non-finite tetrahedral volume detected.")
minimum(Vol) > 0.0 || error("Zero-volume tetrahedron detected in final mesh.")

lfe = Vol .^ (1.0 / 3.0)
write_numeric_vector(joinpath(DATA_DIR, "lfe.txt"), lfe)

println()
println("Final mesh fields")
println("  tetra volume min  : ", minimum(Vol))
println("  tetra volume mean : ", mean(Vol))
println("  tetra volume max  : ", maximum(Vol))
println("  lfe min           : ", minimum(lfe))
println("  lfe mean          : ", mean(lfe))
println("  lfe max           : ", maximum(lfe))

println()
println("Final outputs")
println("  SpineVertebraePhantom.msh")
for path in xdmf_outputs
    println("  ", basename(path))
end
println("  element_material_ID.txt")
println("  YoungModulus.txt")
println("  TensileStrength.txt")
println("  FractureEnergy.txt")
println("  BVTV_clean.txt")
println("  MaterialClass.txt")
println("  lfe.txt")

# =============================================================================
# 11. Finish
# =============================================================================

println()
println("VERITAS vertebral phantom pipeline complete.")
println("Close all figure windows to exit.")

while any(isopen, FIGURE_SCREENS)
    sleep(0.1)
end

println("All figures closed.")

end # main

main()
