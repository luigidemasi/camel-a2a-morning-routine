import { KEYCLOAK } from '../config.js';

let cachedToken: string | null = null;
let tokenExpiry = 0;

async function fetchToken(): Promise<string> {
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: KEYCLOAK.clientId,
    client_secret: KEYCLOAK.clientSecret,
  });

  const res = await fetch(KEYCLOAK.tokenEndpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    throw new Error(`OIDC token request failed: ${res.status} ${res.statusText}`);
  }

  const data = await res.json() as { access_token: string; expires_in: number };
  cachedToken = data.access_token;
  tokenExpiry = Date.now() + (data.expires_in - 30) * 1000;
  return cachedToken;
}

export async function getToken(): Promise<string> {
  if (cachedToken && Date.now() < tokenExpiry) {
    return cachedToken;
  }
  return fetchToken();
}

export function invalidateToken(): void {
  cachedToken = null;
  tokenExpiry = 0;
}

export const oidcAuthHandler = {
  headers: async () => ({ Authorization: `Bearer ${await getToken()}` }),
  shouldRetryWithHeaders: async (_req: RequestInit, res: Response) => {
    if (res.status === 401 || res.status === 403) {
      invalidateToken();
      return { Authorization: `Bearer ${await getToken()}` };
    }
    return undefined;
  },
};
