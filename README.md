# quarkus-utp-2026
Repo del curso **Microservicios cloud-native con Quarkus en AWS** para la UTP.

## Estructura general del curso

- **docs**: diapositivas y PDFs de apoyo.
- **labs**: enunciados de los laboratorios.
- **00-21**: proyectos heredados del curso anterior (UTP), reutilizados y renombrados en el temario UTP.
- **Nuevos proyectos UTP**:
  - `22-student-management-api`: mini‑proyecto integrador (Student Management API).
  - `23-async-virtual-threads`: microservicios asíncronos usando virtual threads.
  - `24-aws-genai-bedrock`: integración de Quarkus con AWS Bedrock (módulo inspiración IA).

## Módulos vs proyectos

- **Módulo 1 – Fundamentos y Arquitectura (4h)**
  - Arquitectura y patrones (API Gateway, Saga, CQRS, Circuit Breaker): material teórico en `docs/` + referencias a labs de tolerancia a fallos (`15-17-*`) y monitoreo (`18-21-*`).
  - Arquitectura de referencia AWS (ECS/EKS, RDS, Secrets Manager, CloudWatch): material teórico en `docs/` + configuración específica en proyectos de despliegue y observabilidad.

- **Módulo 2 – Desarrollo con Quarkus (10h)**
  - MicroProfile Config → `01-develop-config-*`
  - Servicios REST con Quarkus → `02-develop-rest-*`
  - API Contract‑First con OpenAPI → se reforzará en `02-develop-rest-*` y `22-student-management-api`.
  - Persistencia con AWS RDS (PostgreSQL/Aurora) → `03-develop-persist-*` + perfiles/properties para RDS.
  - Aplicaciones nativas y GraalVM → `04-develop-native-*`
  - Testing y Testcontainers → `05-demo-test-*` y `06-test-review-*`

- **Módulo 3 – Integración y Resiliencia (5h)**
  - Microservicios asíncronos y virtual threads → `23-async-virtual-threads` (nuevo).
  - Tolerancia a fallos con SmallRye Fault Tolerance → `15-tolerance-policies-*`, `16-tolerance-health-*`, `17-tolerance-review-*`.

- **Módulo 4 – Seguridad y Operaciones de Identidad (4h)**
  - Seguridad con JWT, OIDC, integración con AWS Cognito o Keycloak → `11-secure-jwt-*`, `12-secure-sso-*`, `13-secure-review-*`.

- **Módulo 5 – Observabilidad y Operaciones (4h)**
  - Monitoreo y logging (OpenTelemetry, Micrometer, Grafana, CloudWatch) → `18-monitor-logging-*`, `19-monitor-metrics-*`, `20-monitor-trace-*`, `21-monitor-review-*` + ajustes para exportar a AWS.
  - Troubleshooting y diagnóstico en AWS → se apoya en los mismos proyectos de observabilidad y en el despliegue en contenedores (`14-deploy-k8s-start`).

- **Módulo 6 – Mini‑Proyecto Integrador (2h)**
  - `22-student-management-api`: microservicio educativo con REST, persistencia en RDS y despliegue en contenedor (ECS/EKS) + observabilidad con CloudWatch/Jaeger.

- **Módulo 7 – IA en AWS (1h, opcional de inspiración)**
  - `24-aws-genai-bedrock`: ejemplo de microservicio Quarkus que orquesta llamadas a AWS Lambda y consulta un modelo fundacional vía Bedrock (RAG o análisis semántico).

## Cómo ejecutar los proyectos

- **Requisitos generales**
  - Java 21 instalado.
  - Maven 3.8+.
  - Docker (recomendado para bases de datos y herramientas de observabilidad).

- **Ejecutar un laboratorio**
  - Entrar al directorio del proyecto, por ejemplo:

    ```bash
    cd 22-student-management-api
    mvn quarkus:dev
    ```

  - La aplicación quedará disponible en `http://localhost:8080`.

- **Configuración de base de datos (ejemplo Student Management API)**
  - Configuración local: ver `22-student-management-api/src/main/resources/application.properties` (PostgreSQL local `studentdb`).
  - En AWS RDS usar el perfil `prod` y ajustar la URL del datasource al endpoint de RDS.

> Nota: varios proyectos mantienen el código base original del curso UTP, pero la narrativa y los ejercicios se adaptan al contexto educativo (UTP) y a AWS.
