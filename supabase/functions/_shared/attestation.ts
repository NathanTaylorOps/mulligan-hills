// Verify the short-lived "mhi1" integrity attestation minted by verify-integrity (signEntitlement's sibling in
// entitlement.ts). Needs the PUBLIC key (SPKI PEM, secret ENTITLEMENT_PUBLIC_KEY_PEM): the same public key that is
// compiled into the game as MHPlatformConfig.ENTITLEMENT_PUBLIC_KEY_PEM.
import { b64urlDecode, pemToDer } from "./crypto.ts";

export async function importRsaPublicKey(pem: string): Promise<CryptoKey> {
  const normalized = pem.includes("\\n") ? pem.replace(/\\n/g, "\n") : pem;
  return await crypto.subtle.importKey("spki", pemToDer(normalized), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
}

export interface AttestationCheck { ok: boolean; reason: string }

export async function verifyIntegrityAttestation(
  publicKey: CryptoKey, token: unknown, expectedPkg: string, expectedAction: string, nowSeconds: number,
): Promise<AttestationCheck> {
  if (typeof token !== "string" || token.length > 2048) return { ok: false, reason: "missing_attestation" };
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== "mhi1") return { ok: false, reason: "bad_attestation_format" };
  let sig: ReturnType<typeof b64urlDecode>, payload: Record<string, unknown>;
  try {
    sig = b64urlDecode(parts[2]);
    payload = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
  } catch {
    return { ok: false, reason: "bad_attestation_format" };
  }
  const valid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", publicKey, sig, new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!valid) return { ok: false, reason: "bad_attestation_signature" };
  if (payload.kind !== "integrity" || payload.pkg !== expectedPkg || payload.action !== expectedAction) return { ok: false, reason: "attestation_mismatch" };
  if (typeof payload.exp !== "number" || payload.exp < nowSeconds) return { ok: false, reason: "attestation_expired" };
  return { ok: true, reason: "" };
}
