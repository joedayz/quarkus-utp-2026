package edu.utp.quarkus.genai.model;

import java.util.List;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "curso")
public class Curso extends PanacheEntity {

    @Column(nullable = false)
    public String nombre;

    @Column(nullable = false, unique = true)
    public String codigo;

    @Column(nullable = false)
    public int ciclo;

    @Column(nullable = false)
    public String profesor;

    @Column(nullable = false)
    public String dia;

    @Column(name = "hora_inicio", nullable = false)
    public String horaInicio;

    @Column(name = "hora_fin", nullable = false)
    public String horaFin;

    @Column(nullable = false)
    public String aula;

    // TODO: Implementar método findByCiclo(int ciclo)
    // Debe retornar la lista de cursos filtrados por ciclo
    public static List<Curso> findByCiclo(int ciclo) {
        return List.of();
    }

    // TODO: Implementar método findByDia(String dia)
    // Debe retornar la lista de cursos filtrados por día
    public static List<Curso> findByDia(String dia) {
        return List.of();
    }

    // TODO: Implementar método findByCicloAndDia(int ciclo, String dia)
    // Debe retornar la lista de cursos filtrados por ciclo y día
    public static List<Curso> findByCicloAndDia(int ciclo, String dia) {
        return List.of();
    }
}
