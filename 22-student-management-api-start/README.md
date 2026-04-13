# 22-student-management-api-start (plantilla del laboratorio)

Carpeta **START**: implementación **tuya** en local; la **solución de referencia** está en [`../22-student-management-api-solution/`](../22-student-management-api-solution/).

## Qué incluye esta plantilla

| Contenido | Rol |
|-----------|-----|
| `pom.xml`, `mvnw`, Dockerfiles | Mismo stack Quarkus 3.32 que la solution |
| `Student.java`, `Grade.java`, `GradeInput.java` | Modelo JPA y DTO listos |
| `StudentResource.java`, `GradeResource.java` | **Stubs** (`UnsupportedOperationException`): **tú** implementas la lógica REST + Panache |
| `StudentApiTest.java` | Pruebas de integración: deben pasar (`201`, `200`, `204`, `404`, validación `400`) cuando termines |
| `application.properties` | Dev Services (PostgreSQL en Docker) para `quarkus:dev` y tests |

## Flujo recomendado

1. **Docker** activo (Dev Services).
2. Implementa **`StudentResource`** y **`GradeResource`** (sustituye los `throw new UnsupportedOperationException(...)`).
   - Puedes guiarte por [`../22-student-management-api-solution/src/main/java/edu/utp/quarkus/student/`](../22-student-management-api-solution/src/main/java/edu/utp/quarkus/student/) (solo para comparar, no copies sin entender).
3. Ejecuta en esta carpeta:

   ```bash
   ./mvnw quarkus:dev
   ```

   Swagger: <http://localhost:8080/q/swagger-ui>

4. Cuando compile y quieras validar contrato:

   ```bash
   ./mvnw test
   ```

5. Cuando **todos los tests** pasen, **copia** los archivos Java (y lo que cambies en `application.properties` si aplica) hacia **`22-student-management-api-solution`** para alinear con el proyecto que despliega **GitHub Actions → ECR → ECS** (ver [`../.github/workflows/student-management-api-aws.yml`](../.github/workflows/student-management-api-aws.yml) y el README de la solution).

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

Cuerpos JSON alineados con `Student`, `GradeInput` y entidad `Grade`.

## AWS (módulo 6)

El workflow del repo opera sobre **`22-student-management-api-solution`**, no sobre esta carpeta **start**. Después del lab local, sincroniza código con **solution** y sigue [`../22-student-management-api-solution/README.md`](../22-student-management-api-solution/README.md) (RDS, variables GitHub, `deploy/aws-bootstrap.sh`, etc.).

## Requisitos

- Java **21**, Maven (o solo `./mvnw`), Docker para Dev Services.
