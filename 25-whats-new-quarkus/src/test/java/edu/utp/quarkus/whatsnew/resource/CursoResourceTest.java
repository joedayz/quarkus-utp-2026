package edu.utp.quarkus.whatsnew.resource;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
class CursoResourceTest {

    @Test
    void listarCursosDesdeElCatalogoSembrado() {
        given()
                .when().get("/cursos")
                .then()
                .statusCode(200)
                .body("size()", is(4));
    }

    @Test
    void buscarPorIdUsaLaCacheL2EnLlamadasRepetidas() {
        given()
                .when().get("/cursos/1")
                .then()
                .statusCode(200)
                .body("nombre", is("MicroProfile Config"));

        // Segunda llamada: con second-level-caching-enabled, Hibernate ORM resuelve
        // esta entidad desde la cache Caffeine de la region "cursos" sin volver a
        // consultar H2 (visible en los logs de SQL habilitados en application.properties).
        given()
                .when().get("/cursos/1")
                .then()
                .statusCode(200)
                .body("nombre", is("MicroProfile Config"));
    }

    @Test
    void retornar404ParaCursoInexistente() {
        given()
                .when().get("/cursos/999")
                .then()
                .statusCode(404);
    }
}
