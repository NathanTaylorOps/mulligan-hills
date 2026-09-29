// Play Integrity: decode (server side, Google API) and evaluate the verdict.
// Endpoint (POST https://playintegrity.googleapis.com/v1/{package}:decodeIntegrityToken, body {"integrity_token"})
// and verdict fields per https://developer.android.com/google/play/integrity/standard and .../verdicts (fetched 2026-09-29).
// The response wrapper key `tokenPayloadExternal` is from memory: UNVERIFIED. See
// https://developer.android.com/google/play/integrity/reference/rest/v1/TopLevel/decodeIntegrityToken
import { getAccessToken } from "./google_auth.ts";
import type { ServiceAccount } from "./google_auth.ts";

export const SCOPE_PLAY_INTEGRITY = "https://www.googleapis.com/auth/playintegrity";

// deno-lint-ignore no-explicit-any
export type IntegrityPayload = any;

export async function decodeIntegrityToken(sa: ServiceAccount, packageName: string, token: string): Promise<IntegrityPayload> {
  const at = await getAccessToken(sa, [SCOPE_PLAY_INTEGRITY]);
  const res = await fetch(
    `https://playintegrity.googleapis.com/v1/${encodeURIComponent(packageName)}:decodeIntegrityToken`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json" },
      body: JSON.stringify({ integrity_token: token }),
    },
  );
  if (!res.ok) throw new Error(`decodeIntegrityToken ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const body = await res.json();
  return body.tokenPayloadExternal ?? body;
}

export interface IntegrityPolicy {
  packageName: string;
  expectedRequestHash: string;
  nowMillis: number;
  maxAgeMillis: number; // freshness window for timestampMillis
  requireLicensed: boolean; // true rejects sideloaded builds (internal-track installs from Play count as LICENSED)
  allowBasicIntegrity: boolean; // true also accepts MEETS_BASIC_INTEGRITY (rooted/older devices); weaker
}

export interface IntegrityResult {
  ok: boolean;
  reasons: string[];
  summary: { app: string; device: string[]; licensing: string };
}

export function evaluateIntegrity(p: IntegrityPayload, pol: IntegrityPolicy): IntegrityResult {
  const reasons: string[] = [];
  const rd = p?.requestDetails ?? {};
  if (rd.requestPackageName !== pol.packageName) reasons.push("package_mismatch");
  if (rd.requestHash !== pol.expectedRequestHash) reasons.push("request_hash_mismatch");
  const ts = Number(rd.timestampMillis ?? 0);
  if (!ts || pol.nowMillis - ts > pol.maxAgeMillis || ts - pol.nowMillis > 60_000) reasons.push("stale_or_future_token");

  const app: string = p?.appIntegrity?.appRecognitionVerdict ?? "";
  if (app !== "PLAY_RECOGNIZED") reasons.push("app_not_play_recognized");

  const device: string[] = p?.deviceIntegrity?.deviceRecognitionVerdict ?? [];
  const deviceOk = device.includes("MEETS_DEVICE_INTEGRITY") || (pol.allowBasicIntegrity && device.includes("MEETS_BASIC_INTEGRITY"));
  if (!deviceOk) reasons.push("device_integrity_failed");

  const licensing: string = p?.accountDetails?.appLicensingVerdict ?? "";
  if (pol.requireLicensed && licensing !== "LICENSED") reasons.push("not_licensed");

  return { ok: reasons.length === 0, reasons, summary: { app, device, licensing } };
}
