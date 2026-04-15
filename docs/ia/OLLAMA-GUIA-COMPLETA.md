# 🦙 Guía Completa de Ollama para el Curso

## ¿Qué es Ollama?

Ollama es una herramienta que permite ejecutar **Large Language Models (LLMs) localmente** en tu máquina. Es como tener tu propio ChatGPT corriendo en tu laptop, sin necesidad de internet ni API keys.

## 🎯 Por Qué Usar Ollama en el Curso

### Para Estudiantes
- ✅ **Gratis e ilimitado**: No necesitan gastar en APIs
- ✅ **Aprenden más**: Ven cómo funcionan los modelos "por dentro"
- ✅ **Experimentación**: Pueden probar sin miedo a consumir cuota
- ✅ **Privacidad**: Datos sensibles no salen de su máquina

### Para el Instructor
- ✅ **Demos sin depender de internet**: Funciona offline
- ✅ **Comparación didáctica**: Cloud vs Local
- ✅ **Costo cero**: Los estudiantes no necesitan tarjeta de crédito
- ✅ **Alternativa real**: Es lo que se usa en producción para ciertos casos

---

## 📦 Instalación Paso a Paso

### macOS
```bash
# Opción 1: Homebrew (recomendado)
brew install ollama

# Opción 2: Manual
curl -fsSL https://ollama.com/install.sh | sh
```

### Linux (Ubuntu/Debian)
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Windows
1. Descargar instalador: https://ollama.com/download
2. Ejecutar el instalador
3. Verificar instalación en terminal: `ollama --version`

### Verificar Instalación
```bash
ollama --version
# Debería mostrar algo como: ollama version 0.1.x
```

---

## 🚀 Primeros Pasos

### 1. Iniciar Ollama
```bash
# En macOS/Linux, normalmente se inicia automáticamente
# Si no, ejecutar:
ollama serve

# Verificar que está corriendo:
curl http://localhost:11434/api/version
```

### 2. Descargar Tu Primer Modelo

#### Mistral (Recomendado para empezar)
```bash
ollama pull mistral
```
- **Tamaño**: 4.1 GB
- **RAM necesaria**: 8 GB
- **Ventajas**: Excelente en español, rápido, propósito general

#### Llama 3.2 (Más ligero)
```bash
ollama pull llama3.2
```
- **Tamaño**: 2 GB
- **RAM necesaria**: 4 GB
- **Ventajas**: Muy rápido, corre en laptops modestas

#### CodeLlama (Para código)
```bash
ollama pull codellama
```
- **Tamaño**: 3.8 GB
- **RAM necesaria**: 8 GB
- **Ventajas**: Especializado en generar código

### 3. Probar el Modelo
```bash
ollama run mistral

>>> Hola, ¿cómo estás?
# El modelo responderá...

# Salir con: /bye o Ctrl+D
```

---

## 📚 Modelos Disponibles y Recomendaciones

### Para el Curso (ordenados por prioridad)

| Modelo | Tamaño | RAM | CPU/GPU | Mejor Para | Descargar |
|--------|---------|-----|---------|------------|-----------|
| **mistral** | 4.1 GB | 8 GB | CPU: Bien | General, español | `ollama pull mistral` |
| **llama3.2** | 2 GB | 4 GB | CPU: Muy bien | Rápido, básico | `ollama pull llama3.2` |
| **phi3** | 2.3 GB | 4 GB | CPU: Muy bien | Eficiente, estudiantes | `ollama pull phi3` |
| **codellama** | 3.8 GB | 8 GB | CPU: Bien | Código Java | `ollama pull codellama` |
| **gemma** | 2.9 GB | 6 GB | CPU: Bien | Por Google | `ollama pull gemma` |

### Recomendaciones por Máquina

#### Laptop Modesta (4-8 GB RAM)
```bash
ollama pull phi3 
# o
ollama pull llama3.2
```

#### Laptop Moderna (16+ GB RAM)
```bash
ollama pull mistral
ollama pull codellama  # Opcional para ejercicios de código
```

#### Con GPU NVIDIA
```bash
# Ollama detecta GPU automáticamente
ollama pull mistral
# Será MUCHO más rápido
```

---

## 🔧 Uso desde Java

### Diferencia Clave: NO SE NECESITA API KEY

