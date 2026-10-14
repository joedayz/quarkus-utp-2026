# LAB 1: SETUP

**Autor:** José Díaz

## 1. Crear un directorio para crear nuestro primer proyecto Quarkus

### Linux/Mac

```bash
mkdir start-setup
```

### Windows (CMD)

```cmd
mkdir start-setup
```

### Windows (PowerShell)

```powershell
New-Item -ItemType Directory -Name start-setup
```

## 2. Crear una aplicación Quarkus usando el comando maven:

### Linux/Mac

```bash
mvn io.quarkus:quarkus-maven-plugin:3.40.1:create \
  -DprojectGroupId=edu.utp.training \
  -DprojectArtifactId=tenther \
  -DplatformVersion=3.40.1 \
  -Dextensions="quarkus-rest"
```

### Windows (CMD)

```cmd
mvn io.quarkus:quarkus-maven-plugin:3.40.1:create ^
  -DprojectGroupId=edu.utp.training ^
  -DprojectArtifactId=tenther ^
  -DplatformVersion=3.40.1 ^
  -Dextensions="quarkus-rest"
```

### Windows (PowerShell)

```powershell
mvn io.quarkus:quarkus-maven-plugin:3.40.1:create `
  -DprojectGroupId=edu.utp.training `
  -DprojectArtifactId=tenther `
  -DplatformVersion=3.40.1 `
  -Dextensions="quarkus-rest"
```

**Alternativa (una sola línea para Windows):**

```cmd
mvn io.quarkus:quarkus-maven-plugin:3.40.1:create -DprojectGroupId=edu.utp.training -DprojectArtifactId=tenther -DplatformVersion=3.40.1 -Dextensions="quarkus-rest"
```

## 3. Navegar al directorio del proyecto

### Linux/Mac/Windows

```bash
cd tenther
```

## 4. Ejecutar la aplicación en modo desarrollo

### Linux/Mac/Windows

```bash
mvn quarkus:dev
```

**O usando el wrapper de Maven (si está disponible):**

```bash
# Linux/Mac
./mvnw quarkus:dev

# Windows (CMD)
mvnw.cmd quarkus:dev

# Windows (PowerShell)
.\mvnw.cmd quarkus:dev
```

Deberíamos obtener el siguiente resultado:

[La aplicación debería iniciarse correctamente]

## 5. Invocar la aplicación

### Curl

```bash
curl http://localhost:8080/hello
```

### Powershell

```powershell
Invoke-WebRequest http://localhost:8080/hello
```

**Respuesta esperada:**

```
Hello from Quarkus REST
```

## 6. Cambiar el archivo de ejemplo `edu.utp.training.GreetingResource`

**NOTA:** Cambiar el `@Path("/hello")` a `@Path("/tenther")`

### Antes:

```java
@GET
@Produces(MediaType.TEXT_PLAIN)
public String hello() {
    return "Hello from Quarkus REST";
}
```

### Ahora:

```java
@GET
@Path("/{number}")
@Produces(MediaType.TEXT_PLAIN)
public String multiply(
    @PathParam("number") Integer number
) {
    return String.valueOf(number * 10);
}
```

**NOTA:** No agregar `+ "\n"` al final del `return`. El endpoint devuelve texto plano (`TEXT_PLAIN`), y un salto de línea extra solo complica las aserciones en los tests (ver paso 8).

## 7. Probar la nueva funcionalidad

```bash
curl http://localhost:8080/tenther/7
```

**Respuesta esperada:**

```
70
```

## 8. Actualizar el test `edu.utp.training.GreetingResourceTest`

Al cambiar el recurso en el paso 6, el test generado por defecto (que probaba `/hello` esperando el texto `"Hello from Quarkus REST"`) queda desactualizado y debe adaptarse al nuevo endpoint `/tenther/{number}`.

**NOTA:** La respuesta del endpoint es un `String` (por el `@Produces(MediaType.TEXT_PLAIN)`), así que el matcher de REST Assured debe comparar contra un `String` (`is("40")`), **no** contra un número (`is(40)`). Un `Integer` nunca es igual (`equals`) a un `String`, aunque representen el mismo valor, por lo que usar `is(40)` siempre falla con un error como `Expected: is <40>  Actual: 40`.

### Antes:

```java
package edu.utp.training;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
class GreetingResourceTest {
    @Test
    void testHelloEndpoint() {
        given()
          .when().get("/hello")
          .then()
             .statusCode(200)
             .body(is("Hello from Quarkus REST"));
    }

}
```

### Ahora:

```java
package edu.utp.training;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
class GreetingResourceTest {
    @Test
    void testHelloEndpoint() {
        given()
          .when().get("/tenther/4")
          .then()
             .statusCode(200)
             .body(is("40"));
    }

}
```

**Nota:** La clase `GreetingResourceIT` (usada para los tests en modo nativo/empaquetado) extiende `GreetingResourceTest`, por lo que no necesita cambios adicionales; hereda automáticamente este test corregido.

### Ejecutar el test

```bash
mvn test
```

**Resultado esperado:**

```
Tests run: 1, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

## 9. Detener la aplicación

Para detener la aplicación, presionar la letra "q" o `Ctrl+c`.

