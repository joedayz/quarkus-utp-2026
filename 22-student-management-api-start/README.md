# 22-student-management-api-start (plantilla del laboratorio)

Carpeta **START**: implementación **tuya** en local; la **solución de referencia** está en [`../22-student-management-api-solution/`](../22-student-management-api-solution/).

## Qué incluye esta plantilla

| Contenido | Rol |
|-----------|-----|
| `pom.xml`, `mvnw`, Dockerfiles | Mismo stack Quarkus 3.32 que la solution |
| `Student.java`, `Grade.java`, `GradeInput.java` | Modelo JPA y DTO listos |
| `StudentResource.java`, `GradeResource.java` | **Stubs** (`UnsupportedOperationException`): los sustituyes con el código de abajo |
| `StudentApiTest.java` | En el repo va **solo el primer test** (paso 6a); el segundo lo añades en el paso 6b |
| `application.properties` | En el repo va solo el **paso 1**; los pasos 2 y 3 los pegas desde abajo |

**Estado inicial del repo:** ya tienes el **Paso 1** en `application.properties` y el **Paso 6a** en `StudentApiTest`. Los recursos siguen en **stub** hasta que pegues los pasos 4 y 5. Orden típico: pasos **2 → 3** (properties), **4 → 5** (API), `./mvnw test` (debe pasar 1 test), **6b** (segundo test), otra vez `./mvnw test` (2 tests).

## Contrato REST (resumen)

| Método | Ruta | Comportamiento esperado (tests) |
|--------|------|----------------------------------|
| GET | `/students` | Lista JSON |
| POST | `/students` | Crea, **201** + `Location` |
| GET | `/students/{id}` | **200** o **404** |
| PUT | `/students/{id}` | Actualiza |
| DELETE | `/students/{id}` | Borra; GET siguiente **404** |
| GET | `/students/{id}/grades` | Lista (vacía al inicio) |
| POST | `/students/{id}/grades` | Crea nota; score 0–20 o **400** |
| GET/PUT/DELETE | `/students/{id}/grades/{gradeId}` | CRUD de nota |

---

## Guía paso a paso — copiar y pegar

**Requisitos:** Java **21**, Docker activo (Dev Services). Orden recomendado:

| Paso | Archivo | Qué haces |
|------|---------|-----------|
| 1 | `src/main/resources/application.properties` | **Reemplaza** el archivo por el bloque *base* |
| 2 | mismo | **Añade al final** el bloque *OpenAPI / métricas / trazas* |
| 3 | mismo | **Añade al final** el bloque *prod* (antes de copiar a **solution** / AWS) |
| 4 | `StudentResource.java` | **Reemplaza** el stub completo |
| 5 | `GradeResource.java` | **Reemplaza** el stub completo |
| 6a | `StudentApiTest.java` | **Reemplaza** por la clase con **un** test |
| 6b | mismo | **Añade** el segundo método `@Test` antes del `}` final de la clase |
| ✓ | — | `./mvnw test` (deben pasar los dos tests) |

Tras los pasos **2–5** (y con el paso 1 ya en el repo), ejecuta `./mvnw test`: debe pasar el **único** test del archivo. Tras **6b**, pasan **dos** tests.

---

### Paso 1 — `application.properties` (base: nombre, Postgres, Dev Services, tests)

**Ruta:** `src/main/resources/application.properties` — **borra lo anterior** y pega:

```properties
quarkus.application.name=student-management-api

quarkus.datasource.db-kind=postgresql
quarkus.datasource.username=student
quarkus.datasource.password=student

%dev.quarkus.datasource.devservices.enabled=true
%dev.quarkus.hibernate-orm.database.generation=update
%dev.quarkus.hibernate-orm.log.sql=true

%test.quarkus.datasource.devservices.enabled=true
%test.quarkus.hibernate-orm.database.generation=drop-and-create
```

Comprueba: `./mvnw quarkus:dev` (aún sin Swagger hasta el paso 2).

---

### Paso 2 — `application.properties` (añade **al final** del mismo archivo)

