## Demo Kubernetes: expense-service + expense-client (AWS EKS)

Este directorio contiene una demo para desplegar los microservicios en **Amazon Elastic Kubernetes Service (EKS)**:
- expense-service: servicio REST de gastos
- expense-client: cliente que consume expense-service

Los scripts construyen las imágenes Docker, las suben a **Amazon Elastic Container Registry (ECR)** y las despliegan en EKS. La comunicación interna usa DNS con la variable EXPENSE_SVC.

### Prerrequisitos

1. **AWS CLI v2** instalado y configurado
   - Instalación: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   - Configurar: `aws configure`
   - Verificar: `aws --version` y `aws sts get-caller-identity`

2. **eksctl** instalado
   - Instalación: https://eksctl.io/installation/
   - En macOS: `brew install eksctl`
   - Verificar: `eksctl version`

3. **Docker o Podman** instalado y ejecutándose
   - Necesario para construir las imágenes localmente antes de subirlas a ECR
   - Los scripts detectan automáticamente cuál está disponible

4. **kubectl** instalado
   - Instalación: https://kubernetes.io/docs/tasks/tools/
   - En macOS: `brew install kubectl`
   - Verificar: `kubectl version --client`

5. **Maven** instalado
   - Para construir los proyectos Java antes de crear las imágenes Docker

6. **Cuenta de AWS** con permisos IAM para:
   - ECR (crear repos, push/pull imágenes)
   - EKS (crear/administrar clusters)
   - EC2 (nodos del cluster)
   - CloudFormation (eksctl lo usa internamente)
   - IAM (roles de servicio)

### Costos

⚠️ **Importante**: EKS y EC2 son servicios de pago en AWS.
- **EKS Control Plane**: ~$0.10/hora (~$73/mes)
- **EC2 Nodos (t3.medium x2)**: ~$0.0416/hora por nodo (~$60/mes por nodo)
- **ECR**: $0.10/GB/mes de almacenamiento
- **ELB (LoadBalancer)**: ~$0.025/hora (~$18/mes)

**Total estimado**: ~$210/mes si se deja corriendo 24/7

Asegúrate de:
- Eliminar los recursos cuando termines para evitar cargos
- Usar `./scripts/undeploy-all.sh --delete-all` para limpiar todo

### Diferencias con Azure AKS

| Concepto | Azure | AWS |
|----------|-------|-----|
| Registry | Azure Container Registry (ACR) | Elastic Container Registry (ECR) |
| Kubernetes | Azure Kubernetes Service (AKS) | Elastic Kubernetes Service (EKS) |
| CLI Setup | `az login` | `aws configure` |
| Cluster CLI | `az aks create` | `eksctl create cluster` |
| Kubeconfig | `az aks get-credentials` | `aws eks update-kubeconfig` |
| Login Registry | `az acr login` | `aws ecr get-login-password \| docker login` |
| LoadBalancer | Azure Load Balancer (IP) | AWS ELB (hostname DNS) |
| Costo Control Plane | Gratis | ~$0.10/hora |

### Pasos para desplegar en EKS

#### Paso 1: Configurar AWS (crear ECR y EKS)

Este script:
- Verifica tus credenciales de AWS
- Crea repositorios ECR para cada microservicio (con image scanning habilitado)
- Crea un cluster EKS con 2 nodos t3.medium usando eksctl
- Configura kubectl para conectarse al cluster
- Guarda la configuración en `eks-config.env`

```bash
cd eks
chmod +x scripts/*.sh
./scripts/eks-setup.sh [CLUSTER_NAME] [AWS_REGION]
```

Ejemplo con valores personalizados:
```bash
./scripts/eks-setup.sh mi-cluster us-west-2
```

Valores por defecto:
- CLUSTER_NAME: `expense-eks`
- AWS_REGION: `us-east-1`

> ⏱️ La creación del cluster EKS tarda ~15-20 minutos.

#### Paso 2: Construir y subir imágenes a ECR

Este script:
- Detecta automáticamente Docker o Podman
- Compila los proyectos con Maven
- Construye las imágenes Docker para `linux/amd64`
- Se autentica con ECR
- Sube las imágenes a ECR

```bash
./scripts/build-and-push-all.sh
```

#### Paso 3: Desplegar en EKS

Este script:
- Reemplaza las variables `${AWS_ACCOUNT_ID}` y `${AWS_REGION}` en el manifest
- Aplica los manifests de Kubernetes
- Espera a que los pods estén listos
- Muestra la URL del LoadBalancer (hostname DNS del ELB)

```bash
./scripts/deploy-all.sh
```

> **Nota**: AWS EKS usa un Elastic Load Balancer que expone un **hostname DNS** (no una IP directa como Azure). El DNS puede tardar 1-2 minutos en propagarse.

#### Paso 4: Verificar el despliegue

```bash
# Ver pods y servicios
kubectl get pods
kubectl get svc

# Probar el servicio (usar el hostname del ELB)
curl http://<ELB_HOSTNAME>:8080/expenses

# Si el ELB aún no está listo, usar port-forward
kubectl port-forward svc/expense-client 8081:8080
curl http://localhost:8081/expenses
```

### Scripts disponibles

| Script | Descripción |
|--------|-------------|
| `scripts/eks-setup.sh` | Crea repos ECR y cluster EKS |
| `scripts/build-and-push-all.sh` | Compila y sube imágenes a ECR |
| `scripts/deploy-all.sh` | Despliega en EKS |
| `scripts/undeploy-all.sh` | Elimina recursos de Kubernetes |
| `scripts/undeploy-all.sh --delete-all` | Elimina todo (K8s + EKS + ECR) |
| `scripts/diagnose.sh` | Diagnóstico de problemas |
| `scripts/cluster-info.sh` | Información del cluster |

### Manifiestos de Kubernetes

| Archivo | Descripción |
|---------|-------------|
| `k8s/expenses-all.yaml` | Despliegue completo WITH health probes |
| `k8s/expenses-all-no-probes.yaml` | Despliegue WITHOUT health probes (comparación) |

### Troubleshooting

#### Pod en estado ImagePullBackOff
```bash
# Verificar que las imágenes existen en ECR
aws ecr list-images --repository-name expense-service --region $AWS_REGION
aws ecr list-images --repository-name expense-client --region $AWS_REGION

# Verificar que el nodo puede acceder a ECR (permisos IAM)
kubectl describe pod -l app=expense-service
```

#### Pod en estado CrashLoopBackOff
```bash
# Ver logs del pod
kubectl logs -l app=expense-service --tail=50

# Si es por los health probes, desplegar la versión sin probes
kubectl apply -f k8s/expenses-all-no-probes.yaml
```

#### LoadBalancer sin hostname/IP
```bash
# Ver eventos del servicio
kubectl describe svc expense-client

# Puede tardar 1-2 minutos. Mientras tanto usar port-forward:
kubectl port-forward svc/expense-client 8081:8080
```

#### Permisos IAM insuficientes
```bash
# Verificar identidad actual
aws sts get-caller-identity

# El usuario/role necesita permisos para:
# - eks:* (cluster management)
# - ecr:* (registry)
# - ec2:* (nodos)
# - cloudformation:* (eksctl)
# - iam:* (service roles)
#
# Opción simple: usar AdministratorAccess (solo para desarrollo/lab)
```

### Limpieza

```bash
# Solo eliminar el despliegue (mantiene cluster y repos)
./scripts/undeploy-all.sh

# Eliminar TODO (cluster EKS + repos ECR)
./scripts/undeploy-all.sh --delete-all
```
