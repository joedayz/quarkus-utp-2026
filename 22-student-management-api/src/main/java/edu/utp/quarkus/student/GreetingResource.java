package edu.utp.quarkus.student;

import jakarta.transaction.Transactional;
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

import java.net.URI;
import java.util.List;

@Path("/students")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Transactional
public class GreetingResource {

    @GET
    public List<Student> list() {
        return Student.listAll();
    }

    @POST
    public Response create(Student student, @Context UriInfo uriInfo) {
        student.persist();
        URI location = uriInfo.getAbsolutePathBuilder().path(student.id.toString()).build();
        return Response.created(location).entity(student).build();
    }

    @GET
    @Path("/{id}")
    public Student get(@PathParam("id") Long id) {
        return Student.<Student>findByIdOptional(id)
                .orElseThrow(() -> new NotFoundException("Student not found"));
    }

    @PUT
    @Path("/{id}")
    public Student update(@PathParam("id") Long id, Student updated) {
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
    public void delete(@PathParam("id") Long id) {
        boolean deleted = Student.deleteById(id);
        if (!deleted) {
            throw new NotFoundException("Student not found");
        }
    }
}