```properties
quarkus.smallrye-openapi.path=/openapi
quarkus.swagger-ui.always-include=true
quarkus.swagger-ui.path=/q/swagger-ui

mp.openapi.extensions.smallrye.info.title=Student Management API
mp.openapi.extensions.smallrye.info.version=1.0.0-SNAPSHOT
mp.openapi.extensions.smallrye.info.description=REST API de estudiantes y calificaciones (lab START).

quarkus.micrometer.export.prometheus.enabled=true
quarkus.micrometer.binder.http-server.enabled=true

quarkus.otel.service.name=student-management-api
quarkus.otel.traces.sampler=traceidratio
quarkus.otel.traces.sampler.arg=1
quarkus.otel.exporter.otlp.traces.endpoint=http://localhost:4317
quarkus.otel.exporter.otlp.traces.protocol=grpc
quarkus.log.console.format=%d{HH:mm:ss} %-5p traceId=%X{traceId}, spanId=%X{spanId} [%c{2.}] (%t) %s%e%n

%test.quarkus.otel.sdk.disabled=true
```

Swagger: <http://localhost:8080/q/swagger-ui>

---

### Paso 3 — `application.properties` (añade **al final**; alineado con **solution** / ECS)

Úsalo cuando vayas a copiar el proyecto a **`22-student-management-api-solution`** o a desplegar (RDS + variables en GitHub).

```properties
%prod.quarkus.hibernate-orm.database.generation=update
%prod.quarkus.datasource.username=student
%prod.quarkus.datasource.password=${STUDENT_DB_PASSWORD:change-me}
%prod.quarkus.otel.sdk.disabled=true
```

En **prod**, la URL JDBC llega por variable de entorno `QUARKUS_DATASOURCE_JDBC_URL` (no hace falta fijarla aquí si usas GitHub Actions como en la solution).

---

### Paso 4 — `StudentResource.java`

**Ruta:** `src/main/java/edu/utp/quarkus/student/StudentResource.java` — **reemplaza todo**.

```java
package edu.utp.quarkus.student;

import io.micrometer.core.annotation.Counted;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.net.URI;
import java.util.List;

@Path("/students")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Transactional
@Tag(name = "Students", description = "Alta, baja y consulta de estudiantes")
public class StudentResource {

    @GET
    @Operation(summary = "Listar estudiantes")
    public List<Student> list() {
        return Student.listAll();
    }

    @POST
    @Operation(summary = "Crear estudiante")
    @Counted(value = "students.created", description = "Estudiantes creados")
    public Response create(@Valid Student student, @Context UriInfo uriInfo) {
        student.id = null;
        student.grades.clear();
        student.persist();
        URI location = uriInfo.getAbsolutePathBuilder().path(student.id.toString()).build();
        return Response.created(location).entity(student).build();
    }

    @GET
    @Path("/{id}")
    @Operation(summary = "Obtener estudiante por id")
    public Student get(@PathParam("id") Long id) {
        return Student.<Student>findByIdOptional(id)
                .orElseThrow(() -> new NotFoundException("Student not found"));
    }

    @PUT
    @Path("/{id}")
    @Operation(summary = "Actualizar estudiante")
    public Student update(@PathParam("id") Long id, @Valid Student updated) {
        Student entity = Student.findById(id);
        if (entity == null) {
            throw new NotFoundException("Student not found");
        }
        entity.code = updated.code;
        entity.fullName = updated.fullName;
        entity.email = updated.email;
        entity.career = updated.career;
        return entity;
    }

    @DELETE
    @Path("/{id}")
    @Operation(summary = "Eliminar estudiante")
    public void delete(@PathParam("id") Long id) {
        Student entity = Student.findById(id);
        if (entity == null) {
            throw new NotFoundException("Student not found");
        }
        entity.delete();
    }
}
```

*(Opcional: quita `@Counted` y su `import` si no quieres métrica.)*

---

### Paso 5 — `GradeResource.java`

**Ruta:** `src/main/java/edu/utp/quarkus/student/GradeResource.java` — **reemplaza todo**.

