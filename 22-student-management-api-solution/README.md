# 22-student-management-api-solution

Referencia completa del **mini‑proyecto integrador** (Módulo 5–6, ~2 h): API REST con Quarkus, OpenAPI, PostgreSQL (**RDS** en la nube), métricas y trazas. La **demo de despliegue en AWS del curso** se hace con **GitHub Actions → Amazon ECR → Amazon ECS (Fargate)** (no es un flujo opcional: es el camino acordado para mostrar el pipeline en clase).

**Laboratorio paso a paso (implementación en local → copiar a esta carpeta → AWS):** sigue la guía en [**`22-student-management-api-start/README.md`**](../22-student-management-api-start/README.md) (fases numeradas, comandos listos para copiar y pegar).

## Despliegue en AWS: GitHub Actions → ECR → ECS

Workflow: [`.github/workflows/student-management-api-aws.yml`](../.github/workflows/student-management-api-aws.yml).  
Task definition plantilla: [`deploy/ecs-task-definition.json`](deploy/ecs-task-definition.json).

### Qué hace el workflow (y qué no)

| Sí hace | No hace |
|---------|---------|
| `./mvnw package -DskipTests`, `docker build` con `src/main/docker/Dockerfile.jvm` | No ejecuta tests en CI |
| Crea el repositorio **ECR** si no existe; `docker push` `:GITHUB_SHA` y `:latest` | No crea **cluster** ni **servicio** ECS ni ALB (eso es local/consola) |
| Sustituye `__AWS_ACCOUNT_ID__` y `__AWS_REGION__` en la task definition | No ejecuta **`aws-bootstrap`** (RDS/EC2 lo creas en tu máquina con ese script) |
| Si la Variable **`QUARKUS_DATASOURCE_JDBC_URL`** está definida, **añade** JDBC al JSON (usuario por Variable `QUARKUS_DATASOURCE_USERNAME` o `student`; contraseña vía Secret **`STUDENT_DB_PASSWORD`** si existe) | — |
| Registra una **nueva revisión** de task definition e inyecta la imagen ECR; `ecs UpdateService` + **wait for service stability** | — |

Si el servicio no estabiliza (health checks fallando, tarea reiniciando), el job **falla** al final aunque ECR haya recibido la imagen.

---

<a id="aws-bootstrap-script"></a>

### Script aws-bootstrap (AWS CLI): `deploy/aws-bootstrap.sh` y `deploy/aws-bootstrap.ps1`

En [`deploy/aws-bootstrap.sh`](deploy/aws-bootstrap.sh) (Linux/macOS/Git Bash) y [`deploy/aws-bootstrap.ps1`](deploy/aws-bootstrap.ps1) (Windows PowerShell) tienes un aprovisionador que usa **AWS CLI v2** y crea la mayor parte de lo que el workflow **no** crea.

**Requisitos:** perfil o credenciales AWS con permisos amplios en la cuenta de demo (IAM, EC2, ECR, ECS, Logs; con **`--with-rds` / `-WithRds`** también **RDS**). Sin `--with-rds`, debes crear RDS a mano o añadir JDBC en `deploy/ecs-task-definition.json` / variables de GitHub.

**Qué crea (idempotente en lo posible):**

| Recurso | Detalle |
|---------|---------|
| Rol `ecsTaskExecutionRole` | Trust `ecs-tasks.amazonaws.com` + `AmazonECSTaskExecutionRolePolicy` |
| Repositorio ECR | Nombre por defecto `student-management-api` (o `ECR_REPOSITORY`) |
| Log group | `/ecs/student-management-api` |
| Cluster ECS | Nombre por defecto `student-management-api` (o `CLUSTER_NAME`) |
| Security group | `student-mgmt-ecs-<cluster>`: ingress **8080** desde `0.0.0.0/0` (**solo demo**) |
| Subnets | Dos subnets de la VPC; con **`--with-rds`** deben estar en **AZ distintas** (requisito de RDS) |
| **`--with-rds` / `-WithRds`** (opcional) | DB subnet group, SG de RDS (5432 ← SG de tareas ECS), instancia **PostgreSQL** `db.t4g.micro` (configurable con `RDS_INSTANCE_CLASS`). **Coste y espera (~10–20 min)** la primera vez. |
| Archivos generados | `deploy/github-variables-snippet.env`; con RDS además **`deploy/rds-credentials.env`** (gitignored) con JDBC listo para copiar a GitHub **Variables** + **Secret** |

