package edu.utp.training;


import edu.utp.training.service.MultiplierService;
import edu.utp.training.service.SolverService;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

public class MultiplierResource implements MultiplierService {
    final Logger log = LoggerFactory.getLogger(MultiplierResource.class);

    @Inject
    @RestClient
    SolverService solverService;

    @GET
    @Path("/{lhs}/{rhs}")
    @Produces(MediaType.TEXT_PLAIN)
    public Float multiply(@PathParam("lhs") String lhs, @PathParam("rhs") String rhs) {
        log.info("Multiplying {} to {}" ,lhs, rhs);
        return solverService.solve(lhs)*solverService.solve(rhs);
    }
}