#### OpenAI (necesita API key)
```java
String url = "https://api.openai.com/v1/chat/completions";
HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create(url))
    .header("Authorization", "Bearer " + apiKey) // ← API KEY
    .header("Content-Type", "application/json")
    .POST(...)
    .build();
```

#### Ollama (sin API key)
```java
String url = "http://localhost:11434/v1/chat/completions";
HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create(url))
    // ← No se necesita Authorization!
    .header("Content-Type", "application/json")
    .POST(...)
    .build();
```

### Body del Request (Idéntico)
```json
{
  "model": "mistral",
  "messages": [
    {"role": "user", "content": "Hola"}
  ],
  "stream": false
}
```

### Response (Idéntico a OpenAI)
```json
{
  "model": "mistral",
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "¡Hola! ¿Cómo puedo ayudarte?"
    }
  }],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 20,
    "total_tokens": 30
  }
}
```

---

## 🎓 Integración en el Curso

### Clase 2 (Opcional - 5 minutos)
**Mención rápida:**
> "Si no quieren gastar en APIs, existe Ollama que corre modelos localmente. Es gratis y la API es idéntica. Lo veremos en detalle más adelante."

### Clase 3 (Recomendado - 15 minutos)
**Demo práctica:**
1. Mostrar instalación rápida
2. Descargar un modelo pequeño (phi3)
3. Modificar código de fase1 para usar Ollama
4. Comparar velocidad y respuestas

**Script para clase:**
```bash
# 1. Verificar instalación (1 min)
ollama --version

# 2. Descargar modelo (2 min)
ollama pull phi3

# 3. Listar modelos (1 min)
ollama list

# 4. Probar desde terminal (2 min)
ollama run phi3 "Explica qué es un LLM en una frase"

# 5. Desde Java (9 min)
cd fase1-ollama-start
# Completar los TODOs en vivo
mvn clean compile exec:java
```

### Clase Dedicada (Opcional - 30-45 minutos)
**Tema:** "Modelos Locales vs APIs en la Nube"

**Contenido:**
1. Arquitectura de Ollama
2. Cuándo usar local vs cloud
3. Optimización de rendimiento
4. Casos de uso reales

---

## 🆚 Ollama vs OpenAI: Tabla Comparativa

| Aspecto | Ollama | OpenAI/Anthropic |
|---------|--------|------------------|
| **Costo** | Gratis | $0.002-0.06 por 1k tokens |
| **Velocidad** | Depende de tu CPU/GPU | Generalmente más rápido |
| **Calidad** | Buena (7-8/10) | Excelente (9-10/10) |
| **Privacidad** | Total (local) | Los datos van a servidores |
| **Internet** | No necesita (post-descarga) | Siempre necesario |
| **Setup** | Requiere instalación | Solo API key |
| **Hardware** | Necesitas RAM+CPU | No importa |
| **Rate Limits** | Ninguno | Sí (depende del plan) |
| **Modelos** | Open source | Propietarios |
| **Multimodal** | Limitado | Sí (visión, audio) |

---

## 💡 Casos de Uso Reales

### ✅ Cuándo Usar Ollama

1. **Desarrollo y Testing**
   - Iterar rápido sin consumir cuota
   - Pruebas automatizadas (CI/CD)

2. **Privacidad Crítica**
   - Datos médicos, legales, financieros
   - Cumplimiento normativo (GDPR, HIPAA)

3. **Sin Conectividad**
   - Ambientes air-gapped
   - Deployments edge

4. **Costo Sensible**
   - Startups en fase inicial
   - Proyectos educativos
   - Alta frecuencia de uso

### ✅ Cuándo Usar APIs en la Nube

1. **Calidad Crítica**
   - Chatbots customer-facing
   - Generación de contenido profesional

2. **Hardware Limitado**
   - Aplicaciones móviles
   - Serverless

3. **Modelos Especializados**
   - GPT-4 para razonamiento complejo
   - Claude para contexto largo (100k+ tokens)

4. **Producción de Alto Volumen**
   - Paralelización masiva
   - Baja latencia consistente

---

## 🛠️ Comandos Útiles

