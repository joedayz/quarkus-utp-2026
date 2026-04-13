package edu.utp.quarkus.student;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class StudentApiTest {

    @Test
    void crudStudentAndGrades() {
        int createdId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {"code":"T-001","fullName":"Test User","email":"test@utp.edu.pe","career":"IS"}
                        """)
                .when().post("/students")
                .then()
                .statusCode(201)
                .body("id", not(empty()))
                .extract().path("id");

        given()
                .when().get("/students/" + createdId)
                .then()
                .statusCode(200)
                .body("code", is("T-001"));

        given()
                .when().get("/students/" + createdId + "/grades")
                .then()
                .statusCode(200)
                .body("size()", is(0));

        int gradeId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {"courseCode":"CS999","score":18.5,"term":"2026-1"}
                        """)
                .when().post("/students/" + createdId + "/grades")
                .then()
                .statusCode(201)
                .extract().path("id");

        given()
                .when().get("/students/" + createdId + "/grades/" + gradeId)
                .then()
                .statusCode(200)
                .body("score", is(18.5F));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {"courseCode":"CS999","score":19.0,"term":"2026-1"}
                        """)
                .when().put("/students/" + createdId + "/grades/" + gradeId)
                .then()
                .statusCode(200)
                .body("score", is(19.0F));

        given()
                .when().delete("/students/" + createdId + "/grades/" + gradeId)
                .then()
                .statusCode(204);

        given()
                .when().delete("/students/" + createdId)
                .then()
                .statusCode(204);

        given()
                .when().get("/students/" + createdId)
                .then()
                .statusCode(404);
    }
}
