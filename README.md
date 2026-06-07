# Sistema RAG de noticias de tecnología e IA (con información actualizada)

Servicio RAG (Retrieval-Augmented Generation) que responde preguntas sobre
noticias de tecnología e inteligencia artificial. Se despliega como un
**servidor REST (FastAPI)** reproducible con Docker e incorpora un **pipeline
de actualización** (ingesta por RSS, indexado incremental y poda por
antigüedad) para mantener la base de conocimiento al día.

## Componentes

| Componente | Tecnología | Función |
|---|---|---|
| Modelo de embeddings | `intfloat/multilingual-e5-large` (1024D) | Vectoriza documentos y consultas (prefijos `passage:` / `query:`) |
| Base vectorial | Qdrant + índice HNSW | Almacena vectores y metadatos; búsqueda ANN y filtrada |
| Recuperación | Vectorial + reranking BM25 | Búsqueda híbrida (70% vectorial / 30% léxico) |
| LLM | OpenAI GPT-4o-mini | Genera la respuesta a partir del contexto recuperado |
| API | FastAPI + Uvicorn | Servicio REST del producto |
| Ingesta | feedparser (RSS) + APScheduler | Recolección y actualización periódica |

## Arquitectura

Dos planos desacoplados (ver `documento/` para el diagrama y la justificación):

- **Consulta:** usuario → API → embedding de la pregunta → búsqueda en Qdrant
  (con filtros de recencia/fuente) → reranking híbrido → prompt con contexto y
  citas → LLM → respuesta + fuentes.
- **Ingesta:** scheduler → descarga RSS → limpieza HTML → deduplicación →
  chunking → embeddings → `upsert` idempotente en Qdrant → poda por TTL.

## Requisitos

- Docker y Docker Compose (recomendado), o Python 3.11+.
- Clave de API de OpenAI (sin ella, el sistema responde en modo
  extractivo devolviendo el contexto recuperado).

## Ejecución con Docker (recomendado)

```bash
cp .env.example .env          # editar OPENAI_API_KEY
docker compose up -d --build  

# Indexar el corpus de muestra (demo sin red)
curl -X POST http://localhost:8000/ingest/sample

# Preguntar
curl -X POST http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "¿Qué novedades hay sobre modelos de lenguaje?"}'
```

Documentación interactiva de la API en `http://localhost:8000/docs`.

## Ejecución en local (sin Docker)

```bash
docker compose up -d qdrant            # solo la base vectorial
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
python -m scripts.ingest_sample        # carga muestra
```

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/health` | Estado del servicio y nº de vectores |
| GET | `/stats` | Vectores indexados |
| POST | `/ask` | Pregunta → respuesta RAG + fuentes |
| POST | `/ingest/sample` | Indexa el corpus de muestra |
| POST | `/ingest/rss` | Descarga e indexa desde feeds RSS |
| POST | `/maintenance/prune` | Borra noticias obsoletas (TTL) |

Ejemplo de consulta con filtro de recencia:

```bash
curl -X POST http://localhost:8000/ask -H "Content-Type: application/json" -d '{
  "question": "¿Cómo regula Europa la IA?",
  "published_after": "2026-03-01T00:00:00+00:00"
}'
```

## Actualización automática

Activa el planificador definiendo en `.env`:

```
ENABLE_SCHEDULER=true
RSS_FEEDS=https://techcrunch.com/feed/,https://www.theverge.com/rss/index.xml
UPDATE_EVERY_MINUTES=30
TTL_DAYS=30
```

Cada `UPDATE_EVERY_MINUTES` el sistema descarga las noticias nuevas, las indexa
(añadiendo, actualizando o ignorando según su `content_hash`) y elimina las
publicadas hace más de `TTL_DAYS` días.

## Estructura

```
rag_noticias/
├── app/
│   ├── config.py        # configuración por variables de entorno
│   ├── embeddings.py    # e5-large con prefijos query/passage
│   ├── vectorstore.py   # Qdrant: HNSW, upsert idempotente, update, TTL, búsqueda
│   ├── ingestion.py     # RSS + limpieza + dedup + chunking + indexado
│   ├── rag.py           # recuperación + reranking híbrido + prompt + LLM
│   ├── scheduler.py     # actualización periódica (APScheduler)
│   └── main.py          # API FastAPI
├── data/
│   ├── sample_articles.json
│   └── feeds.txt
├── scripts/ingest_sample.py
├── Dockerfile
├── docker-compose.yaml
├── requirements.txt
└── .env.example
```