```java
package edu.utp.quarkus.student;

import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.net.URI;
import java.util.List;

@Path("/students/{studentId}/grades")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Transactional
@Tag(name = "Grades", description = "Calificaciones por estudiante")
public class GradeResource {

    @GET
    @Operation(summary = "Listar calificaciones del estudiante")
    public List<Grade> list(@PathParam("studentId") Long studentId) {
        Student student = requireStudent(studentId);
        return Grade.list("student", student);
    }

    @POST
    @Operation(summary = "Registrar calificación")
    public Response create(@PathParam("studentId") Long studentId, @Valid GradeInput input, @Context UriInfo uriInfo) {
        Student student = requireStudent(studentId);
        Grade grade = new Grade();
        grade.student = student;
        grade.courseCode = input.courseCode;
        grade.score = input.score;
        grade.term = input.term;
        grade.persist();
        URI location = uriInfo.getAbsolutePathBuilder().path(grade.id.toString()).build();
        return Response.created(location).entity(grade).build();
    }

    @GET
    @Path("/{gradeId}")
    @Operation(summary = "Obtener una calificación")
    public Grade get(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId) {
        requireStudent(studentId);
        Grade grade = Grade.findById(gradeId);
        if (grade == null || grade.student == null || !grade.student.id.equals(studentId)) {
            throw new NotFoundException("Grade not found");
        }
        return grade;
    }

    @PUT
    @Path("/{gradeId}")
    @Operation(summary = "Actualizar calificación")
    public Grade update(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId, @Valid GradeInput input) {
        Grade entity = get(studentId, gradeId);
        entity.courseCode = input.courseCode;
        entity.score = input.score;
        entity.term = input.term;
        return entity;
    }

    @DELETE
    @Path("/{gradeId}")
    @Operation(summary = "Eliminar calificación")
    public void delete(@PathParam("studentId") Long studentId, @PathParam("gradeId") Long gradeId) {
        Grade entity = get(studentId, gradeId);
        entity.delete();
    }

    private static Student requireStudent(Long studentId) {
        Student student = Student.findById(studentId);
        if (student == null) {
            throw new NotFoundException("Student not found");
        }
        return student;
    }
}
```

---

### Paso 6a — `StudentApiTest.java` (solo el test CRUD)

**Ruta:** `src/test/java/edu/utp/quarkus/student/StudentApiTest.java` — en el repo **ya viene** así; si lo borraste, **reemplaza todo** por esta clase (un solo `@Test`). Cuando los pasos 4–5 estén pegados, `./mvnw test` debe pasar **1** test.

```java
package edu.utp.quarkus.student;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class StudentApiTest {

    @Test
    void crudStudentAndGrades() {
        int createdId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {"code":"T-001","fullName":"Test User","email":"test@utp.edu.pe","career":"IS"}
                        """)
                .when().post("/students")
                .then()
                .statusCode(201)
                .body("id", not(empty()))
                .extract().path("id");

        given()
                .when().get("/students/" + createdId)
                .then()
                .statusCode(200)
                .body("code", is("T-001"));

        given()
                .when().get("/students/" + createdId + "/grades")
                .then()
                .statusCode(200)
                .body("size()", is(0));

        int gradeId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {"courseCode":"CS999","score":18.5,"term":"2026-1"}
                        """)
                .when().post("/students/" + createdId + "/grades")
                .then()
                .statusCode(201)
                .extract().path("id");

        given()
                .when().get("/students/" + createdId + "/grades/" + gradeId)
                .then()
                .statusCode(200)
                .body("score", is(18.5F));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {"courseCode":"CS999","score":19.0,"term":"2026-1"}
                        """)
                .when().put("/students/" + createdId + "/grades/" + gradeId)
                .then()
                .statusCode(200)
                .body("score", is(19.0F));

        given()
                .when().delete("/students/" + createdId + "/grades/" + gradeId)
                .then()
                .statusCode(204);

        given()
                .when().delete("/students/" + createdId)
                .then()
                .statusCode(204);

        given()
                .when().get("/students/" + createdId)
                .then()
                .statusCode(404);
    }
}
```

---

### Paso 6b — `StudentApiTest.java` (añade **validación**)

En el **mismo** archivo, **dentro de la clase** (por ejemplo **antes** del `}` final que cierra `StudentApiTest`), pega este segundo método:

```java
    @Test
    void validationRejectsInvalidScore() {
        int studentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {"code":"T-002","fullName":"Other","email":"o@utp.edu.pe","career":"IS"}
                        """)
                .when().post("/students")
                .then()
                .statusCode(201)
                .extract().path("id");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {"courseCode":"X","score":25.0,"term":"2026-1"}
                        """)
                .when().post("/students/" + studentId + "/grades")
                .then()
                .statusCode(400);
    }
```

Vuelve a ejecutar `./mvnw test`: deben pasar **los dos** tests.

---

## Comandos útiles

```bash
cd 22-student-management-api-start
./mvnw quarkus:dev
./mvnw test
```

## AWS (módulo 6)

El workflow del repo opera sobre **`22-student-management-api-solution`**, no sobre esta carpeta **start**. Cuando los tests pasen, **copia** el código (y `application.properties` si lo personalizaste) a **solution** y sigue [`../22-student-management-api-solution/README.md`](../22-student-management-api-solution/README.md) y [`.github/workflows/student-management-api-aws.yml`](../.github/workflows/student-management-api-aws.yml).
