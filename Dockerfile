# syntax=docker/dockerfile:1.7

############################
# Base común
############################
FROM node:20-slim AS base
WORKDIR /app
ENV NODE_ENV=production
# Evita que Node intente usar color/interactivo en logs CI
ENV CI=true

############################
# Etapa deps (con dev deps)
############################
FROM base AS deps
# Aprovecha cache de npm
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

############################
# Etapa build
############################
FROM deps AS builder
COPY . .
# Compila y luego elimina dev deps, dejando solo prod
RUN npm run build && npm prune --omit=dev

############################
# Etapa runtime (solo prod)
############################
FROM base AS runner
# Copia sólo lo necesario para correr
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# (Opcional) si tu app sirve assets estáticos fuera de dist, copia aquí:
# COPY --from=builder /app/public ./public

# Corre como usuario no root (la imagen oficial tiene 'node')
USER node

EXPOSE 3000

# Healthcheck ligero sin dependencias
#HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD node -e "http=require('http');req=http.get({host:'127.0.0.1',port:3000,path:'/health'},r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1));"

CMD ["node", "dist/main.js"]
