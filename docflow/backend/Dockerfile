# syntax=docker/dockerfile:1

# Node 22 on Alpine: small image, native fetch/FormData/Blob so the Stirling
# client needs no HTTP dependency at all.
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

# Copy manifests first so `npm ci` is cached until dependencies actually change.
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src

# Run as the image's built-in unprivileged user. Files only ever live in this
# process's heap, so the container needs no writable volume.
USER node

# Azure Container Apps sets PORT; 8080 is the default target port.
ENV PORT=8080
EXPOSE 8080

CMD ["node", "src/server.js"]
