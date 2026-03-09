# LAB 8: QUARKUS DEV SERVICES

**Autor:** José Díaz  
**Github Repo:** https://github.com/joedayz/quarkus-utp-2026.git

## 1. Abre el proyecto test-devservices

Navega al directorio del proyecto:

### Linux/Mac/Windows

```bash
cd expense-service
```

## 2. Crea una anotación personalizada para ejecutar una base de datos PostgreSQL

Crea el archivo `src/test/java/com/utp/training/rest/WithPostgresDB.java`.

La interfaz de anotación debe tener tres parámetros de tipo String: `name`, `username` y `password`.

El objetivo de esta anotación es cualquier tipo de Java, y debe tener retención en tiempo de ejecución.

La anotación debe lucir como el siguiente código:

```java
package edu.utp.training.rest;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface WithPostgresDB {
    String username() default "";
    String password() default "";
    String name() default "";
}
```

## 3. Crea la clase de recurso de prueba para PostgreSQL

### 3.1. Crea el archivo `src/test/java/com/utp/training/rest/PostgresDBTestResource.java`

### 3.2. La clase de recurso de prueba debe implementar la interfaz `QuarkusTestResourceConfigurableLifecycleManager`

### 3.3. Debe usar la anotación `WithPostgresDB` como parámetro genérico para esta interfaz

```java
package edu.utp.training.rest;

import io.quarkus.test.common.QuarkusTestResourceConfigurableLifecycleManager;

public class PostgresDBTestResource implements 
        QuarkusTestResourceConfigurableLifecycleManager<WithPostgresDB> {
}
```

## 4. Agrega el código para capturar los parámetros de la anotación y establecerlos en los campos de la clase

Agrega los campos privados y el método `init`:

```java
package edu.utp.training.rest;

import io.quarkus.test.common.QuarkusTestResourceConfigurableLifecycleManager;

public class PostgresDBTestResource implements 
        QuarkusTestResourceConfigurableLifecycleManager<WithPostgresDB> {
    
    private String name;
    private String username;
    private String password;

    @Override
    public void init(WithPostgresDB params) {
        username = params.username();
        password = params.password();
        name = params.name();
    }
}
```

## 5. Agrega el campo del contenedor de base de datos PostgreSQL de Testcontainers a la clase de recurso

Agrega los imports necesarios y el campo del contenedor:

```java
package edu.utp.training.rest;

import io.quarkus.test.common.QuarkusTestResourceConfigurableLifecycleManager;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

public class PostgresDBTestResource implements 
        QuarkusTestResourceConfigurableLifecycleManager<WithPostgresDB> {
    
    private static final DockerImageName imageName = 
        DockerImageName.parse("postgres:14.1")
            .asCompatibleSubstituteFor("postgres");
    
    private static final PostgreSQLContainer<?> DATABASE = 
        new PostgreSQLContainer<>(imageName);
    
    private String name;
    private String username;
    private String password;

    @Override
    public void init(WithPostgresDB params) {
        username = params.username();
        password = params.password();
        name = params.name();
    }
}
```

## 6. Agrega el código que inicia el contenedor de base de datos y establece las propiedades del datasource en el evento start del recurso

Implementa el método `start()`:

```java
@Override
public Map<String, String> start() {
    DATABASE.withDatabaseName(name)
            .withUsername(username)
            .withPassword(password)
            .start();
    
    return Map.of(
        "quarkus.datasource.username", username,
        "quarkus.datasource.password", password,
        "quarkus.datasource.jdbc.url", DATABASE.getJdbcUrl()
    );
}
```

**NOTA:** Asegúrate de agregar el import para `Map`:

```java
import java.util.Map;
```

## 7. Agrega el código que detenga el contenedor de la base de datos en el evento stop del recurso

Implementa el método `stop()`:

```java
@Override
public void stop() {
    DATABASE.stop();
}
```

### Código completo de PostgresDBTestResource

Al finalizar los pasos 5, 6 y 7, tu clase `PostgresDBTestResource.java` debe verse así:

