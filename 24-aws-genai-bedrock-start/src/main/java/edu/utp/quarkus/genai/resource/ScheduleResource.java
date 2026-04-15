package edu.utp.quarkus.genai.resource;

import java.util.List;

import edu.utp.quarkus.genai.dto.ScheduleRequest;
import edu.utp.quarkus.genai.dto.ScheduleResponse;
import edu.utp.quarkus.genai.model.Curso;
import edu.utp.quarkus.genai.service.BedrockService;
import jakarta.persistence.EntityManager;

// TODO: Agregar anotaciones JAX-RS: @Path, @Produces, @Consumes
public class ScheduleResource {

    // TODO: Inyectar BedrockService con @Inject
    BedrockService bedrockService;

    // TODO: Inyectar EntityManager con @Inject
    EntityManager em;

    // TODO: Agregar anotación @POST
    public ScheduleResponse askSchedule(ScheduleRequest request) {
        // TODO: Implementar lógica del endpoint
        // 1. Si request.ciclo() != null, buscar cursos por ciclo; si no, traer todos
        // 2. Formatear cursos como contexto con formatCursosAsContext()
        // 3. Llamar bedrockService.ask(question, context)
        // 4. Retornar ScheduleResponse con question, answer, model y cantidad de cursos
        return null;
    }

    // TODO: Agregar anotaciones @GET y @Path("/ciclos")
    public List<Integer> getCiclos() {
        // TODO: Consultar ciclos distintos usando EntityManager
        return List.of();
    }

    // TODO: Agregar anotaciones @GET y @Path("/cursos/{ciclo}")
    public List<Curso> getCursosByCiclo(int ciclo) {
        // TODO: Retornar cursos del ciclo indicado
        return List.of();
    }

    private String formatCursosAsContext(List<Curso> cursos) {
        if (cursos.isEmpty()) {
            return "No se encontraron cursos para los criterios especificados.";
        }

        StringBuilder sb = new StringBuilder();
        sb.append("| Ciclo | Código | Curso | Profesor | Día | Hora Inicio | Hora Fin | Aula |\n");
        sb.append("|-------|--------|-------|----------|-----|-------------|----------|------|\n");

        for (Curso c : cursos) {
            sb.append("| %d | %s | %s | %s | %s | %s | %s | %s |\n".formatted(
                    c.ciclo, c.codigo, c.nombre, c.profesor, c.dia, c.horaInicio, c.horaFin, c.aula));
        }

        return sb.toString();
    }
}
