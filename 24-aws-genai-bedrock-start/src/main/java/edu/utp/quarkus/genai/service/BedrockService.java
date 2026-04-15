package edu.utp.quarkus.genai.service;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;

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
        // TODO: Implementar la llamada a AWS Bedrock
        // 1. Construir el JSON del request usando objectMapper (Claude Messages API)
        //    - anthropic_version: "bedrock-2023-05-31"
        //    - max_tokens: 1024
        //    - system: SYSTEM_PROMPT
        //    - messages: [{role: "user", content: contexto + pregunta}]
        // 2. Crear InvokeModelRequest con modelId, contentType y body
        // 3. Llamar bedrockClient.invokeModel(request)
        // 4. Parsear la respuesta JSON y extraer content[0].text
        return "TODO: Implementar integración con Bedrock";
    }

    public String getModelId() {
        return modelId;
    }
}
