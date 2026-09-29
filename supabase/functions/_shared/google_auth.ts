// Service-account OAuth2 (JWT bearer) using only WebCrypto. No Google SDK needed.
// https://developers.google.com/identity/protocols/oauth2/service-account#httprest
import { b64url, importRsaPrivateKey, rs256Sign } from "./crypto.ts";

export interface ServiceAccount {
  client_email: string;
  private_key: string; // PKCS#8 PEM from the JSON key file
}

const cache = new Map<string, { token: string; expiresAtMs: number }>();

export async function getAccessToken(sa: ServiceAccount, scopes: string[]): Promise<string> {
  const scope = scopes.join(" ");
  const hit = cache.get(scope);
  if (hit && hit.expiresAtMs - Date.now() > 60_000) return hit.token;

  const now = Math.floor(Date.now() / 1000);
  const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));
  const unsigned = `${enc({ alg: "RS256", typ: "JWT" })}.${enc({
    iss: sa.client_email,
    scope,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;
  const sig = await rs256Sign(await importRsaPrivateKey(sa.private_key), unsigned);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${sig}`,
    }),
  });
  if (!res.ok) throw new Error(`token endpoint ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const body = await res.json();
  cache.set(scope, { token: body.access_token, expiresAtMs: Date.now() + Number(body.expires_in ?? 3600) * 1000 });
  return body.access_token;
}

export function parseServiceAccount(jsonText: string): ServiceAccount {
  const o = JSON.parse(jsonText);
  if (!o.client_email || !o.private_key) throw new Error("service account JSON missing client_email/private_key");
  return { client_email: o.client_email, private_key: o.private_key };
}
