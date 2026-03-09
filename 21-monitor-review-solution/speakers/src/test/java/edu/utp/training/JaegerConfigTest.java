package edu.utp.training;


import static edu.utp.training.ConfigTestUtils.getConfigProperty;
import static edu.utp.training.ConfigTestUtils.testConfigValueEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import org.junit.jupiter.api.Test;

import io.quarkus.test.junit.QuarkusTest;


@QuarkusTest
public class JaegerConfigTest {

    @Test
    public void testOtelServiceName() {
        String traceName = getConfigProperty( "quarkus.otel.service.name" );
        assertNotNull( traceName, "quarkus.otel.service.name must be set" );
    }

    @Test
    public void testOtelTracesSampler() {
        testConfigValueEquals( "quarkus.otel.traces.sampler", "traceidratio" );
    }

    @Test
    public void testOtelTracesSamplerArg() {
        testConfigValueEquals( "quarkus.otel.traces.sampler.arg", "1" );
    }

    @Test
    public void testOtelExporterEndpoint() {
        testConfigValueEquals( "quarkus.otel.exporter.otlp.traces.endpoint", "http://localhost:4317" );
    }

}
