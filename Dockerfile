# ========== deps ==========
FROM node:20-alpine AS deps
WORKDIR /app

# Toolchain para compilar deps nativas (bcrypt, sharp, etc.)
RUN apk add --no-cache python3 make g++

# Afinar NPM para CI (menos ruido y timeouts más altos)
RUN npm config set fund false \
 && npm config set audit false \
 && npm config set progress false \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm config set fetch-timeout 120000 \
 && npm config set prefer-online true \
 && npm config set registry https://registry.npmjs.org/

COPY package*.json ./
RUN npm ci --no-audit --no-fund

# ========== build ==========
FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ========== runtime ==========
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
# Instala solo runtime deps (sin dev), usando el lockfile ya resuelto
COPY --from=deps /app/package-lock.json ./
RUN apk add --no-cache python3 make g++ \
 && npm ci --omit=dev --no-audit --no-fund \
 && apk del python3 make g++

COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["node","dist/main.js"]
