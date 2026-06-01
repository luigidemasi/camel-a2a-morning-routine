import { ClientFactory, JsonRpcTransportFactory, RestTransportFactory, createAuthenticatingFetchWithRetry } from '@a2a-js/sdk/client';
import type { Client } from '@a2a-js/sdk/client';
import { oidcAuthHandler } from './oidc.js';

const clientCache = new Map<string, Client>();

const plainFactory = new ClientFactory();

const authFetch = createAuthenticatingFetchWithRetry(fetch, oidcAuthHandler);
const oidcFactory = new ClientFactory({
  transports: [
    new RestTransportFactory({ fetchImpl: authFetch }),
    new JsonRpcTransportFactory({ fetchImpl: authFetch }),
  ],
});

export async function getClient(agentUrl: string): Promise<Client> {
  let client = clientCache.get(agentUrl);
  if (!client) {
    client = await plainFactory.createFromUrl(agentUrl);
    clientCache.set(agentUrl, client);
  }
  return client;
}

export async function getOidcClient(agentUrl: string): Promise<Client> {
  const key = `oidc:${agentUrl}`;
  let client = clientCache.get(key);
  if (!client) {
    client = await oidcFactory.createFromUrl(agentUrl);
    clientCache.set(key, client);
  }
  return client;
}
