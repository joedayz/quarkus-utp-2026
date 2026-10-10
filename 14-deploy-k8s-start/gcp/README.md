## Demo: expense-service + expense-client en Google Cloud (GCP)

Cuatro formas de desplegar los mismos microservicios en GCP. Las imágenes se construyen localmente (`linux/amd64`) y se publican en **Artifact Registry**.

| Opción | Directorio | Qué es | Comunicación interna | Exposición |
|--------|-----------|--------|----------------------|------------|
| **GKE Autopilot** | `gke/` | Kubernetes administrado, Google gestiona los nodos | DNS K8s `expense-service:8080` | LoadBalancer (IP) |
| **GKE Standard** | `gke/` | Kubernetes con node pool propio (2x e2-medium) | DNS K8s | LoadBalancer (IP) |
| **Cloud Run** | `cloudrun/` | Contenedores serverless, escala a cero | URL `run.app` del backend (`ingress=internal`) | URL HTTPS pública del cliente |
| **Compute Engine + K3s** | `gce-k3s/` | K3s instalado en una VM e2-medium | DNS K8s | `http://IP_VM:8080` limitado a tu IP |

### Prerrequisitos

- `gcloud` con sesión iniciada (`gcloud auth login`) y un proyecto con **facturación habilitada**
- Docker o Podman, Maven
- GKE: `kubectl` y `gcloud components install gke-gcloud-auth-plugin`

### Paso común: proyecto y registro

```bash
cd gcp
./scripts/gcp-setup.sh <PROJECT_ID> [REGION]   # por defecto: proyecto activo de gcloud, us-central1
./scripts/build-and-push-all.sh
```

Habilita las APIs necesarias, crea el repositorio `expense` en Artifact Registry y guarda `gcp-config.env` (ignorado por git).

### Opción 1 y 2: GKE (Autopilot / Standard)

```bash
./gke/scripts/gke-setup.sh autopilot      # o: standard
./gke/scripts/deploy-all.sh
./gke/scripts/diagnose.sh                 # si algo falla
./gke/scripts/undeploy-all.sh --delete-all
```

El manifiesto compartido `k8s/expenses-all.yaml` define `requests` de CPU/memoria, necesarios para dimensionar y facturar en Autopilot. Los nodos acceden a Artifact Registry del mismo proyecto sin configuración extra.

### Opción 3: Cloud Run

```bash
./cloudrun/scripts/deploy-all.sh                    # backend solo interno
./cloudrun/scripts/deploy-all.sh --public-backend   # backend público (alternativa simple)
./cloudrun/scripts/undeploy-all.sh
```

Por defecto el backend usa `--ingress internal` y el cliente sale por la VPC `default` (Direct VPC egress, todo el tráfico) con Private Google Access, de modo que el backend no es accesible desde internet. Esto requiere la red `default`; si tu organización no la tiene, usa `--public-backend`. Los servicios son `--allow-unauthenticated`; si una política de organización lo impide, el despliegue fallará.

### Opción 4: Compute Engine + K3s

```bash
./gce-k3s/scripts/k3s-setup.sh [VM_NAME] [CIDR]   # CIDR por defecto: tu IP pública /32
./gce-k3s/scripts/deploy-all.sh
./gce-k3s/scripts/undeploy-all.sh --delete-all
```

Las imágenes se transfieren por SSH a la VM (`save` → `ctr images import`), por lo que no se guardan credenciales de registro en ella. Es la opción con más mantenimiento: parches del SO, actualizaciones de K3s y disponibilidad de un solo nodo dependen de ti.

### Limpieza

```bash
./gke/scripts/undeploy-all.sh --delete-all
./cloudrun/scripts/undeploy-all.sh
./gce-k3s/scripts/undeploy-all.sh --delete-all
./scripts/delete-registry.sh
```

### Costos (orientativo, verifica precios actuales)

⚠️ Todo lo que dejes corriendo genera cargos: GKE cobra cómputo y balanceador (más cargo de clúster según el nivel gratuito aplicable), la VM de K3s cobra mientras exista y Cloud Run cobra por uso, con escala a cero. Elimina los recursos al terminar.

### Resumen de decisión

- **Completar la comparación con EKS/AKS** → GKE Autopilot
- **Aprender administración de nodos** → GKE Standard
- **Demo de bajo tráfico y costo** → Cloud Run
- **Entender Kubernetes “a mano” en una VM** → Compute Engine + K3s
