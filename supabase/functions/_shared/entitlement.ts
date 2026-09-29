// Signed entitlement token "mh1": mh1.<b64url(payload)>.<b64url(RS256 signature over "mh1.<b64url(payload)>")>
// Must stay byte-compatible with game/platform/mh_entitlement_token.gd.
import { b64url, importRsaPrivateKey, rs256Sign, sha256hex } from "./crypto.ts";

export interface EntitlementPayload {
  v: 1;
  pkg: string;
  pid: string; // product id
  ord: string; // Google order id (GPA.xxxx) or ""
  pth: string; // first 16 hex of sha256(purchase token): lets support correlate without storing the token
  iat: number; // unix seconds
  ref: number; // unix seconds: client should re-verify online after this; still honoured offline
}

export const REFRESH_AFTER_SECONDS = 90 * 24 * 3600;

export async function signEntitlement(
  privateKeyPem: string,
  pkg: string,
  productId: string,
  orderId: string,
  purchaseToken: string,
  nowSeconds: number = Math.floor(Date.now() / 1000),
): Promise<string> {
  const payload: EntitlementPayload = {
    v: 1,
    pkg,
    pid: productId,
    ord: orderId,
    pth: (await sha256hex(purchaseToken)).slice(0, 16),
    iat: nowSeconds,
    ref: nowSeconds + REFRESH_AFTER_SECONDS,
  };
  const key = await importRsaPrivateKey(privateKeyPem);
  const body = "mh1." + b64url(new TextEncoder().encode(JSON.stringify(payload)));
  return body + "." + (await rs256Sign(key, body));
}

/** Short-lived attestation issued by verify-integrity. Different prefix so it can never be mistaken for an entitlement. */
export async function signIntegrityAttestation(
  privateKeyPem: string,
  pkg: string,
  action: string,
  nowSeconds: number = Math.floor(Date.now() / 1000),
): Promise<string> {
  const payload = { v: 1, kind: "integrity", pkg, action, iat: nowSeconds, exp: nowSeconds + 600 };
  const key = await importRsaPrivateKey(privateKeyPem);
  const body = "mhi1." + b64url(new TextEncoder().encode(JSON.stringify(payload)));
  return body + "." + (await rs256Sign(key, body));
}
