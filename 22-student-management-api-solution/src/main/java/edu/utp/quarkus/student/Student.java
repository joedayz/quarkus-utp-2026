package edu.utp.quarkus.student;

import com.fasterxml.jackson.annotation.JsonIgnore;
import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "student")
@Schema(name = "Student", description = "Estudiante matriculado")
public class Student extends PanacheEntity {

    @NotBlank
    @Size(max = 32)
    @Column(name = "code", nullable = false, unique = true, length = 32)
    @Schema(example = "U2026001")
    public String code;

    @NotBlank
    @Size(max = 200)
    @Column(name = "full_name", nullable = false, length = 200)
    @Schema(example = "Ana Pérez")
    public String fullName;

    @Email
    @Size(max = 120)
    @Column(name = "email", length = 120)
    @Schema(example = "ana.perez@utp.edu.pe")
    public String email;

    @Size(max = 120)
    @Column(name = "career", length = 120)
    @Schema(example = "Ingeniería de Software")
    public String career;

    @OneToMany(mappedBy = "student", cascade = CascadeType.ALL, orphanRemoval = true)
    @JsonIgnore
    @Schema(hidden = true)
    public List<Grade> grades = new ArrayList<>();
}
