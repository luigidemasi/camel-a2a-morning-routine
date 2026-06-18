FROM registry.access.redhat.com/ubi9/nodejs-20:latest

WORKDIR /app

COPY dashboard/package*.json ./
RUN npm ci --production

COPY dashboard/ .

EXPOSE 3000

CMD ["npm", "start"]
