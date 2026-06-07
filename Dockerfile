FROM python:3.11-slim

WORKDIR /srv

# Dependencias del sistema mínimas
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY data ./data
COPY scripts ./scripts

# Caché de modelos de Hugging Face (se monta como volumen en docker-compose)
ENV HF_HOME=/srv/.cache/huggingface
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
