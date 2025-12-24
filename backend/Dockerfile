FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Copy prisma schema BEFORE npm install (needed for prisma generate)
COPY prisma/ ./prisma/

# Copy source code and config (needed for build)
COPY src/ ./src/
COPY tsconfig.json ./

# Install ALL dependencies (including dev deps for build)
# Use --legacy-peer-deps for chromadb compatibility with openai@6
RUN npm ci --legacy-peer-deps

# Build the application (creates dist/)
# Note: This runs again to ensure clean build after all files are present
RUN npm run build

# Remove dev dependencies to reduce image size
# Use --ignore-scripts to prevent postinstall from running again (dist/ already exists)
RUN npm ci --omit=dev --legacy-peer-deps --ignore-scripts

# Expose port
EXPOSE 3000

# Start both the API server and scheduler worker
CMD npx concurrently --kill-others "node dist/server.js" "node dist/worker.js"