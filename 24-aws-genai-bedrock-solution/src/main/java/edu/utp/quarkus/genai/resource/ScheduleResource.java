package edu.utp.quarkus.genai.resource;

import edu.utp.quarkus.genai.dto.ScheduleRequest;
import edu.utp.quarkus.genai.dto.ScheduleResponse;
import edu.utp.quarkus.genai.model.Curso;
import edu.utp.quarkus.genai.service.BedrockService;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.util.List;

@Path("/genai/schedule")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ScheduleResource {

    @Inject
    BedrockService bedrockService;

    @Inject
    EntityManager em;

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
