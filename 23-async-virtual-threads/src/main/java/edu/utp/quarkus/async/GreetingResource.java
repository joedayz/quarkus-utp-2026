package edu.utp.quarkus.async;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.time.Duration;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Path("/async")
public class GreetingResource {

    // Virtual threads require Java 21 with --enable-preview if not GA in the runtime used.
    private static final ExecutorService VIRTUAL_EXECUTOR = Executors.newVirtualThreadPerTaskExecutor();

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String simulateAsyncCall() {
        CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
            try {
                Thread.sleep(Duration.ofSeconds(1).toMillis());
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            return "Async response from virtual thread\n";
        }, VIRTUAL_EXECUTOR);

        return future.join();
    }
}

