package edu.utp.quarkus.genai.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelRequest;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelResponse;

@ApplicationScoped
public class BedrockService {

    @Inject
    BedrockRuntimeClient bedrockClient;

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "bedrock.model-id", defaultValue = "anthropic.claude-3-haiku-20240307-v1:0")
    String modelId;

    private static final String SYSTEM_PROMPT = """
            Eres un asistente de consulta de horarios de la carrera de Ingeniería de Software \
            de la Universidad Tecnológica del Perú (UTP). \
            Responde de forma clara, amigable y concisa. \
            Responde SOLO con base en los datos de horarios proporcionados. \
            Si la información solicitada no está en los datos, indica que no tienes esa información. \
            Formatea las respuestas de manera legible usando listas cuando sea apropiado.""";

    public String ask(String question, String scheduleContext) {
        try {
            ObjectNode requestBody = objectMapper.createObjectNode();
            requestBody.put("anthropic_version", "bedrock-2023-05-31");
            requestBody.put("max_tokens", 1024);
            requestBody.put("system", SYSTEM_PROMPT);

            ArrayNode messages = requestBody.putArray("messages");
            ObjectNode userMessage = messages.addObject();
            userMessage.put("role", "user");

            String userContent = """
                    ## Datos de horarios disponibles:
                    %s

                    ## Pregunta del estudiante:
                    %s""".formatted(scheduleContext, question);

            userMessage.put("content", userContent);

            String requestJson = objectMapper.writeValueAsString(requestBody);

            InvokeModelRequest invokeRequest = InvokeModelRequest.builder()
                    .modelId(modelId)
                    .contentType("application/json")
                    .accept("application/json")
                    .body(SdkBytes.fromUtf8String(requestJson))
                    .build();

            InvokeModelResponse response = bedrockClient.invokeModel(invokeRequest);
            String responseJson = response.body().asUtf8String();

            JsonNode responseNode = objectMapper.readTree(responseJson);
            JsonNode contentArray = responseNode.get("content");
            if (contentArray != null && contentArray.isArray() && !contentArray.isEmpty()) {
                return contentArray.get(0).get("text").asText();
            }

            return "No se pudo obtener una respuesta del modelo.";
        } catch (Exception e) {
            return "Error al consultar el modelo: " + e.getMessage();
        }
    }

    public String getModelId() {
        return modelId;
    }
}
