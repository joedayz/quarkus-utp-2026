package edu.utp.quarkus.student;

import com.fasterxml.jackson.annotation.JsonIgnore;
import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

import java.math.BigDecimal;

@Entity
@Table(name = "grade")
@Schema(name = "Grade", description = "Calificación de un curso para un estudiante")
public class Grade extends PanacheEntity {

    @NotNull
    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "student_id", nullable = false)
    @JsonIgnore
    @Schema(hidden = true)
    public Student student;

    @NotBlank
    @Size(max = 32)
    @Column(name = "course_code", nullable = false, length = 32)
    @Schema(example = "CS401")
    public String courseCode;

    @NotNull
    @DecimalMin("0.0")
    @DecimalMax("20.0")
    @Column(name = "score", nullable = false, precision = 4, scale = 2)
    @Schema(example = "17.5", description = "Nota en escala 0–20")
    public BigDecimal score;

    @Size(max = 16)
    @Column(name = "term", length = 16)
    @Schema(example = "2026-1")
    public String term;
}
