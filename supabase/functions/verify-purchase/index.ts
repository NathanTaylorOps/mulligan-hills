// POST /functions/v1/verify-purchase
// Body: { platform:"android", package_name, product_id, purchase_token, integrity_token? }
// 200: { ok:true, entitlement:"mh1....", order_id, test_purchase, integrity:{mode,ok,reasons} }
// 4xx: { ok:false, error:"..." }
// No Supabase account is required or read: the entitlement belongs to the store receipt.
// The `purchase_flow` kill switch deliberately does NOT block this function: Restore must keep working (DEC-030).
import { corsHeaders, env, json } from "../_shared/http.ts";
import { parseServiceAccount } from "../_shared/google_auth.ts";
import { acknowledgePurchase, verifyProductPurchase } from "../_shared/play_purchases.ts";
import { decodeIntegrityToken, evaluateIntegrity } from "../_shared/integrity.ts";
import { signEntitlement } from "../_shared/entitlement.ts";
import { sha256hex } from "../_shared/crypto.ts";
import { makeBackend } from "../_shared/supabase_backend.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);

  try {
    const pkg = env("ANDROID_PACKAGE_NAME");
    const allowed = env("ALLOWED_PRODUCT_IDS", "mh_full_unlock").split(",").map((s) => s.trim());
    const mode = env("INTEGRITY_MODE", "log"); // off | log | enforce
    const sa = parseServiceAccount(env("GOOGLE_SERVICE_ACCOUNT_JSON"));

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return json({ ok: false, error: "bad_json" }, 400);
    const { package_name, product_id, purchase_token, integrity_token } = body as Record<string, unknown>;
    if (package_name !== pkg) return json({ ok: false, error: "wrong_package" }, 400);
    if (typeof product_id !== "string" || !allowed.includes(product_id)) return json({ ok: false, error: "unknown_product" }, 400);
    if (typeof purchase_token !== "string" || purchase_token.length < 10 || purchase_token.length > 4096) {
      return json({ ok: false, error: "bad_purchase_token" }, 400);
    }

    // 1) Integrity (standard request). Hash source MUST match the client: sha256hex(package|product_id|purchase_token)
    let integrity = { mode, ok: true, reasons: [] as string[] };
    if (mode !== "off") {
      if (typeof integrity_token !== "string" || integrity_token === "") {
        integrity = { mode, ok: false, reasons: ["missing_integrity_token"] };
      } else {
        const payload = await decodeIntegrityToken(sa, pkg, integrity_token);
        const r = evaluateIntegrity(payload, {
          packageName: pkg,
          expectedRequestHash: await sha256hex(`${pkg}|${product_id}|${purchase_token}`),
          nowMillis: Date.now(),
          maxAgeMillis: 10 * 60_000,
          requireLicensed: env("INTEGRITY_REQUIRE_LICENSED", "false") === "true",
          allowBasicIntegrity: env("INTEGRITY_ALLOW_BASIC", "false") === "true",
        });
        integrity = { mode, ok: r.ok, reasons: r.reasons };
      }
      if (!integrity.ok) console.warn("integrity failed", JSON.stringify(integrity));
      if (!integrity.ok && mode === "enforce") return json({ ok: false, error: "integrity_failed", integrity }, 403);
    }

    // 2) Purchase with Google Play Developer API
    const p = await verifyProductPurchase(sa, pkg, product_id, purchase_token);
    if (!p.valid) return json({ ok: false, error: `purchase_invalid:${p.reason}` }, 403);

    // 2b) Token reuse counter (added with migration 20261004000600). Stores only a hash. FAILS OPEN: if the database is
    //     unreachable the purchase is still honoured. A normal player verifies a few times (install, reinstall, new phone).
    try {
      const maxUses = Number(env("PURCHASE_MAX_VERIFICATIONS_30D", "10"));
      const rec = (await makeBackend().rpc("purchase_verification_record", {
        p_hash: await sha256hex(purchase_token), p_product: product_id, p_order: p.orderId, p_test: p.isTestPurchase, p_window_days: 30,
      })) as { count?: number };
      if (typeof rec?.count === "number" && rec.count > maxUses) {
        console.warn("purchase token reuse limit hit", rec.count);
        return json({ ok: false, error: "token_reuse_limit" }, 429);
      }
    } catch (e) {
      console.warn("purchase_verification_record failed (ignored)", e instanceof Error ? e.message : e);
    }

    // 3) Acknowledge on the server so a client crash cannot lead to an auto-refund (idempotent enough).
    if (!p.acknowledged && env("ACKNOWLEDGE_ON_SERVER", "true") === "true") {
      const acked = await acknowledgePurchase(sa, pkg, product_id, purchase_token);
      if (!acked) console.warn("server acknowledge failed; client will retry");
    }

    // 4) Sign entitlement
    const entitlement = await signEntitlement(env("ENTITLEMENT_SIGNING_KEY_PEM"), pkg, product_id, p.orderId, purchase_token);
    return json({ ok: true, entitlement, order_id: p.orderId, test_purchase: p.isTestPurchase, integrity });
  } catch (e) {
    console.error("verify-purchase error", e instanceof Error ? e.message : e);
    return json({ ok: false, error: "server_error" }, 500);
  }
});