### Gestión de Modelos
```bash
# Listar modelos instalados
ollama list

# Descargar modelo
ollama pull <modelo>

# Eliminar modelo
ollama rm <modelo>

# Ver información de un modelo
ollama show mistral

# Ver cuánto espacio usan
du -sh ~/.ollama/models/
```

### Control del Servidor
```bash
# Iniciar servidor
ollama serve

# Ver logs
ollama logs

# Detener (Ctrl+C en la terminal donde corre)
```

### API Directa
```bash
# Verificar que está corriendo
curl http://localhost:11434/api/version

# Listar modelos vía API
curl http://localhost:11434/api/tags

# Chat vía API
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral",
    "messages": [{"role": "user", "content": "Hola"}]
  }'
```

---

## ⚠️ Troubleshooting Común

### "Connection refused"
**Problema:** Ollama no está corriendo
**Solución:**
```bash
ollama serve
# O reiniciar: 
brew services restart ollama  # macOS
```

### "Model not found"
**Problema:** Modelo no descargado
**Solución:**
```bash
ollama pull mistral
```

### "Out of memory"
**Problema:** Modelo muy grande para tu RAM
**Solución:**
```bash
# Usar modelo más pequeño
ollama pull phi3
```

### Respuestas Muy Lentas
**Causas:**
1. CPU sin AVX2 (procesadores antiguos)
2. Sin suficiente RAM (swapping)
3. Modelo muy grande

**Soluciones:**
```bash
# Usar modelo más pequeño
ollama pull phi3

# Verificar uso de memoria
top  # o htop

# Cerrar otras aplicaciones
```

### Puerto 11434 Ya en Uso
**Problema:** Otro proceso usa el puerto
**Solución:**
```bash
# Ver qué proceso usa el puerto
lsof -i :11434

# Matar el proceso
kill -9 <PID>
```

---

## 📊 Performance: Qué Esperar

### En Laptop Moderna (M1/M2 Mac, i7/Ryzen reciente)
- **Mistral**: ~20-40 tokens/segundo
- **Phi3**: ~40-60 tokens/segundo
- **Primera carga**: 5-10 segundos (carga del modelo)
- **Siguientes**: respuesta inmediata

### En Laptop Modesta (>5 años)
- **Phi3**: ~5-15 tokens/segundo
- **Mistral**: ~2-10 tokens/segundo
- **Tiempo total**: 10-30 segundos por respuesta

### Con GPU NVIDIA (RTX 3060+)
- **Cualquier modelo**: 50-100+ tokens/segundo
- **Experiencia**: comparable a GPT-3.5

---

## 🎯 Ejercicios para Estudiantes

### Básico
1. Instalar Ollama
2. Descargar 2 modelos diferentes
3. Comparar sus respuestas a la misma pregunta
4. Medir tiempo de respuesta

### Intermedio
1. Integrar Ollama en fase1-start
2. Crear script que detecte si está disponible
3. Fallback a OpenAI si Ollama no está disponible

### Avanzado
1. Crear comparador de modelos (velocidad + calidad)
2. Implementar caché de respuestas
3. Sistema híbrido: Ollama para dev, OpenAI para prod

---

## 📖 Recursos Adicionales

- **Documentación oficial**: https://github.com/ollama/ollama
- **Lista completa de modelos**: https://ollama.com/library
- **API Reference**: https://github.com/ollama/ollama/blob/main/docs/api.md
- **Comparativas de modelos**: https://huggingface.co/spaces/lmsys/chatbot-arena-leaderboard
- **Community Discord**: https://discord.gg/ollama

---

## 💬 FAQ del Curso

**P: ¿Debo exigir que todos instalen Ollama?**
R: No. Hazlo opcional. Algunos estudiantes pueden tener máquinas modestas.

**P: ¿Qué modelo recomiendas para la clase?**
R: Mistral. Es el mejor balance calidad/velocidad/tamaño.

**P: ¿Puedo usar Ollama en examenes/proyectos?**
R: Sí, es una opción válida. Incluso pueden mezclar (dev con Ollama, prod con OpenAI).

**P: ¿Funciona en Windows?**
R: Sí, pero requiere WSL2. La experiencia en Mac/Linux es mejor.

**P: ¿Vale la pena para el curso?**
R: Sí, al menos como demo. Les muestra que hay alternativas y cómo funcionan los LLMs "por dentro".

---

**Última actualización:** Marzo 2026
