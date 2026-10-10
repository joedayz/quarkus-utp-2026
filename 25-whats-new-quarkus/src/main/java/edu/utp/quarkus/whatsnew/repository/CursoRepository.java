package edu.utp.quarkus.whatsnew.repository;

import edu.utp.quarkus.whatsnew.model.Curso;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class CursoRepository implements PanacheRepository<Curso> {

    public Curso buscarPorNombre(String nombre) {
        return find("lower(nombre) like lower(?1)", "%" + nombre + "%").firstResult();
    }
}
