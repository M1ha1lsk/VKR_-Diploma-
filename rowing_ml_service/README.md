# Rowing ML Service

Сервис инференса для `rowing_tracker` (клиент-серверная схема).

## Составляющие

- `models/` — только файлы модели (ожидается `real_model_bundle.joblib`)
- `tmp/` — временные файлы (если понадобятся)
- `app/api_server.py` — HTTP API (`/health`, `/predict`)
