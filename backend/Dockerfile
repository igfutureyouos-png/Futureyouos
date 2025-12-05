FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including dev deps for build)
# Use --legacy-peer-deps for chromadb compatibility with openai@6
RUN npm ci --legacy-peer-deps

# Copy source code
COPY src/ ./src/
COPY prisma/ ./prisma/
COPY tsconfig.json ./

# Build the application (creates dist/)
RUN npm run build

# Remove dev dependencies to reduce image size
RUN npm ci --only=production --legacy-peer-deps

# Expose port
EXPOSE 3000

# Start the scheduler worker
CMD ["node", "dist/workers/scheduler.worker.js"]