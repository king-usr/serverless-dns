# Multi-stage build for serverless-dns
FROM node:18-alpine AS base

# Install security updates and tools
RUN apk update && apk upgrade && apk add --no-cache dumb-init

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN if [ -f package-lock.json ]; then \
      npm ci --only=production && npm cache clean --force; \
    else \
      npm install --only=production && npm cache clean --force; \
    fi

# Copy source code
COPY . .

# Build if build script exists
RUN if npm run | grep -q "build"; then \
      npm run build; \
    else \
      echo "No build script found, skipping build"; \
    fi

# Production stage
FROM node:18-alpine AS production

RUN apk add --no-cache dumb-init curl

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

WORKDIR /app

# Copy built application
COPY --from=base --chown=nextjs:nodejs /app .

# Set environment
ENV NODE_ENV=production
ENV PORT=8080

USER nextjs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/dns-query || exit 1

EXPOSE 8080 8053 5053

# Use dumb-init to handle signals properly
CMD ["dumb-init", "node", "src/server-node.js"]
