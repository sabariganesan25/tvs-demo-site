FROM node:20-alpine AS web
WORKDIR /app/frontend
COPY frontend/package.json ./
RUN npm install
COPY frontend ./
RUN npm run build
FROM python:3.11-slim
WORKDIR /app/backend
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY backend ./
COPY --from=web /app/frontend/dist /app/frontend/dist
RUN useradd -m portal && mkdir -p /app/logs && chown -R portal:portal /app
USER portal
CMD ["sh","-c","gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind 0.0.0.0:${PORT:-8000} --timeout 60"]
