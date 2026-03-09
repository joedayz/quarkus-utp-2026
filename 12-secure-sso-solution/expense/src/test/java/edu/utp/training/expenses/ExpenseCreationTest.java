package edu.utp.training.expenses;

import org.junit.jupiter.api.Test;
import io.restassured.http.ContentType;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.common.http.TestHTTPEndpoint;


import static io.restassured.RestAssured.given;
import static io.restassured.RestAssured.when;
import static org.hamcrest.CoreMatchers.containsString;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
@TestHTTPEndpoint( TestExpenseResource.class )
public class ExpenseCreationTest {

    @Test
    public void testCreateExpense() {
        given()
                .body( Expense.of( "Test Expense", Expense.PaymentMethod.CASH, "2" ) )
                .contentType( ContentType.JSON )
                .post();

        when()
                .get()
                .then()
                .statusCode( 200 )
                .assertThat()
                .body( "size()", is( 4 ) )
                .body(
                        containsString( "\"name\":\"Test Expense\"" ),
                        containsString( "\"paymentMethod\":\"" + Expense.PaymentMethod.CASH + "\"" ),
                        containsString( "\"amount\":2.0" ) );

    }

}