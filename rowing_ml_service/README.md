# Rowing ML Service

Сервис инференса для `rowing_tracker` (клиент-серверная схема).

## Что хранится здесь

- `models/` — только файлы модели (ожидается `real_model_bundle.joblib`)
- `tmp/` — временные файлы (если понадобятся)
- `app/api_server.py` — HTTP API (`/health`, `/predict`)

## Запуск

Из родительской директории `C:\Users\mikha\MAI_study`:

```bash
docker compose up --build rowing-ml-api
```

Сервис будет доступен на `http://localhost:8000`.
