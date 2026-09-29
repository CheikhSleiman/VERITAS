# =============================================================================
# VERITAS - Postprocessing and visualisation functions
# Extracted unchanged from the validated reference createVertebralPhantom.jl
# =============================================================================

# =============================================================================
# Helpers: Plotting
# =============================================================================

function axis_geom!(ax)

    autolimits!(ax)

    ax.aspect = :data
    ax.viewmode = :free
    ax.perspectiveness = 0.0

    # MATLAB view(3)
    ax.azimuth = deg2rad(-37.5)
    ax.elevation = deg2rad(30.0)

    return ax
end
