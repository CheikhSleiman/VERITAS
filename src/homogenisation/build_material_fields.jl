function build_material_fields(ElementMaterialID)

    nElem = length(ElementMaterialID)

    # Cortical bone
    E_cortical = 15e9
    ft_cortical = 50e6
    Gf_cortical = 1000.0

    # Young's modulus
    E_tissue = 18e9
    n_E = 2.0
    q_E_blastic = 0.6
    E_min = 50e6
    E_blastic_max = 5e9

    # Tensile strength
    ft_ref = 70e6
    n_f = 2.0
    q_f_blastic = 0.4
    ft_min = 0.1e6
    ft_blastic_max = 20e6

    # Fracture energy
    Gf_ref = 1000.0
    n_G = 1.5
    q_G_blastic = 0.50
    Gf_min = 5.0
    Gf_blastic_max = 300.0

    # Blastic transition
    BVTV_blastic_threshold = 0.25
    k_transition = 60.0
    tol_cortical = 1e-8

    YoungModulus = zeros(Float64, nElem)
    TensileStrength = zeros(Float64, nElem)
    FractureEnergy = zeros(Float64, nElem)
    BVTV_clean = fill(NaN, nElem)
    MaterialClass = zeros(Int, nElem)

    is_cortical = abs.(ElementMaterialID .- 2.0) .< tol_cortical
    is_bvtv = (ElementMaterialID .> 0.0) .& (ElementMaterialID .<= 1.0)

    is_normal_cancellous =
        is_bvtv .&
        (ElementMaterialID .<= BVTV_blastic_threshold) .&
        .!is_cortical

    is_blastic =
        is_bvtv .&
        (ElementMaterialID .> BVTV_blastic_threshold) .&
        .!is_cortical

    is_unclassified = .!(is_cortical .| is_normal_cancellous .| is_blastic)

    BVTV_clean[is_normal_cancellous] .= ElementMaterialID[is_normal_cancellous]
    BVTV_clean[is_blastic] .= ElementMaterialID[is_blastic]
    BVTV_clean[is_cortical] .= 1.0

    is_bone_bvtv = is_normal_cancellous .| is_blastic
    bvf = BVTV_clean[is_bone_bvtv]

    S = 1.0 ./ (1.0 .+ exp.(-k_transition .* (bvf .- BVTV_blastic_threshold)))

    q_E = 1.0 .- (1.0 - q_E_blastic) .* S
    q_f = 1.0 .- (1.0 - q_f_blastic) .* S
    q_G = 1.0 .- (1.0 - q_G_blastic) .* S

    is_blastic_inside_bvtv_vector = is_blastic[is_bone_bvtv]

    E_values = q_E .* E_tissue .* (bvf .^ n_E)
    E_values = max.(E_values, E_min)
    E_values[is_blastic_inside_bvtv_vector] .= min.(
        E_values[is_blastic_inside_bvtv_vector],
        E_blastic_max,
    )
    YoungModulus[is_bone_bvtv] .= E_values

    ft_values = q_f .* ft_ref .* (bvf .^ n_f)
    ft_values = max.(ft_values, ft_min)
    ft_values[is_blastic_inside_bvtv_vector] .= min.(
        ft_values[is_blastic_inside_bvtv_vector],
        ft_blastic_max,
    )
    TensileStrength[is_bone_bvtv] .= ft_values

    Gf_values = q_G .* Gf_ref .* (bvf .^ n_G)
    Gf_values = max.(Gf_values, Gf_min)
    Gf_values[is_blastic_inside_bvtv_vector] .= min.(
        Gf_values[is_blastic_inside_bvtv_vector],
        Gf_blastic_max,
    )
    FractureEnergy[is_bone_bvtv] .= Gf_values

    YoungModulus[is_cortical] .= E_cortical
    TensileStrength[is_cortical] .= ft_cortical
    FractureEnergy[is_cortical] .= Gf_cortical

    MaterialClass[is_normal_cancellous] .= 1
    MaterialClass[is_cortical] .= 2
    MaterialClass[is_blastic] .= 3

    return (
        YoungModulus=YoungModulus,
        TensileStrength=TensileStrength,
        FractureEnergy=FractureEnergy,
        BVTV_clean=BVTV_clean,
        MaterialClass=MaterialClass,
        is_normal_cancellous=is_normal_cancellous,
        is_cortical=is_cortical,
        is_blastic=is_blastic,
        is_unclassified=is_unclassified,
        BVTV_blastic_threshold=BVTV_blastic_threshold,
        k_transition=k_transition,
        q_E_blastic=q_E_blastic,
        q_f_blastic=q_f_blastic,
        q_G_blastic=q_G_blastic,
        E_cortical=E_cortical,
        ft_cortical=ft_cortical,
        Gf_cortical=Gf_cortical,
    )
end

