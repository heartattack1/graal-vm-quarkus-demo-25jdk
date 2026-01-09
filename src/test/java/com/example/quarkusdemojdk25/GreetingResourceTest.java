package com.example.quarkusdemojdk25;


import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@QuarkusTest
class GreetingResourceTest {

    @Test
    void hello() {
        given()
                .when().get("/hello")
                .then()
                .statusCode(200)
                .body("message", is("hello"))
                .body("ts", notNullValue());
    }
}
