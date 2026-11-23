# --- Stage 1: Build ---
# Node wird nur zum Bauen gebraucht und landet nicht im finalen Image.
FROM node:24-alpine AS build
WORKDIR /app

# Lockfile zuerst kopieren: der npm-ci-Layer wird nur bei Dependency-Änderungen neu gebaut.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Vite kompiliert diese Werte fest ins JS-Bundle ein, daher Build-ARG (nicht Runtime-ENV).
ARG VITE_API_BASE_URL
ARG VITE_IMGS=items
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_IMGS=$VITE_IMGS
RUN npm run build

# --- Stage 2: Runtime ---
# Nur statische Dateien + nginx, kein Node, kein Quellcode.
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY security-headers.conf /etc/nginx/security-headers.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1
