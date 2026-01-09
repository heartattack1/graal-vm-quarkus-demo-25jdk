package com.example.quarkusdemojdk25;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.time.Instant;
import java.util.Map;

@Path("/hello")
public class GreetingResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> hello() {
        return Map.of(
                "message", "hello",
                "ts", Instant.now().toString()
        );
    }
}
