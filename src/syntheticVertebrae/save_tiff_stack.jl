function save_tiff_stack(B, folder)

    mkpath(folder)

    for file in readdir(folder; join=true)
        endswith(lowercase(file), ".tiff") && rm(file)
    end

    for k in axes(B, 3)

        file_name = joinpath(
            folder,
            "Vertebrae$(k).tiff",
        )

        slice = @view B[:, :, k]
        img = Gray{N0f8}.(clamp.(Float64.(slice), 0.0, 1.0))

        TiffImages.save(file_name, img)
    end
end

