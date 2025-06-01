FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:18-alpine AS runtime

RUN apk add --no-cache dumb-init
ENV NODE_ENV production
ENV PORT 8080

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .

USER node
EXPOSE 8080 5053/udp 5054

CMD ["dumb-init", "node", "src/server-node.js"]
