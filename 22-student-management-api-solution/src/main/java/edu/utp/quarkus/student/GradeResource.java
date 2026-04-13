package edu.utp.quarkus.student;

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

@Path("/students/{studentId}/grades")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Transactional
@Tag(name = "Grades", description = "Calificaciones por estudiante")
public class GradeResource {

    @GET
    @Operation(summary = "Listar calificaciones del estudiante")
    public List<Grade> list(@PathParam("studentId") Long studentId) {
        Student student = requireStudent(studentId);
        return Grade.list("student", student);
    }

    @POST
    @Operation(summary = "Registrar calificación")
    public Response create(@PathParam("studentId") Long studentId, @Valid GradeInput input, @Context UriInfo uriInfo) {
        Student student = requireStudent(studentId);
        Grade grade = new Grade();
        grade.student = student;
        grade.courseCode = input.courseCode;
        grade.score = input.score;
        grade.term = input.term;
        grade.persist();
        URI location = uriInfo.getAbsolutePathBuilder().path(grade.id.toString()).build();
        return Response.created(location).entity(grade).build();
    }

    @GET
    @Path("/{gradeId}")
    @Operation(summary = "Obtener una calificación")
    public Grade get(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId) {
        requireStudent(studentId);
        Grade grade = Grade.findById(gradeId);
        if (grade == null || grade.student == null || !grade.student.id.equals(studentId)) {
            throw new NotFoundException("Grade not found");
        }
        return grade;
    }

    @PUT
    @Path("/{gradeId}")
    @Operation(summary = "Actualizar calificación")
    public Grade update(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId, @Valid GradeInput input) {
        Grade entity = get(studentId, gradeId);
        entity.courseCode = input.courseCode;
        entity.score = input.score;
        entity.term = input.term;
        return entity;
    }

    @DELETE
    @Path("/{gradeId}")
    @Operation(summary = "Eliminar calificación")
    public void delete(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId) {
        Grade entity = get(studentId, gradeId);
        entity.delete();
    }

    private static Student requireStudent(Long studentId) {
        Student student = Student.findById(studentId);
        if (student == null) {
            throw new NotFoundException("Student not found");
        }
        return student;
    }
}
