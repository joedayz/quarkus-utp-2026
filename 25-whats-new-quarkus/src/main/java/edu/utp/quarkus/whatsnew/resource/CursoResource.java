package edu.utp.quarkus.whatsnew.resource;

import edu.utp.quarkus.whatsnew.model.Curso;
import edu.utp.quarkus.whatsnew.repository.CursoRepository;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

/**
 * Expone el catalogo de cursos, respaldado por la cache L2 de Hibernate ORM
 * (region "cursos") que demuestra la eviccion por peso introducida en Quarkus 3.38.
 *
 * Al repetir una peticion GET /cursos/{id}, Hibernate ORM resuelve la entidad
 * desde la cache Caffeine en memoria en lugar de volver a consultar la base de
 * datos, hasta que se supere el peso maximo configurado o expire la entrada.
 */
@Path("/cursos")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class CursoResource {

    @Inject
    CursoRepository cursoRepository;

    @GET
    public List<Curso> listar() {
        return cursoRepository.listAll();
    }

    @GET
    @Path("/{id}")
    public Curso buscarPorId(@PathParam("id") Long id) {
        Curso curso = cursoRepository.findById(id);
        if (curso == null) {
            throw new NotFoundException("Curso " + id + " no encontrado");
        }
        return curso;
    }

    @POST
    @Transactional
    public Curso crear(Curso curso) {
        cursoRepository.persist(curso);
        return curso;
    }
}
