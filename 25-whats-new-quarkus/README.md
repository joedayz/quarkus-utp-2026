# 25-whats-new-quarkus

Demo de las novedades de Quarkus entre la plataforma **3.34** y la **3.40** (la
version usada en el resto de proyectos nuevos de este curso: `22`, `23` y `24`),
cubriendo tanto los anuncios de cada release como las actualizaciones de
componentes del ecosistema resaltadas para la 3.40.

Fuentes oficiales:

- [Quarkus 3.34 - Enhancements all around](https://quarkus.io/blog/quarkus-3-34-released/)
- [Quarkus 3.35 - JAR tree-shaking, PGO for native, Semeru AOT, @Transactional for Hibernate Reactive, and more](https://quarkus.io/blog/quarkus-3-35-released/)
- [Quarkus 3.36 - Quarkus Signals, embedded SBOMs, OIDC SPIFFE authentication, and more](https://quarkus.io/blog/quarkus-3-36-released/)
- [Quarkus 3.37 - Extension-based modularity, Hibernate ORM 7.4, Jackson reflection-free serializers, and more](https://quarkus.io/blog/quarkus-3-37-released/)
- [Quarkus 3.38 - Weight-based eviction for Hibernate second level Caffeine cache, and more](https://quarkus.io/blog/quarkus-3-38-released/)
- [Quarkus 3.39 - Post-quantum cryptography support in TLS registry](https://quarkus.io/blog/quarkus-3-39-released/)
- [Quarkus 3.40 - component upgrades](https://quarkus.io/blog/quarkus-3-40-released/)

## Que hay para ejecutar en esta demo

| Feature | Release | Donde esta en el codigo |
|---|---|---|
| Eviccion por peso en la cache L2 Caffeine de Hibernate ORM | 3.38 | [`Curso`](src/main/java/edu/utp/quarkus/whatsnew/model/Curso.java), [`CursoWeigher`](src/main/java/edu/utp/quarkus/whatsnew/cache/CursoWeigher.java), [`application.properties`](src/main/resources/application.properties) |
| Quarkus MCP Server 2.0.1 (component upgrade destacado en 3.40) | 3.40 | [`CursoMcpTools`](src/main/java/edu/utp/quarkus/whatsnew/mcp/CursoMcpTools.java) |
| Quarkus LangChain4j 1.13.3 sobre AWS Bedrock (component upgrade destacado en 3.40) | 3.40 | [`CourseAdvisor`](src/main/java/edu/utp/quarkus/whatsnew/ai/CourseAdvisor.java), [`CourseAdvisorResource`](src/main/java/edu/utp/quarkus/whatsnew/resource/CourseAdvisorResource.java) |

### 1. Cache L2 con eviccion por peso (3.38)

Antes de Quarkus 3.38 la region Caffeine de la segunda cache (L2) de Hibernate
ORM solo se podia limitar por **numero de objetos**
(`quarkus.hibernate-orm.cache."region".memory.object-count`). Desde 3.38 se
puede limitar por **peso estimado** con:

```properties
quarkus.hibernate-orm.cache."cursos".memory.maximum-weight=5000
quarkus.hibernate-orm.cache."cursos".memory.weigher-class=edu.utp.quarkus.whatsnew.cache.CursoWeigher
```

`CursoWeigher` implementa `com.github.benmanes.caffeine.cache.Weigher` y asigna
a cada `Curso` un peso proporcional al tamano de sus campos de texto, util
cuando el tamano de las entidades cacheadas es muy variable (por ejemplo,
descripciones largas vs. cortas).

Prueba:

```shell script
curl http://localhost:8080/cursos/1   # primera llamada: consulta H2
curl http://localhost:8080/cursos/1   # segunda llamada: resuelta desde la cache L2
```

Con `quarkus.hibernate-orm.log.sql=true` veras un solo `select` en los logs
aunque hagas la peticion varias veces.

### 2. Quarkus MCP Server 2.0.1 (upgrade de componente en 3.40)

[`CursoMcpTools`](src/main/java/edu/utp/quarkus/whatsnew/mcp/CursoMcpTools.java)
es un bean CDI normal cuyos metodos anotados con `@Tool` se exponen
automaticamente como herramientas de [MCP](https://modelcontextprotocol.io/)
(Model Context Protocol) gracias a la dependencia `quarkus-mcp-server-http`.
Cualquier cliente MCP (un asistente de IA, un IDE compatible, etc.) puede
descubrir y llamar `listarCursos` o `buscarCursoPorNombre` sin que hayamos
escrito ningun codigo de protocolo. Revisa la consola de `quarkus:dev` al
arrancar para ver el endpoint MCP expuesto.

### 3. Quarkus LangChain4j 1.13.3 + AWS Bedrock (upgrade de componente en 3.40)

[`CourseAdvisor`](src/main/java/edu/utp/quarkus/whatsnew/ai/CourseAdvisor.java)
usa `@RegisterAiService` (Quarkus LangChain4j) para declarar un asistente de IA
en un par de lineas, sin construir manualmente el request/response de Bedrock
como en `BedrockService` del modulo
[24-aws-genai-bedrock-solution](../24-aws-genai-bedrock-solution). Usa el
mismo modelo (`anthropic.claude-3-haiku-20240307-v1:0`) y requiere las mismas
credenciales de AWS que ese modulo (ver su `README.md` /
`LAB 24 - AWS GENAI BEDROCK.md`).

```shell script
curl -X POST http://localhost:8080/advisor/recommend \
  -H 'Content-Type: text/plain' \
  -d 'Quiero aprender resiliencia y tolerancia a fallos'
```

> En el perfil `%test` la integracion con Bedrock se desactiva
> (`quarkus.langchain4j.bedrock.enable-integration=false`) para que el resto
> de la demo (cache L2, MCP, REST) se pueda ejecutar y probar sin credenciales
> de AWS.

## Otras novedades 3.34 -> 3.40 (documentadas, sin demo ejecutable aqui)

Estos puntos no tienen una demo de codigo en este modulo porque requieren
infraestructura adicional (SPIFFE, TLS con curvas post-cuanticas) o son
mejoras de build/packaging dificiles de mostrar de forma aislada en un
proyecto de clase. Se documentan para referencia del curso:

| Release | Novedad | Nota |
|---|---|---|
| 3.35 | JAR tree-shaking | Reduce el tamano del uber-jar eliminando clases no usadas; relacionado con `04-develop-native-*`. |
| 3.35 | PGO (Profile-Guided Optimization) para native | Builds nativos mas rapidos/pequenos usando un perfil de ejecucion previo; ver `04-develop-native-*`. |
| 3.35 | Semeru AOT | Soporte de compilacion AOT con el runtime Semeru de IBM. |
| 3.35 | `@Transactional` para Hibernate Reactive | Simplifica el manejo de transacciones reactivas igual que en ORM clasico; complementa `08-reactive-develop-*`. |
| 3.36 | Quarkus Signals | Nueva API reactiva de estado (signals) para construir UIs/estado derivado. |
| 3.36 | SBOM embebido | El artefacto final puede incluir su propio Software Bill of Materials. |
| 3.36 | Autenticacion OIDC SPIFFE | Nuevo mecanismo de identidad de servicio para `11-secure-jwt-*` / `12-secure-sso-*`. |
| 3.37 | Modularidad basada en extensiones | Cambios internos en como se componen las extensiones de Quarkus. |
| 3.37 | Hibernate ORM 7.4 | Version de Hibernate ORM usada de base en `03-develop-persist-*` y en este modulo. |
| 3.37 | Serializers de Jackson sin reflexion | Mejora de arranque/nativo para serializacion JSON. |
| 3.38 | Quarkus HTTP Problem | Extension que mapea excepciones al estandar RFC 9457 (`application/problem+json`). |
| 3.39 | Criptografia post-cuantica en TLS registry | Soporte de algoritmos PQC en `quarkus-tls-registry`. |
| 3.40 | Amazon Services 3.22.1, Google Cloud Services 2.24.0, Camel Quarkus 3.40.0, CXF 3.40.0, Debezium 3.6.3.Final, Operator SDK 7.8.0, Vault 4.10.0, Qpid JMS 2.14.0 | Actualizaciones de componentes de la plataforma; `Amazon Services` ya se usa en `22`, `24` y en este modulo. |
| - | JobRunr 9 (externo) | Soporte dia uno para Quarkus 3.40 LTS, fuera del alcance del curso. |

## Requisitos

- Java 21 y Maven (igual que el resto del curso).
- Para el endpoint `/advisor/recommend`: credenciales de AWS con acceso a
  Bedrock, igual que en `24-aws-genai-bedrock-*`.
- El resto de la demo (cache L2, catalogo REST, herramientas MCP) funciona sin
  AWS ni Docker gracias a la base de datos H2 en memoria.

## Running the application in dev mode

You can run your application in dev mode that enables live coding using:
```shell script
./mvnw compile quarkus:dev
```

> **_NOTE:_**  Quarkus now ships with a Dev UI, which is available in dev mode only at http://localhost:8080/q/dev/.

## Packaging and running the application

The application can be packaged using:
```shell script
./mvnw package
```
It produces the `quarkus-run.jar` file in the `target/quarkus-app/` directory.
Be aware that it’s not an _über-jar_ as the dependencies are copied into the `target/quarkus-app/lib/` directory.

The application is now runnable using `java -jar target/quarkus-app/quarkus-run.jar`.

If you want to build an _über-jar_, execute the following command:
```shell script
./mvnw package -Dquarkus.package.type=uber-jar
```

The application, packaged as an _über-jar_, is now runnable using `java -jar target/*-runner.jar`.

## Creating a native executable

You can create a native executable using:
```shell script
./mvnw package -Dnative
```

Or, if you don't have GraalVM installed, you can run the native executable build in a container using:
```shell script
./mvnw package -Dnative -Dquarkus.native.container-build=true
```

You can then execute your native executable with: `./target/25-whats-new-quarkus-1.0.0-SNAPSHOT-runner`

If you want to learn more about building native executables, please consult https://quarkus.io/guides/maven-tooling.

## Related Guides

- Hibernate ORM with Panache ([guide](https://quarkus.io/guides/hibernate-orm-panache)): CRUD simplificado y cache L2 con Hibernate ORM
- Quarkus LangChain4j ([docs](https://docs.quarkiverse.io/quarkus-langchain4j/dev/index.html)): servicios de IA declarativos (`@RegisterAiService`)
- Quarkus MCP Server ([docs](https://docs.quarkiverse.io/quarkus-mcp-server/dev/index.html)): exposicion de herramientas via Model Context Protocol
- SmallRye OpenAPI ([guide](https://quarkus.io/guides/openapi-swaggerui)): Document your REST APIs with OpenAPI - comes with Swagger UI