**Variables de entorno opcionales:** `AWS_REGION`, `CLUSTER_NAME`, `SERVICE_NAME` (default `student-management-api-svc`), `ECR_REPOSITORY`, `VPC_ID`.

**Uso (desde la carpeta `22-student-management-api-solution`):**

```bash
chmod +x deploy/aws-bootstrap.sh   # una vez
./deploy/aws-bootstrap.sh --infra-only --with-rds
```

```powershell
Set-Location 22-student-management-api-solution
.\deploy\aws-bootstrap.ps1 -InfraOnly -WithRds
```

- **`--with-rds` / `-WithRds`:** crea RDS PostgreSQL de demo y `deploy/rds-credentials.env`. Combínalo con `--infra-only` o con una corrida completa (no con `--deploy-service`).
- **`--infra-only` / `-InfraOnly`:** solo infra anterior + `github-variables-snippet.env`; **no** registra task definition ni crea el servicio ECS.
- **Sin flags:** si ya existe imagen `:latest` en ECR, registra la task definition (sustituye imagen por la de tu cuenta) y crea el servicio Fargate si aún no existe.
- **`--deploy-service` / `-DeployService`:** tras publicar la imagen (p. ej. GitHub Action con **Solo ECR**), registra task y crea el servicio.

**Flujo recomendado con el script:**

1. Ejecutar **`--infra-only`** (opcional **`--with-rds`** para crear RDS y obtener JDBC en `rds-credentials.env`). Anota el **security group** de las tareas si no usaste RDS en el script.  
2. **JDBC en ECS:** o bien editas **`deploy/ecs-task-definition.json`** y **commit**, o bien (recomendado sin contraseña en git) defines en GitHub la Variable **`QUARKUS_DATASOURCE_JDBC_URL`**, Variable **`QUARKUS_DATASOURCE_USERNAME`** y el Secret **`STUDENT_DB_PASSWORD`** (valores copiados de `rds-credentials.env` tras `--with-rds`).  
3. Si **no** usaste `--with-rds`, en **RDS** abre **5432** desde el security group de las tareas.  
4. En **GitHub**: Secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` y **Variables** de `github-variables-snippet.env`.  
5. Ejecutar el workflow con **Solo ECR** para subir `:latest`.  
6. Ejecutar **`./deploy/aws-bootstrap.sh --deploy-service`** (o `.\deploy\aws-bootstrap.ps1 -DeployService`) si el servicio ECS aún no existe.  
7. Ejecutar el workflow **sin** Solo ECR para que Actions actualice el servicio en cada cambio.

---

### Checklist: qué necesitas para que el Action pase

Marca esto **antes** de ejecutar el workflow con **ECR + ECS** (sin «Solo ECR»):

1. **IAM — rol de ejecución de tareas (ECS)**  
   - Existe un rol (p. ej. `ecsTaskExecutionRole`) con la política administrada **`AmazonECSTaskExecutionRolePolicy`**.  
   - El **nombre** del rol coincide con `executionRoleArn` en `deploy/ecs-task-definition.json` (por defecto `arn:aws:iam::CUENTA:role/ecsTaskExecutionRole`). Si tu rol tiene otro nombre, **cámbialo en el JSON** en el repo.

2. **IAM — usuario o clave que usa GitHub**  
   - Puede autenticarse en la cuenta y región correctas.  
   - Tiene permisos suficientes (ver [política mínima sugerida](#iam-mínimo-para-el-usuario-de-github-actions) más abajo), incluido **`iam:PassRole`** sobre el ARN del **execution role** de la tarea.

3. **RDS PostgreSQL**  
   - Instancia creada, accesible desde las **mismas VPC/subnets** donde correrán las tareas (o enrutado/VPC peering según tu diseño).  
   - **Security group de RDS:** entrada **5432** solo desde el security group de las tareas ECS (no abierto a `0.0.0.0/0` en producción).

4. **Red del servicio ECS**  
   - **Cluster** Fargate creado (o creado por el [script aws-bootstrap](#aws-bootstrap-script)).  
   - **Servicio** existente con nombre exacto al de la variable `ECS_SERVICE`, en el cluster `ECS_CLUSTER` (el script puede crearlo en `--deploy-service` tras la primera imagen en ECR).  
   - El servicio usa **awsvpc**, subnets correctas, **security group** que permita: tráfico al contenedor **8080** (desde el ALB o desde donde pruebes) y **salida** hacia RDS:5432 (y hacia internet si la imagen debe tirar de algo externo).

5. **`deploy/ecs-task-definition.json` en el repo**  
   - `family` = `student-management-api` (debe coincidir con la familia que usa tu servicio).  
   - En `containerDefinitions[0].environment` (o `secrets`) están **`QUARKUS_DATASOURCE_JDBC_URL`**, usuario y contraseña de **prod**, coherentes con Quarkus 3, por ejemplo:  
     - `QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://HOST_RDS:5432/NOMBRE_BD`  
     - `QUARKUS_DATASOURCE_USERNAME=...`  
     - `QUARKUS_DATASOURCE_PASSWORD=...` **o** referencia a **Secrets Manager** en `secrets` (recomendado).  
   - Sin JDBC válido, la app no arranca bien y el **health check** `GET /q/health/live` falla → **stability timeout**.

