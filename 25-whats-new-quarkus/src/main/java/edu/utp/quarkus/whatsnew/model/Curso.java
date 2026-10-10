package edu.utp.quarkus.whatsnew.model;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Cacheable;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import org.hibernate.annotations.Cache;
import org.hibernate.annotations.CacheConcurrencyStrategy;

/**
 * Entidad cacheada en la region "cursos" de la segunda cache (L2) de Hibernate ORM.
 *
 * Desde Quarkus 3.38, la region Caffeine de esta cache puede configurarse con
 * eviccion basada en peso (ver {@link edu.utp.quarkus.whatsnew.cache.CursoWeigher})
 * ademas de la tradicional eviccion basada en conteo de objetos.
 */
@Entity
@Cacheable
@Cache(usage = CacheConcurrencyStrategy.READ_WRITE, region = "cursos")
public class Curso extends PanacheEntity {

    @Column(nullable = false)
    public String nombre;

    @Column(length = 1000)
    public String descripcion;

    public int creditos;
}
