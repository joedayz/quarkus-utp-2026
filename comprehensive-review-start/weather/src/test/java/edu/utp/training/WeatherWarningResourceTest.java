package edu.utp.training;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;

@QuarkusTest
public class WeatherWarningResourceTest {

    @Test
    public void testWarningsEndpoint() {
        given()
                .when().get("/warnings")
                .then()
                .statusCode(200);
    }

}