package edu.utp.training.expenses;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.QueryParam;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@Path("/score")
@ApplicationScoped
@RegisterRestClient
public interface FraudScoreService {
    @GET
    FraudScore getByAmount(@QueryParam("amount") double amount);
}
