# LAB 24: ASISTENTE DE HORARIOS UTP CON QUARKUS + AWS BEDROCK

**Autor:** José Díaz  
**Github Repo:** https://github.com/joedayz/quarkus-utp-2026.git

## Objetivo

Construir un asistente inteligente de consulta de horarios universitarios que combine:
- **Quarkus REST** para los endpoints
- **Hibernate ORM Panache + H2** para la base de datos de horarios
- **AWS Bedrock (Claude 3 Haiku)** para respuestas en lenguaje natural

El flujo es: el estudiante hace una pregunta → se consultan los horarios en H2 → se inyectan como contexto a Claude → Claude responde en lenguaje natural.

## Prerrequisitos

- Java 21
- Maven 3.9+
- Credenciales AWS configuradas (`~/.aws/credentials`) con acceso a **Amazon Bedrock** en la región `us-east-1`
- Acceso habilitado al modelo **Anthropic Claude 3 Haiku** en la consola de AWS Bedrock

## 1. Cargar en su IDE el proyecto `24-aws-genai-bedrock-start`

Examina la estructura del proyecto. Ya cuenta con:
- `pom.xml` con todas las dependencias configuradas
- Entidad `Curso.java` con los campos definidos (pero sin finder methods)
- `import.sql` con 16 cursos de Ingeniería de Software (4 ciclos)
- `application.properties` con la configuración de H2 (Bedrock está pendiente)
- `BedrockService.java` con la estructura base (método `ask()` pendiente)
- `ScheduleResource.java` con los endpoints pendientes
- `index.html` con la interfaz web lista

## 2. Configurar `application.properties` — sección AWS Bedrock

Abre `src/main/resources/application.properties` y completa la configuración de Bedrock:

```properties
# AWS Bedrock Runtime
quarkus.bedrockruntime.aws.region=us-east-1
quarkus.bedrockruntime.aws.credentials.type=default
quarkus.bedrockruntime.devservices.enabled=false

# Modelo de Bedrock (Claude 3 Haiku - economico y rapido para demos)
bedrock.model-id=anthropic.claude-3-haiku-20240307-v1:0
```

**Nota:** La propiedad `bedrock.model-id` es una propiedad custom que inyectamos con `@ConfigProperty`.

## 3. Implementar los finder methods en `Curso.java`

Abre `src/main/java/edu/utp/quarkus/genai/model/Curso.java`.

La entidad ya extiende `PanacheEntity`, lo que nos da acceso a métodos estáticos como `list()`, `find()`, `listAll()`, etc.

Implementa los tres finder methods usando el Active Record Pattern de Panache:

```java
public static List<Curso> findByCiclo(int ciclo) {
    return list("ciclo", ciclo);
}

public static List<Curso> findByDia(String dia) {
    return list("dia", dia);
}

public static List<Curso> findByCicloAndDia(int ciclo, String dia) {
    return list("ciclo = ?1 and dia = ?2", ciclo, dia);
}
```

**Nota:** `list("ciclo", ciclo)` es equivalente a `list("ciclo = ?1", ciclo)`. Panache infiere el operador `=` cuando solo se pasa el nombre del campo.

## 4. Implementar el método `ask()` en `BedrockService.java`

Abre `src/main/java/edu/utp/quarkus/genai/service/BedrockService.java`.

El servicio ya tiene inyectados el `BedrockRuntimeClient`, `ObjectMapper` y el `modelId`. Debes implementar el método `ask()` que:

1. Construye el request JSON siguiendo la **Claude Messages API**
2. Invoca el modelo vía `BedrockRuntimeClient`
3. Parsea la respuesta

```java
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
```

Agrega los imports necesarios:

```java
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelRequest;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelResponse;
```

**Puntos clave:**
- `anthropic_version: "bedrock-2023-05-31"` es obligatorio para Claude en Bedrock
- El `system` prompt va como campo top-level (no como mensaje)
- El contexto de horarios se inyecta dentro del contenido del mensaje del usuario

## 5. Agregar anotaciones JAX-RS al `ScheduleResource.java`

Abre `src/main/java/edu/utp/quarkus/genai/resource/ScheduleResource.java`.

### 5.1. Agrega los imports y anotaciones de clase

```java
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/genai/schedule")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ScheduleResource {
```

### 5.2. Agrega `@Inject` a los campos

