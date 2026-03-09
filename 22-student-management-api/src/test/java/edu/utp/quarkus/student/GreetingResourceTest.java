package edu.utp.quarkus.student;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.hasItems;

@QuarkusTest
class GreetingResourceTest {
    @Test
    void shouldListStudents() {
        given()
          .when().get("/students")
          .then()
             .statusCode(200)
             .body("code", hasItems());
    }

}