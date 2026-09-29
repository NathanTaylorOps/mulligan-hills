// POST /functions/v1/verify-integrity
// Body: { package_name, integrity_token, action, nonce }
// Client request hash = sha256hex(`${package_name}|${action}|${nonce}`)
// 200: { ok, reasons, summary, attestation? }  attestation = short-lived signed "mhi1" token when ok.
import { corsHeaders, env, json } from "../_shared/http.ts";
import { parseServiceAccount } from "../_shared/google_auth.ts";
import { decodeIntegrityToken, evaluateIntegrity } from "../_shared/integrity.ts";
import { signIntegrityAttestation } from "../_shared/entitlement.ts";
import { sha256hex } from "../_shared/crypto.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  try {
    const pkg = env("ANDROID_PACKAGE_NAME");
    const sa = parseServiceAccount(env("GOOGLE_SERVICE_ACCOUNT_JSON"));
    const b = (await req.json().catch(() => null)) as Record<string, unknown> | null;
    if (!b || b.package_name !== pkg) return json({ ok: false, error: "wrong_package" }, 400);
    const { integrity_token, action, nonce } = b;
    if (typeof integrity_token !== "string" || typeof action !== "string" || typeof nonce !== "string" ||
        action.length > 64 || nonce.length > 128) {
      return json({ ok: false, error: "bad_request" }, 400);
    }
    const payload = await decodeIntegrityToken(sa, pkg, integrity_token);
    const r = evaluateIntegrity(payload, {
      packageName: pkg,
      expectedRequestHash: await sha256hex(`${pkg}|${action}|${nonce}`),
      nowMillis: Date.now(),
      maxAgeMillis: 10 * 60_000,
      requireLicensed: env("INTEGRITY_REQUIRE_LICENSED", "false") === "true",
      allowBasicIntegrity: env("INTEGRITY_ALLOW_BASIC", "false") === "true",
    });
    const attestation = r.ok ? await signIntegrityAttestation(env("ENTITLEMENT_SIGNING_KEY_PEM"), pkg, action) : undefined;
    return json({ ok: r.ok, reasons: r.reasons, summary: r.summary, attestation }, r.ok ? 200 : 403);
  } catch (e) {
    console.error("verify-integrity error", e instanceof Error ? e.message : e);
    return json({ ok: false, error: "server_error" }, 500);
  }
});