6. **Primera vez: el servicio ECS debe existir antes del pipeline completo**  
   El Action **no** crea el servicio. Opciones: usar **`deploy/aws-bootstrap.sh --deploy-service`** (o `.ps1 -DeployService`) después de la primera subida a ECR, **o** registrar la task definition y crear el servicio a mano en la consola/AWS CLI. A partir de ahí, cada ejecución del workflow registra **nueva revisión** y actualiza el servicio.

7. **GitHub — Secrets y Variables** (pestaña *Actions*)  
   - Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`. Opcional: **`STUDENT_DB_PASSWORD`** (si defines **`QUARKUS_DATASOURCE_JDBC_URL`**, el workflow inyecta JDBC en la task definition).  
   - Variables: **`ECS_CLUSTER`** y **`ECS_SERVICE`** (obligatorias si quieres ECS en ejecución manual sin «Solo ECR»).  
   - Opcionales: `AWS_REGION`, `ECR_REPOSITORY`; **`QUARKUS_DATASOURCE_JDBC_URL`**, **`QUARKUS_DATASOURCE_USERNAME`** (si la URL está definida, Actions añade JDBC al JSON antes del deploy).

8. **Health check del contenedor**  
   - La imagen JVM incluye `curl`; el task definition ya usa `curl -sf http://localhost:8080/q/health/live`.  
   - Extensión **`quarkus-smallrye-health`** debe estar en el `pom.xml` (ya está en esta solution).

---

### Primera vez en AWS (orden sugerido)

