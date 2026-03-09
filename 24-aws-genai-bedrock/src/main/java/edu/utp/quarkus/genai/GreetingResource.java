package edu.utp.quarkus.genai;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.util.Map;

@Path("/genai")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class GreetingResource {

    @POST
    @Path("/prompt")
    public Map<String, String> prompt(Map<String, String> body) {
        String question = body.getOrDefault("question", "Hola desde Quarkus en AWS.");

        // Aquí iría la llamada real a AWS Bedrock (modelo fundacional) usando el SDK de AWS.
        // En el laboratorio los estudiantes reemplazarán esta simulación por una integración real.
        String fakeAnswer = "Respuesta generada para: " + question;

        return Map.of(
                "question", question,
                "answer", fakeAnswer
        );
    }
}

