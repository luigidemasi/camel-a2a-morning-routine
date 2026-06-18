FROM registry.access.redhat.com/ubi9/nodejs-20:latest

USER 0

COPY dashboard/package*.json /opt/app-root/src/
WORKDIR /opt/app-root/src
RUN npm ci --production

COPY dashboard/ /opt/app-root/src/

RUN chown -R 1001:0 /opt/app-root/src && \
    chmod -R g=u /opt/app-root/src

USER 1001

EXPOSE 3000

CMD ["npm", "start"]
