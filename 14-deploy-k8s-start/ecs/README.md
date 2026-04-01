## Demo Contenedores: expense-service + expense-client (AWS ECS Fargate)

Este directorio contiene una demo para desplegar los microservicios en **Amazon Elastic Container Service (ECS)** usando **Fargate** (serverless):
- expense-service: servicio REST de gastos
- expense-client: cliente que consume expense-service

A diferencia de EKS (Kubernetes), ECS usa su propia API con **Task Definitions**, **Services** y **Clusters**. No se necesita kubectl ni manifiestos YAML de Kubernetes.

### Prerrequisitos

1. **AWS CLI v2** instalado y configurado
   - Instalación: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   - Configurar: `aws configure`
   - Verificar: `aws --version` y `aws sts get-caller-identity`

2. **Docker o Podman** instalado y ejecutándose
   - Necesario para construir las imágenes localmente antes de subirlas a ECR
   - Los scripts detectan automáticamente cuál está disponible

3. **Maven** instalado
   - Para construir los proyectos Java antes de crear las imágenes Docker

4. **Cuenta de AWS** con permisos IAM para:
   - ECR (crear repos, push/pull imágenes)
   - ECS (crear clusters, task definitions, services)
   - IAM (crear roles de ejecución)
   - Cloud Map (service discovery)
   - EC2 (security groups, VPC)
   - CloudWatch Logs

### Costos

⚠️ **Importante**: ECS Fargate es un servicio de pago en AWS.
- **Fargate vCPU**: $0.04048/hora por vCPU
- **Fargate Memory**: $0.004445/hora por GB
- **Por tarea (0.5 vCPU, 1GB)**: ~$0.02/hora (~$14.76/mes)
- **2 tareas**: ~$30/mes
- **ECR**: $0.10/GB/mes de almacenamiento
- **Cloud Map**: $0.10/mes por namespace + $0.10 por millón de queries

**Total estimado**: ~$32/mes si se deja corriendo 24/7 (más barato que EKS)

Asegúrate de:
- Eliminar los recursos cuando termines para evitar cargos
- Usar `./scripts/undeploy-all.sh --delete-all` para limpiar todo

### Diferencias: EKS vs ECS vs Azure AKS

| Concepto | Azure AKS | AWS EKS | AWS ECS Fargate |
|----------|-----------|---------|-----------------|
| Tipo | Kubernetes managed | Kubernetes managed | Container orchestration propio |
| Manifiestos | YAML (K8s) | YAML (K8s) | Task Definitions (JSON/CLI) |
| CLI | kubectl | kubectl | aws ecs |
| Nodos | VMs gestionadas | EC2 o Fargate | **Sin servidores** (Fargate) |
| Service Discovery | DNS interno K8s | DNS interno K8s | **AWS Cloud Map** |
| Load Balancer | Azure LB (IP) | AWS ELB (hostname) | IP pública directa o ALB |
| Health Checks | Probes K8s | Probes K8s | Container health checks |
| Logs | kubectl logs | kubectl logs | **CloudWatch Logs** |
| Costo base | Gratis (control plane) | ~$73/mes | **Sin costo de control plane** |
| Costo total (lab) | ~$120/mes | ~$210/mes | **~$32/mes** |

### Arquitectura ECS

```
┌─────────────────────────────────────────────┐
│                AWS Cloud                     │
│  ┌─────────────────────────────────────┐    │
│  │         ECS Cluster (Fargate)        │    │
│  │                                      │    │
│  │  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │expense-client│──│expense-service│ │    │
│  │  │  Task (0.5c)  │  │  Task (0.5c) │ │    │
│  │  │  IP pública   │  │  IP privada  │ │    │
│  │  └──────────────┘  └──────────────┘ │    │
│  │         │              ▲             │    │
│  │         │    Cloud Map │             │    │
│  │         └──────────────┘             │    │
│  │     expense-service.expense.local    │    │
│  └─────────────────────────────────────┘    │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │   ECR    │  │CloudWatch│  │Cloud Map │  │
│  │ (images) │  │  (logs)  │  │  (DNS)   │  │
│  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────┘
```

**Comunicación entre servicios:**
- En K8s (EKS/AKS): `expense-service:8080` (DNS interno de K8s)
- En ECS: `expense-service.expense.local:8080` (AWS Cloud Map / Route 53 privado)

### Pasos para desplegar en ECS

