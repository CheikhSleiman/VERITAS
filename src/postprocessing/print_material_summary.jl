function print_material_summary(fields)

    YoungModulus = fields.YoungModulus
    TensileStrength = fields.TensileStrength
    FractureEnergy = fields.FractureEnergy
    BVTV_clean = fields.BVTV_clean

    is_normal = fields.is_normal_cancellous
    is_cortical = fields.is_cortical
    is_blastic = fields.is_blastic
    is_unclassified = fields.is_unclassified

    println()
    println("====================================================")
    println("Material assignment summary")
    println("====================================================")
    @printf("Number of elements:              %d\n", length(YoungModulus))
    @printf("Normal cancellous elements:      %d\n", count(is_normal))
    @printf("Blastic lesion elements:         %d\n", count(is_blastic))
    @printf("Cortical elements:               %d\n", count(is_cortical))
    @printf("Unclassified elements:           %d\n", count(is_unclassified))

    @printf("\nSmooth transition:\n")
    @printf("  BV/TV threshold:               %.4f\n", fields.BVTV_blastic_threshold)
    @printf("  k_transition:                  %.4f\n", fields.k_transition)

    @printf("\nBlastic quality factors:\n")
    @printf("  q_E_blastic:                   %.4f\n", fields.q_E_blastic)
    @printf("  q_f_blastic:                   %.4f\n", fields.q_f_blastic)
    @printf("  q_G_blastic:                   %.4f\n", fields.q_G_blastic)

    @printf("\nYoung's modulus range:\n")
    @printf("  Global min:                    %.4e Pa = %.4f GPa\n", minimum(YoungModulus), minimum(YoungModulus)/1e9)
    @printf("  Global max:                    %.4e Pa = %.4f GPa\n", maximum(YoungModulus), maximum(YoungModulus)/1e9)

    @printf("\nTensile strength range:\n")
    @printf("  Global min:                    %.4e Pa = %.4f MPa\n", minimum(TensileStrength), minimum(TensileStrength)/1e6)
    @printf("  Global max:                    %.4e Pa = %.4f MPa\n", maximum(TensileStrength), maximum(TensileStrength)/1e6)

    @printf("\nFracture energy range:\n")
    @printf("  Global min:                    %.4e N/m\n", minimum(FractureEnergy))
    @printf("  Global max:                    %.4e N/m\n", maximum(FractureEnergy))

    if any(is_normal)
        @printf("\nNormal cancellous bone:\n")
        @printf("  BV/TV range:                   %.4f to %.4f\n", minimum(BVTV_clean[is_normal]), maximum(BVTV_clean[is_normal]))
        @printf("  E range:                       %.4f to %.4f GPa\n", minimum(YoungModulus[is_normal])/1e9, maximum(YoungModulus[is_normal])/1e9)
        @printf("  ft range:                      %.4f to %.4f MPa\n", minimum(TensileStrength[is_normal])/1e6, maximum(TensileStrength[is_normal])/1e6)
        @printf("  Gf range:                      %.4f to %.4f N/m\n", minimum(FractureEnergy[is_normal]), maximum(FractureEnergy[is_normal]))
    end

    if any(is_blastic)
        @printf("\nBlastic lesion:\n")
        @printf("  BV/TV range:                   %.4f to %.4f\n", minimum(BVTV_clean[is_blastic]), maximum(BVTV_clean[is_blastic]))
        @printf("  E range:                       %.4f to %.4f GPa\n", minimum(YoungModulus[is_blastic])/1e9, maximum(YoungModulus[is_blastic])/1e9)
        @printf("  ft range:                      %.4f to %.4f MPa\n", minimum(TensileStrength[is_blastic])/1e6, maximum(TensileStrength[is_blastic])/1e6)
        @printf("  Gf range:                      %.4f to %.4f N/m\n", minimum(FractureEnergy[is_blastic]), maximum(FractureEnergy[is_blastic]))
    end

    if any(is_cortical)
        @printf("\nCortical bone:\n")
        @printf("  E_cortical:                    %.4f GPa\n", fields.E_cortical/1e9)
        @printf("  ft_cortical:                   %.4f MPa\n", fields.ft_cortical/1e6)
        @printf("  Gf_cortical:                   %.4f N/m\n", fields.Gf_cortical)
    end

    println("====================================================")
end

# -----------------------------------------------------------------------------
