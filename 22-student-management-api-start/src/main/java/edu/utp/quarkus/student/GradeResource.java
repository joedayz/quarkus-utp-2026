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
 * LAB: implementa los métodos. Referencia en
 * {@code ../22-student-management-api-solution/.../GradeResource.java}
 */
@Path("/students/{studentId}/grades")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Transactional
@Tag(name = "Grades", description = "Calificaciones por estudiante")
public class GradeResource {

    @GET
    @Operation(summary = "Listar calificaciones del estudiante")
    public List<Grade> list(@PathParam("studentId") Long studentId) {
        throw new UnsupportedOperationException("LAB: implementa list()");
    }

    @POST
    @Operation(summary = "Registrar calificación")
    public Response create(@PathParam("studentId") Long studentId, @Valid GradeInput input, @Context UriInfo uriInfo) {
        throw new UnsupportedOperationException("LAB: implementa create()");
    }

    @GET
    @Path("/{gradeId}")
    @Operation(summary = "Obtener una calificación")
    public Grade get(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId) {
        throw new UnsupportedOperationException("LAB: implementa get()");
    }

    @PUT
    @Path("/{gradeId}")
    @Operation(summary = "Actualizar calificación")
    public Grade update(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId, @Valid GradeInput input) {
        throw new UnsupportedOperationException("LAB: implementa update()");
    }

    @DELETE
    @Path("/{gradeId}")
    @Operation(summary = "Eliminar calificación")
    public void delete(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId) {
        throw new UnsupportedOperationException("LAB: implementa delete()");
    }
}
