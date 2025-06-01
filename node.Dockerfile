# Stage 1: Setup - Install dependencies and perform initial build/download
FROM node:22 as setup
# Use a specific Node.js version for consistency, e.g., node:22.16.0 or node:20
# Ensure you have 'git' for clone if needed, or if not, remove this line.
RUN apt-get update && apt-get install git -yq --no-install-suggests --no-install-recommends

WORKDIR /app
# Copy everything from your project root into /app in the setup stage
COPY . .

# Install all dependencies (including dev dependencies for build process if necessary)
RUN npm install

# Optional: If BLOCKLIST_DOWNLOAD_ONLY=true is meant to run here
# You should verify that `node ./src/server-node.js` actually handles this flag
# and performs the download. If not, you might need a separate script.
# For now, let's assume it works.
# RUN export BLOCKLIST_DOWNLOAD_ONLY=true && node ./src/server-node.js

# Stage 2: Runner - The final, lean image for running the application
FROM node:22-alpine AS runner
# Use a specific Node.js version for consistency, e.g., node:22.16.0-alpine3.19
# or if you prefer consistency with the setup stage, just node:22-alpine

ENV NODE_ENV production
ENV NODE_OPTIONS="--max-old-space-size=200 --heapsnapshot-signal=SIGUSR2"
# Crucially, ensure BLOCKLIST_DOWNLOAD_ONLY is false or unset for runtime
ENV BLOCKLIST_DOWNLOAD_ONLY=false

WORKDIR /app

# --- BEGIN DEBUGGING COPIED FILES ---
# Add these lines to see what's actually being copied
RUN mkdir -p /app/debug_check
RUN ls -Fla /app/debug_check
# --- END DEBUGGING COPIED FILES ---


# Copy only the necessary files from the setup stage to the runner stage
# Copy node_modules (production dependencies only if possible, or all)
COPY --from=setup /app/node_modules ./node_modules/

# Copy the entire src directory (containing server-node.js)
COPY --from=setup /app/src ./src/

# Copy static assets (blocklists__, dbip__)
COPY --from=setup /app/blocklists__ ./blocklists__/
COPY --from=setup /app/dbip__ ./dbip__/

# Copy package.json and package-lock.json (needed by npm start)
COPY --from=setup /app/package.json ./package.json
COPY --from=setup /app/package-lock.json ./package-lock.json


# --- BEGIN MORE DEBUGGING COPIED FILES ---
# After copying, check if the files exist in the runner stage
RUN ls -Fla /app/
RUN ls -Fla /app/src/
# --- END MORE DEBUGGING COPIED FILES ---


# Set the entrypoint to run the application using npm start
# This will execute the "start" script defined in your package.json (node src/server-node.js)
ENTRYPOINT ["npm", "start"]
# If "npm start" fails for some reason, you can revert to directly calling node:
# ENTRYPOINT ["node", "./src/server-node.js"]
