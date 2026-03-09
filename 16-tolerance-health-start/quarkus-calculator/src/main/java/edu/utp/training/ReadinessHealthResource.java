package edu.utp.training;


import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class ReadinessHealthResource {

    private final String HEALTH_CHECK_NAME = "Readiness";
}
