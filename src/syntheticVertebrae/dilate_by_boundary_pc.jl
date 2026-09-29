function dilate_by_boundary_pc(Cff, seed_idx, forbidden_idx=Int[])
    isempty(seed_idx) && return collect(seed_idx)

    nF = length(Cff)
    sel = falses(nF); sel[seed_idx] .= true
    block = falses(nF)
    !isempty(forbidden_idx) && (block[forbidden_idx] .= true)

    boundary_seed = falses(nF)
    for f in seed_idx
        nbrs = Cff[f]
        if any(!sel[n] for n in nbrs)
            boundary_seed[f] = true
        end
    end

    nbrs_all = Int[]
    for f in findall(boundary_seed)
        append!(nbrs_all, Cff[f])
    end
    unique!(nbrs_all)

    to_add = [n for n in nbrs_all if !sel[n] && !block[n]]
    return unique(vcat(collect(seed_idx), to_add))
end

# -----------------------------------------------------------------------------
# Final volume mesh helpers
# -----------------------------------------------------------------------------