**Opción A — con script (recomendado en clase):** [`aws-bootstrap.sh`](deploy/aws-bootstrap.sh) / [`aws-bootstrap.ps1`](deploy/aws-bootstrap.ps1) y el [flujo recomendado](#aws-bootstrap-script) de la sección anterior.

**Opción B — manual:**

1. Crear **VPC/subnets/SG** (o usar default con cuidado en clase).  
2. Crear **RDS PostgreSQL** y anotar endpoint, puerto, base, usuario y contraseña.  
3. Crear rol **`ecsTaskExecutionRole`** con `AmazonECSTaskExecutionRolePolicy`. Si las contraseñas vienen de Secrets Manager, añade al mismo rol permiso de lectura al secreto (`secretsmanager:GetSecretValue` + `kms:Decrypt` si aplica).  
4. Editar **`deploy/ecs-task-definition.json`**: completar `environment` / `secrets` para JDBC (y revisar nombre del rol). Hacer commit en el repo.  
5. **Registrar** la task definition una vez (consola ECS → *Task definitions* → *Create new* con JSON, o `aws ecs register-task-definition --cli-input-json file://...` con el JSON ya sustituido manualmente en cuenta/región).  
6. Crear **cluster** ECS y **servicio** Fargate: elegir la task `student-management-api:1` (o la revisión que hayas registrado), red awsvpc, SG, ALB si aplica.  
7. Configurar en GitHub las **variables** `ECS_CLUSTER` y `ECS_SERVICE` con esos nombres **exactos**.  
8. Configurar **secrets** AWS del usuario IAM.  
9. Ejecutar el workflow (**sin** «Solo ECR») o hacer push a `main` bajo `22-student-management-api-solution/**`.

---

### IAM mínimo para el usuario de GitHub Actions

Sustituye `ACCOUNT_ID` y el nombre del rol si difiere. Ajusta el ARN de `PassRole` al execution role real.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECR",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECS",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PassRoleToECS",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole"
    }
  ]
}
```

`GetAuthorizationToken` en ECR suele requerir `"Resource": "*"` (limitación de AWS). Si usas otra región distinta a la del repo ECR, mantén coherencia con `AWS_REGION` en Variables.

---

### Ejemplo: variables de entorno JDBC en `ecs-task-definition.json`

Dentro de `containerDefinitions[0].environment`, además de `QUARKUS_PROFILE=prod`, añade (valores de ejemplo):

```json
{
  "name": "QUARKUS_DATASOURCE_JDBC_URL",
  "value": "jdbc:postgresql://mi-db.abc123.us-east-1.rds.amazonaws.com:5432/studentdb"
},
{
  "name": "QUARKUS_DATASOURCE_USERNAME",
  "value": "student"
},
{
  "name": "STUDENT_DB_PASSWORD",
  "value": "NO_USAR_EN_PRODUCCION_MEJOR_SECRETS_MANAGER"
}
```

La solution usa `%prod.quarkus.datasource.password=${STUDENT_DB_PASSWORD:...}`; por coherencia usa **`STUDENT_DB_PASSWORD`** en la task definition (o Variables/Secret en GitHub como arriba). En producción, usa `"secrets"` con **Secrets Manager** y deja la contraseña fuera del JSON en git.

---

### Si el workflow falla: causas frecuentes

| Síntoma | Qué revisar |
|---------|-------------|
| Error en *Verificar variables ECS* | Variables `ECS_CLUSTER` y `ECS_SERVICE` vacías en GitHub, o marcaste mal «Solo ECR». |
| `AccessDenied` en ECR / ECS / `PassRole` | Política IAM del usuario; ARN en `iam:PassRole` debe ser el **execution role** de la task. |
| `InvalidParameterException` en task definition | JSON inválido tras editar; coma final, comillas, o `executionRoleArn` de otra cuenta. |
| El job termina pero *Deploy* falla o hace timeout | El **servicio** no existe o el nombre no coincide con `ECS_SERVICE`. |
| *Wait for service stability* timeout | Tarea **unhealthy**: JDBC mal, RDS no alcanzable desde subnets/SG, o contraseña incorrecta. Revisa **CloudWatch Logs** del contenedor (`/ecs/student-management-api`). |
| Health check del contenedor falla | App no levanta (puerto 8080, error al conectar a BD, falta `quarkus-smallrye-health`). |

---

### Ejecutar el workflow

1. **Actions** → **Student Management API — Demo AWS (GitHub Actions → ECR → ECS)** → **Run workflow**.  
2. Desmarca **Solo ECR** para pipeline completo.  
3. O bien: **push** a `main` que cambie archivos bajo `22-student-management-api-solution/**` (con `ECS_CLUSTER` / `ECS_SERVICE` definidos si quieres ECS en ese push).

**Health check en ECS:** `GET /q/health/live` (`quarkus-smallrye-health`).

| Secret / variable GitHub | Uso |
|--------------------------|-----|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Credenciales del usuario IAM con la política anterior (o equivalente). |
| `AWS_REGION` | Variable opcional; por defecto en el workflow suele usarse `us-east-1` si no defines `vars.AWS_REGION`. |
| `ECR_REPOSITORY` | Variable opcional; por defecto `student-management-api`. |
| **`ECS_CLUSTER`**, **`ECS_SERVICE`** | Variables **obligatorias** para desplegar en ECS (manual sin «Solo ECR», o push con despliegue). |

---

## Requisitos (desarrollo local)

- Java 21, Maven 3.8+, Docker (tests con Dev Services; Jaeger opcional para trazas locales).

## Ejecutar en desarrollo

1. **Docker** activo (Dev Services arranca PostgreSQL en contenedor). Si usas tu propio Postgres en `localhost:5432` / `studentdb`, define `QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://localhost:5432/studentdb`.
2. Arranque:

   ```bash
   cd 22-student-management-api-solution
   ./mvnw quarkus:dev
   ```

3. **Swagger UI:** [http://localhost:8080/q/swagger-ui](http://localhost:8080/q/swagger-ui)  
4. **OpenAPI:** [http://localhost:8080/openapi](http://localhost:8080/openapi)  
5. **Métricas:** [http://localhost:8080/q/metrics](http://localhost:8080/q/metrics)

## API (resumen)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/students` | Lista estudiantes |
| POST | `/students` | Crea estudiante |
| GET | `/students/{id}` | Detalle |
| PUT | `/students/{id}` | Actualiza |
| DELETE | `/students/{id}` | Elimina (y calificaciones en cascada vía Panache) |
| GET | `/students/{id}/grades` | Lista calificaciones |
| POST | `/students/{id}/grades` | Crea calificación (cuerpo: `courseCode`, `score`, `term`) |
| GET/PUT/DELETE | `/students/{id}/grades/{gradeId}` | CRUD de una nota |

La nota se valida en escala **0–20** (ajusta si tu institución usa otra escala).

## Trazas (Jaeger u OTLP)

Por defecto las trazas se envían a `http://localhost:4317` (gRPC). Ejemplo con Jaeger:

```bash
docker run --rm -p 16686:16686 -p 4317:4317 jaegertracing/jaeger:2.5.0
```

Los tests desactivan OpenTelemetry (`%test`).

## Tests automatizados

Ubicación: `src/test/java/edu/utp/quarkus/student/`.

| Clase | Qué comprueba |
|--------|----------------|
| **`StudentApiTest`** | Con `@QuarkusTest` y REST Assured contra la app en JVM: **CRUD de estudiante** (POST 201, GET, DELETE 204, GET 404); **calificaciones** (lista vacía, POST nota, GET por id, PUT nota, DELETE); **validación** (POST nota con `score` fuera de 0–20 → 400). |
| **`StudentApiIT`** | Misma batería en **modo empaquetado** (`@QuarkusIntegrationTest`); se ejecuta con `./mvnw verify` cuando `skipITs` está en false (por defecto en este `pom.xml` los IT están saltados; quita `<skipITs>true</skipITs>` o usa el perfil `native` si quieres activarlos en el ciclo estándar). |

Ejecución habitual (solo tests unitarios / `@QuarkusTest`):

```bash
cd 22-student-management-api-solution
./mvnw test
```

Requisito: **Docker** en marcha (Dev Services levanta PostgreSQL para el perfil `test`).

**GitHub Actions (demo ECR/ECS):** el workflow compila con `-DskipTests` para acelerar el pipeline; conviene ejecutar `./mvnw test` en local (o añadir un job de CI dedicado) antes de confiar en un despliegue.
