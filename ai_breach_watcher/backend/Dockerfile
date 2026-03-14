FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends git curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Initialize git repo for skill versioning
RUN git config --global user.email "breach-watcher@local" && \
    git config --global user.name "Breach Watcher" && \
    cd /app && git init && git add -A && git commit -m "initial" --allow-empty || true

EXPOSE 8000

CMD ["uvicorn", "src.api.app:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
