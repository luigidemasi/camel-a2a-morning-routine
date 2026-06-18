# Dockerfile for Node.js dashboard
# Build with: docker build -f dockerfiles/dashboard.Dockerfile -t dashboard .

FROM registry.access.redhat.com/ubi9/nodejs-20:latest

WORKDIR /app

# Install dependencies
COPY dashboard/package*.json ./
RUN npm ci --production

# Copy application source
COPY dashboard/ .

EXPOSE 3000

CMD ["npm", "start"]
