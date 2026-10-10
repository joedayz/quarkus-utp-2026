package edu.utp.quarkus.whatsnew.ai;

import dev.langchain4j.service.SystemMessage;
import dev.langchain4j.service.UserMessage;
import io.quarkiverse.langchain4j.RegisterAiService;

/**
 * Servicio de IA declarativo respaldado por AWS Bedrock a traves de
 * Quarkus LangChain4j, actualizado a la version 1.13.3 en la plataforma 3.40.
 *
 * Reutiliza el mismo modelo (Claude 3 Haiku) y la misma cuenta/region de AWS
 * que el modulo 24-aws-genai-bedrock, pero mediante la abstraccion @RegisterAiService
 * en lugar de invocar el SDK de Bedrock manualmente.
 */
@RegisterAiService
public interface CourseAdvisor {

    @SystemMessage("""
            Eres un asesor academico del curso 'Microservicios cloud-native con Quarkus en AWS'.
            Responde en espanol, en maximo 3 frases, recomendando en que modulo del curso
            (identificado por su numero y nombre de carpeta) el estudiante deberia enfocarse
            segun su interes.
            """)
    @UserMessage("Mi interes es: {interes}")
    String recomendarModulo(String interes);
}
