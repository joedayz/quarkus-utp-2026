package edu.utp.quarkus.student;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

import java.math.BigDecimal;

@Schema(name = "GradeInput", description = "Datos para crear o actualizar una calificación")
public class GradeInput {

    @NotBlank
    @Size(max = 32)
    @Schema(example = "CS401")
    public String courseCode;

    @NotNull
    @DecimalMin("0.0")
    @DecimalMax("20.0")
    @Schema(example = "17.5")
    public BigDecimal score;

    @Size(max = 16)
    @Schema(example = "2026-1")
    public String term;
}