package edu.utp.quarkus.student;

import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.List;

/**
 * LAB: implementa los métodos (hoy lanzan {@link UnsupportedOperationException}).
 * Referencia: {@code ../22-student-management-api-solution/.../StudentResource.java}
 */
@Path("/students")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Transactional
@Tag(name = "Students", description = "Alta, baja y consulta de estudiantes")
public class StudentResource {

    @GET
    @Operation(summary = "Listar estudiantes")
    public List<Student> list() {
        throw new UnsupportedOperationException("LAB: implementa list()");
    }

    @POST
    @Operation(summary = "Crear estudiante")
    public Response create(@Valid Student student, @Context UriInfo uriInfo) {
        throw new UnsupportedOperationException("LAB: implementa create()");
    }

    @GET
    @Path("/{id}")
    @Operation(summary = "Obtener estudiante por id")
    public Student get(@PathParam("id") Long id) {
        throw new UnsupportedOperationException("LAB: implementa get()");
    }

    @PUT
    @Path("/{id}")
    @Operation(summary = "Actualizar estudiante")
    public Student update(@PathParam("id") Long id, @Valid Student updated) {
        throw new UnsupportedOperationException("LAB: implementa update()");
    }

    @DELETE
    @Path("/{id}")
    @Operation(summary = "Eliminar estudiante")
    public void delete(@PathParam("id") Long id) {
        throw new UnsupportedOperationException("LAB: implementa delete()");
    }
}
