export const AGENTS = {
  assistant: 'http://localhost:8090',
  traffic: 'http://localhost:8083',
  email: 'http://localhost:8084',
  package: 'http://localhost:8085',
} as const;

export const KEYCLOAK = {
  tokenEndpoint: process.env.KEYCLOAK_TOKEN_ENDPOINT ?? 'http://localhost:8180/realms/a2a-morning-routine/protocol/openid-connect/token',
  clientId: process.env.KEYCLOAK_CLIENT_ID ?? 'assistant-agent',
  clientSecret: process.env.KEYCLOAK_CLIENT_SECRET ?? 'assistant-agent-secret',
} as const;

export const BFF_PORT = 3000;
export const BFF_WEBHOOK_URL = `http://localhost:${BFF_PORT}/webhook/package`;
