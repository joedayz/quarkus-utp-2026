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

    public static List<Curso> findByCiclo(int ciclo) {
        return list("ciclo", ciclo);
    }

    public static List<Curso> findByDia(String dia) {
        return list("dia", dia);
    }

    public static List<Curso> findByCicloAndDia(int ciclo, String dia) {
        return list("ciclo = ?1 and dia = ?2", ciclo, dia);
    }
}
