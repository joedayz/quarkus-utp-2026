package edu.utp.training;

import io.smallrye.mutiny.Uni;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;

@Path( "/" )
@RegisterRestClient
public interface PricesService {

    @GET
    @Path( "/history/{productId}" )
    Uni<ProductPriceHistory> getProductPriceHistory(@PathParam( "productId" ) final Long productId );
}