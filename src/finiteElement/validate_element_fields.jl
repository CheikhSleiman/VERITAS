function validate_element_fields(n_elements::Int, fields)

    for (name, values) in fields
        length(values) == n_elements ||
            error(
                "Field $(name) has $(length(values)) entries, " *
                "but the final mesh has $(n_elements) tetrahedra."
            )
    end

    return true
end

