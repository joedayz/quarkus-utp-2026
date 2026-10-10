package edu.utp.quarkus.whatsnew.resource;

import edu.utp.quarkus.whatsnew.ai.CourseAdvisor;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/advisor")
@Produces(MediaType.TEXT_PLAIN)
@Consumes(MediaType.TEXT_PLAIN)
public class CourseAdvisorResource {

    @Inject
    CourseAdvisor courseAdvisor;

    @POST
    @Path("/recommend")
    public String recommend(String interes) {
        return courseAdvisor.recomendarModulo(interes);
    }
}