#### Paso 1: Configurar AWS (crear ECR, ECS, Cloud Map, SG, IAM)

Este script crea toda la infraestructura necesaria:
- Repositorios ECR para cada microservicio
- Rol IAM de ejecución de tareas (`ecsTaskExecutionRole`)
- Security Group con acceso HTTP en puerto 8080
- Cluster ECS con Fargate como capacity provider
- Namespace de Cloud Map (`expense.local`) para service discovery
- Log Group en CloudWatch

```bash
cd ecs
chmod +x scripts/*.sh
./scripts/ecs-setup.sh [CLUSTER_NAME] [AWS_REGION]
```

Ejemplo con valores personalizados:
```bash
./scripts/ecs-setup.sh mi-cluster us-west-2
```

Valores por defecto:
- CLUSTER_NAME: `expense-ecs`
- AWS_REGION: `us-east-1`

#### Paso 2: Construir y subir imágenes a ECR

Mismo proceso que EKS: compila con Maven, construye imagen Docker, sube a ECR.

```bash
./scripts/build-and-push-all.sh
```

#### Paso 3: Desplegar en ECS

Este script:
- Registra un servicio de Service Discovery en Cloud Map para expense-service
- Crea Task Definitions para cada microservicio (Fargate, 0.5 vCPU, 1GB RAM)
- Crea o actualiza los ECS Services
- expense-client usa la variable `EXPENSE_SVC=http://expense-service.expense.local:8080`
- Espera a que los servicios estén estables
- Muestra la IP pública del expense-client

```bash
./scripts/deploy-all.sh
```

#### Paso 4: Verificar el despliegue

```bash
# Ver estado de servicios y obtener IP
./scripts/diagnose.sh

# Probar el servicio
curl http://<PUBLIC_IP>:8080/expenses

# Ver logs en CloudWatch
aws logs tail /ecs/expense-ecs --since 10m --follow
```

### Scripts disponibles

| Script | Descripción |
|--------|-------------|
| `scripts/ecs-setup.sh` | Crea toda la infraestructura AWS |
| `scripts/build-and-push-all.sh` | Compila y sube imágenes a ECR |
| `scripts/deploy-all.sh` | Despliega Task Definitions y Services en ECS |
| `scripts/undeploy-all.sh` | Elimina servicios y task definitions |
| `scripts/undeploy-all.sh --delete-all` | Elimina todo (servicios + cluster + ECR + SG + etc.) |
| `scripts/diagnose.sh` | Diagnóstico completo (servicios, tareas, logs, IPs) |

### Troubleshooting

#### Tarea en estado STOPPED
```bash
# Ver razón de parada
./scripts/diagnose.sh

# Ver logs en CloudWatch
aws logs tail /ecs/expense-ecs --since 30m

# Causas comunes:
# - La imagen no existe en ECR → ejecuta build-and-push-all.sh
# - Out of memory → aumentar memory en task definition
# - Health check falla → verificar que /q/health/live responde
```

#### Service Discovery no funciona
```bash
# Verificar namespace
aws servicediscovery list-namespaces --query 'Namespaces[?Name==`expense.local`]'

# Verificar servicio registrado
aws servicediscovery list-services --query 'Services[?Name==`expense-service`]'

# Verificar instancias
aws servicediscovery list-instances --service-id <SERVICE_ID>
```

#### Sin IP pública
```bash
# Las tareas Fargate necesitan assignPublicIp=ENABLED y una subnet pública
# Si usas subnets privadas, necesitas un NAT Gateway o un ALB

# Para producción se recomienda usar un Application Load Balancer (ALB)
# en lugar de IPs públicas directas en las tareas
```

#### Permisos IAM insuficientes
```bash
# Verificar identidad actual
aws sts get-caller-identity

# El usuario necesita permisos para:
# - ecs:* (cluster, services, tasks)
# - ecr:* (registry)
# - iam:CreateRole, iam:AttachRolePolicy (rol de ejecución)
# - servicediscovery:* (Cloud Map)
# - ec2:* (security groups, VPC)
# - logs:* (CloudWatch)
```

### Limpieza

```bash
# Solo eliminar servicios (mantiene cluster, repos, infra)
./scripts/undeploy-all.sh

# Eliminar TODO (servicios + cluster + ECR + SG + Cloud Map + logs)
./scripts/undeploy-all.sh --delete-all
```
