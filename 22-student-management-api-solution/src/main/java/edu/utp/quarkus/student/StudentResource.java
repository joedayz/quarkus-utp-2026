package edu.utp.quarkus.student;

import io.micrometer.core.annotation.Counted;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.NotFoundException;
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

import java.net.URI;
import java.util.List;

@Path("/students")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Transactional
@Tag(name = "Students", description = "Alta, baja y consulta de estudiantes")
public class StudentResource {

    @GET
    @Operation(summary = "Listar estudiantes")
    public List<Student> list() {
        return Student.listAll();
    }

    @POST
    @Operation(summary = "Crear estudiante")
    @Counted(value = "students.created", description = "Estudiantes creados")
    public Response create(@Valid Student student, @Context UriInfo uriInfo) {
        student.id = null;
        student.grades.clear();
        student.persist();
        URI location = uriInfo.getAbsolutePathBuilder().path(student.id.toString()).build();
        return Response.created(location).entity(student).build();
    }

    @GET
    @Path("/{id}")
    @Operation(summary = "Obtener estudiante por id")
    public Student get(@PathParam("id") Long id) {
        return Student.<Student>findByIdOptional(id)
                .orElseThrow(() -> new NotFoundException("Student not found"));
    }

    @PUT
    @Path("/{id}")
    @Operation(summary = "Actualizar estudiante")
    public Student update(@PathParam("id") Long id, @Valid Student updated) {
        Student entity = Student.findById(id);
        if (entity == null) {
            throw new NotFoundException("Student not found");
        }
        entity.code = updated.code;
        entity.fullName = updated.fullName;
        entity.email = updated.email;
        entity.career = updated.career;
        return entity;
    }

    @DELETE
    @Path("/{id}")
    @Operation(summary = "Eliminar estudiante")
    public void delete(@PathParam("id") Long id) {
        Student entity = Student.findById(id);
        if (entity == null) {
            throw new NotFoundException("Student not found");
        }
        entity.delete();
    }
}