```java
@Inject
BedrockService bedrockService;

@Inject
EntityManager em;
```

### 5.3. Implementa el endpoint POST `askSchedule`

```java
@POST
public ScheduleResponse askSchedule(ScheduleRequest request) {
    List<Curso> cursos;
    if (request.ciclo() != null) {
        cursos = Curso.findByCiclo(request.ciclo());
    } else {
        cursos = Curso.listAll();
    }

    String context = formatCursosAsContext(cursos);
    String answer = bedrockService.ask(request.question(), context);

    return new ScheduleResponse(
            request.question(),
            answer,
            bedrockService.getModelId(),
            cursos.size()
    );
}
```

### 5.4. Implementa los endpoints GET

```java
@GET
@Path("/ciclos")
public List<Integer> getCiclos() {
    return em.createQuery("SELECT DISTINCT c.ciclo FROM Curso c ORDER BY c.ciclo", Integer.class)
            .getResultList();
}

@GET
@Path("/cursos/{ciclo}")
public List<Curso> getCursosByCiclo(@PathParam("ciclo") int ciclo) {
    return Curso.findByCiclo(ciclo);
}
```

**Nota:** Usamos `EntityManager` directamente para obtener los ciclos distintos porque Panache no soporta proyecciones a tipos escalares como `Integer`.

## 6. Verificar que compila

### Linux/Mac

```bash
./mvnw compile
```

### Windows

```cmd
mvnw.cmd compile
```

Si hay errores de compilación, revisa los imports y las anotaciones.

## 7. Ejecutar la aplicación

### Linux/Mac

```bash
./mvnw quarkus:dev
```

### Windows

```cmd
mvnw.cmd quarkus:dev
```

La aplicación se inicia en `http://localhost:8080`.

## 8. Probar los endpoints REST

Abre otra terminal y prueba los endpoints:

### 8.1. Obtener los ciclos disponibles

```bash
curl -s http://localhost:8080/genai/schedule/ciclos | python3 -m json.tool
```

**Salida esperada:**

```json
[1, 2, 3, 4]
```

### 8.2. Obtener cursos del ciclo 1

```bash
curl -s http://localhost:8080/genai/schedule/cursos/1 | python3 -m json.tool
```

**Salida esperada:**

```json
[
    {
        "id": 1,
        "nombre": "Introducción a la Programación",
        "codigo": "IS101",
        "ciclo": 1,
        "profesor": "Dr. Carlos Mendoza",
        "dia": "Lunes",
        "horaInicio": "08:00",
        "horaFin": "10:00",
        "aula": "A-201"
    },
    ...
]
```

### 8.3. Hacer una pregunta al asistente

```bash
curl -s -X POST http://localhost:8080/genai/schedule \
  -H "Content-Type: application/json" \
  -d '{"question": "¿Qué cursos tengo los lunes en ciclo 1?", "ciclo": 1}' \
  | python3 -m json.tool
```

**Salida esperada (ejemplo):**

```json
{
    "question": "¿Qué cursos tengo los lunes en ciclo 1?",
    "answer": "Los lunes en el ciclo 1 tienes el siguiente curso:\n\n- **Introducción a la Programación** (IS101)\n  - Profesor: Dr. Carlos Mendoza\n  - Horario: 08:00 - 10:00\n  - Aula: A-201",
    "model": "anthropic.claude-3-haiku-20240307-v1:0",
    "cursosConsultados": 4
}
```

**Nota:** La respuesta de Claude varía en cada invocación, pero siempre estará basada en los datos de `import.sql`.

## 9. Probar la interfaz web

Abre `http://localhost:8080` en el navegador.

1. Selecciona un ciclo (1–4) o deja "Todos los ciclos"
2. Haz clic en una de las preguntas de ejemplo o escribe tu propia pregunta
3. Presiona "Consultar" y observa la respuesta del asistente

## 10. Experimentar con diferentes preguntas

Prueba preguntas como:
- "¿Qué profesor dicta Base de Datos I?"
- "¿Cuántos cursos tiene el ciclo 3?"
- "¿Hay clases los sábados?"
- "¿En qué aula es Redes de Computadoras?"

Observa cómo Claude usa SOLO los datos proporcionados y responde que no tiene información cuando la pregunta está fuera del contexto.

---

**Enjoy!**

**Joe**