```java
package edu.utp.training.rest;

import io.quarkus.test.common.QuarkusTestResourceConfigurableLifecycleManager;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.util.Map;

public class PostgresDBTestResource implements 
        QuarkusTestResourceConfigurableLifecycleManager<WithPostgresDB> {
    
    private static final DockerImageName imageName = 
        DockerImageName.parse("postgres:14.1")
            .asCompatibleSubstituteFor("postgres");
    
    private static final PostgreSQLContainer<?> DATABASE = 
        new PostgreSQLContainer<>(imageName);
    
    private String name;
    private String username;
    private String password;

    @Override
    public void init(WithPostgresDB params) {
        username = params.username();
        password = params.password();
        name = params.name();
    }

    @Override
    public Map<String, String> start() {
        DATABASE.withDatabaseName(name)
                .withUsername(username)
                .withPassword(password)
                .start();
        
        return Map.of(
            "quarkus.datasource.username", username,
            "quarkus.datasource.password", password,
            "quarkus.datasource.jdbc.url", DATABASE.getJdbcUrl()
        );
    }

    @Override
    public void stop() {
        DATABASE.stop();
    }
}
```

## 8. Anota la interfaz de anotación personalizada WithPostgresDB con @QuarkusTestResource

Pasa la clase recién creada `PostgresDBTestResource` como el parámetro por defecto y configura el parámetro `restrictToAnnotatedClass` en `true`.

Actualiza el archivo `WithPostgresDB.java`:

```java
package edu.utp.training.rest;

import io.quarkus.test.common.QuarkusTestResource;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@QuarkusTestResource(value = PostgresDBTestResource.class,
                     restrictToAnnotatedClass = true)
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface WithPostgresDB {
    String username() default "";
    String password() default "";
    String name() default "";
}
```

## 9. Anota la clase de prueba AssociateResourceTest con la anotación personalizada

Abre el archivo `src/test/java/com/utp/training/rest/AssociateResourceTest.java` y agrega la anotación `@WithPostgresDB` con los siguientes parámetros:

- `tc-test` → nombre de la base de datos
- `tc-user` → usuario
- `tc-pass` → contraseña

```java
package edu.utp.training.rest;

import io.quarkus.test.common.http.TestHTTPEndpoint;
import io.quarkus.test.junit.QuarkusTest;

import static io.restassured.RestAssured.given;
import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import edu.utp.training.model.Associate;

@QuarkusTest
@TestHTTPEndpoint(AssociateResource.class)
@WithPostgresDB(name = "tc-test", username = "tc-user", password = "tc-pass")
public class AssociateResourceTest {

    @Test
    public void testListAllEndpoint() {
        Associate[] associates = given()
                .when().get()
                .then()
                    .statusCode(200)
                    .extract()
                    .as(Associate[].class);
        assertThat(associates).hasSize(2);
    }
}
```

## 10. Ejecuta las pruebas para verificar que la base de datos está siendo desplegada por Testcontainers

### Linux/Mac

```bash
./mvnw test
```

### Windows (CMD)

```cmd
mvnw.cmd test
```

### Windows (PowerShell)

```powershell
.\mvnw.cmd test
```

**Salida esperada:**

Deberías ver en la salida del terminal algo como:

```
[INFO] TESTS
[INFO] Running edu.utp.training.rest.AssociateResourceTest
[# [postgres:15]] (pool-4-thread-1) Creating container for image: postgres:15
[# [postgres:15]] (pool-4-thread-1) Container postgres:15 is starting: 7a073...
[# [postgres:15]] (pool-4-thread-1) Container postgres:15 started in PT1.482541461S
[INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

**NOTA:** Si usas Podman en lugar de Docker, necesitas configurar Testcontainers para usar Podman:

### Linux/Mac

```bash
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
export DOCKER_HOST=unix:///var/run/docker.sock
./mvnw test
```

### Windows (PowerShell)

```powershell
$env:TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE="\\.\pipe\docker_engine"
$env:DOCKER_HOST="npipe:////./pipe/docker_engine"
.\mvnw.cmd test
```

## Resumen

En este laboratorio has aprendido a:

- ✅ Crear una anotación personalizada para recursos de prueba de Quarkus
- ✅ Implementar un recurso de prueba configurable con Testcontainers
- ✅ Configurar un contenedor PostgreSQL para pruebas
- ✅ Integrar Testcontainers con Quarkus Test Resources
- ✅ Usar anotaciones personalizadas para configurar recursos de prueba

**Beneficios de este enfoque:**

- 🧪 Contenedores de base de datos se crean automáticamente para cada prueba
- 🔄 Configuración flexible mediante anotaciones
- 🐳 Compatible con Docker y Podman
- ⚙️ Configuración automática de propiedades de datasource
- 🎯 Aislamiento completo entre pruebas

---

**Enjoy!**

**Joe**
