package edu.utp.quarkus.whatsnew.mcp;

import edu.utp.quarkus.whatsnew.model.Curso;
import edu.utp.quarkus.whatsnew.repository.CursoRepository;
import io.quarkiverse.mcp.server.Tool;
import io.quarkiverse.mcp.server.ToolArg;
import jakarta.inject.Inject;

import java.util.List;

/**
 * Herramientas MCP (Model Context Protocol) sobre el catalogo de cursos.
 *
 * Quarkus MCP Server fue actualizado a la version 2.0.1 en la plataforma 3.40;
 * este bean CDI se registra automaticamente como servidor MCP ("quarkus-mcp-server-http")
 * y expone sus metodos anotados con @Tool a cualquier cliente MCP (por ejemplo,
 * un asistente de IA o un IDE compatible), sin necesidad de escribir el
 * boilerplate del protocolo.
 */
public class CursoMcpTools {

    @Inject
    CursoRepository cursoRepository;

    @Tool(description = "Lista todos los cursos disponibles en el catalogo del curso UTP")
    List<Curso> listarCursos() {
        return cursoRepository.listAll();
    }

    @Tool(description = "Busca un curso por coincidencia parcial en su nombre")
    Curso buscarCursoPorNombre(@ToolArg(description = "Texto a buscar en el nombre del curso") String nombre) {
        return cursoRepository.buscarPorNombre(nombre);
    }
}
