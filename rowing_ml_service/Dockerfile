FROM python:3.11-slim

WORKDIR /app

COPY rowing_ml_service/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY rowing_ml_service/app/api_server.py /app/api_server.py
COPY rowing_ml_service/app/features_v2.py /app/features_v2.py
COPY rowing_ml_service/app/wr_curve.py /app/wr_curve.py
COPY rowing_ml_service/models /app/models
COPY rowing_ml_service/tmp /app/tmp

EXPOSE 8000

CMD ["uvicorn", "api_server:app", "--host", "0.0.0.0", "--port", "8000"]
