package edu.utp.training;

import static edu.utp.training.ConfigTestUtils.getConfigProperty;
import static edu.utp.training.ConfigTestUtils.testConfigValueEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import org.junit.jupiter.api.Test;

import io.quarkus.test.junit.QuarkusTest;


@QuarkusTest
public class LoggingConfigTest {

    @Test
    public void testFormat() {
        String traceName = getConfigProperty( "%dev.quarkus.log.console.format" );
        assertNotNull( traceName, "%dev.quarkus.log.console.format must be set" );
    }

    @Test
    public void testJsonFormat() {
        testConfigValueEquals( "%dev.quarkus.log.console.json", "false" );
    }

    @Test
    public void testDebugLevel() {
        testConfigValueEquals( "%dev.quarkus.log.category.\"com.redhat.training\".level", "DEBUG" );
    }

}
