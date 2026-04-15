package edu.utp.quarkus.genai.resource;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasItems;
import static org.hamcrest.Matchers.is;
import org.junit.jupiter.api.Test;

import io.quarkus.test.junit.QuarkusTest;
import static io.restassured.RestAssured.given;

@QuarkusTest
class ScheduleResourceTest {

    @Test
    void testGetCiclos() {
        given()
            .when().get("/genai/schedule/ciclos")
            .then()
                .statusCode(200)
                .body("$", hasItems(1, 2, 3, 4));
    }

    @Test
    void testGetCursosByCiclo() {
        given()
            .when().get("/genai/schedule/cursos/1")
            .then()
                .statusCode(200)
                .body("size()", is(4))
                .body("nombre", hasItem("Introducción a la Programación"))
                .body("codigo", hasItem("IS101"));
    }

    @Test
    void testGetCursosByCiclo3() {
        given()
            .when().get("/genai/schedule/cursos/3")
            .then()
                .statusCode(200)
                .body("size()", is(4))
                .body("nombre", hasItem("Algoritmos"))
                .body("nombre", hasItem("Base de Datos I"));
    }

    @Test
    void testGetCursosEmptyCiclo() {
        given()
            .when().get("/genai/schedule/cursos/99")
            .then()
                .statusCode(200)
                .body("size()", is(0));
    }
}
