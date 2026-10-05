import { assert, assertEquals } from "../_shared/testing.ts";
import { FakeBackend, goodConfig, post } from "../_shared/fake_backend.ts";
import { handle, validateSubmit } from "./handler.ts";
import { signIntegrityAttestation } from "../_shared/entitlement.ts";

const U1 = "11111111-1111-4111-8111-111111111111";
type J = Record<string, any>; // deno-lint-ignore no-explicit-any
const call = async (be: FakeBackend, body: unknown, jwt?: string): Promise<{ status: number; body: J }> => {
  const r = await handle(post(body, jwt), be); return { status: r.status, body: await r.json() };
};
const day = (be: FakeBackend) => Math.floor(be.now / 86400);
const sub = (be: FakeBackend, over: Record<string, unknown> = {}) => ({
  action: "submit", app_version: "0.1.0", day: day(be), score_pm: 540, name_preset_id: 4, template_id: "gem_par3",
  rating_version: "MHRATE-1.0.0", sim_version: "MHSIM-1.0.0", content_hash: "deadbeef", ...over });

Deno.test("daily: submit ok, attempts limit, rate limit", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  const a = await call(be, sub(be), jwt);
  assertEquals(a.status, 200); assertEquals(a.body.attempts, 1); assertEquals(a.body.best_score_pm, 540);
  assertEquals((await call(be, sub(be, { score_pm: 900 }), jwt)).body.error, "too_fast");
  be.now += 10;
  const b = await call(be, sub(be, { score_pm: 900 }), jwt);
  assertEquals(b.body.best_score_pm, 900); assertEquals(b.body.improved, true);
  be.now += 10; await call(be, sub(be, { score_pm: 100 }), jwt);
  be.now += 10;
  const d = await call(be, sub(be), jwt);
  assertEquals(d.status, 429); assertEquals(d.body.error, "attempts_exhausted"); assertEquals(d.body.best_score_pm, 900);
});

Deno.test("daily: bounds checks (DEC-036) and day window", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  for (const [over, err] of [
    [{ score_pm: 1001 }, "bad_score"], [{ score_pm: -1 }, "bad_score"], [{ score_pm: 5.5 }, "bad_score"], [{ score_pm: "9" }, "bad_score"],
    [{ name_preset_id: 1000 }, "bad_name_preset"], [{ name_preset_id: "Bob" }, "bad_name_preset"],
    [{ template_id: "Has Spaces" }, "bad_template"], [{ rating_version: "1.0.0" }, "bad_rating_version"],
    [{ sim_version: "MHSIM-x" }, "bad_sim_version"], [{ content_hash: "zz" }, "bad_content_hash"],
    [{ day: -2 }, "bad_day"],
  ] as [Record<string, unknown>, string][]) {
    const r = await call(be, sub(be, over), jwt);
    assertEquals(r.status, 400, JSON.stringify(over)); assertEquals(r.body.error, err);
  }
  assertEquals((await call(be, sub(be, { app_version: "1" }), jwt)).status, 426, "an unreadable app version counts as too old");
  const future = await call(be, sub(be, { day: day(be) + 2 }), jwt);
  assertEquals(future.body.error, "bad_day"); assertEquals(future.body.today, day(be));
  assertEquals((await call(be, sub(be, { day: day(be) - 1 }), jwt)).status, 200, "yesterday is still accepted");
  assertEquals(validateSubmit({ ...sub(be), content_hash: undefined } as never) !== "bad_content_hash", true, "content_hash is optional");
});

Deno.test("daily: signed in required; kill switch; minimum version", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  assertEquals((await call(be, sub(be))).status, 401);
  be.config = goodConfig({ kill_switches: { ...(goodConfig().kill_switches as object), daily_challenge: false } }); be.now += 100;
  const r = await call(be, sub(be), jwt);
  assertEquals(r.status, 503); assertEquals(r.body.error, "feature_disabled");
  assertEquals((await call(be, { action: "leaderboard", app_version: "0.1.0", day: day(be) }, jwt)).status, 503);
  be.config = goodConfig({ min_app_version: "0.3.0" }); be.now += 100;
  assertEquals((await call(be, sub(be), jwt)).status, 426);
});

Deno.test("daily: leaderboard request checks", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  const ok = await call(be, { action: "leaderboard", app_version: "0.1.0", day: day(be), limit: 10 }, jwt);
  assertEquals(ok.status, 200); assertEquals(ok.body.board.total, 0);
  assertEquals((await call(be, { action: "leaderboard", app_version: "0.1.0", day: day(be), limit: 500 }, jwt)).body.error, "bad_limit");
  assertEquals((await call(be, { action: "leaderboard", app_version: "0.1.0", day: "x" }, jwt)).body.error, "bad_day");
  assertEquals((await call(be, { action: "other", app_version: "0.1.0" }, jwt)).body.error, "unknown_action");
});

Deno.test("daily: allowed rating versions list", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  be.settings.ALLOWED_RATING_VERSIONS = "MHRATE-1.0.0, MHRATE-1.1.0";
  assertEquals((await call(be, sub(be, { rating_version: "MHRATE-2.0.0" }), jwt)).status, 426);
  assertEquals((await call(be, sub(be, { rating_version: "MHRATE-1.1.0" }), jwt)).status, 200);
});

Deno.test("daily: optional Play Integrity attestation gate", async () => {
  const kp = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const pem = (label: string, der: ArrayBuffer) => `-----BEGIN ${label}-----\n${btoa(String.fromCharCode(...new Uint8Array(der)))}\n-----END ${label}-----`;
  const priv = pem("PRIVATE KEY", await crypto.subtle.exportKey("pkcs8", kp.privateKey));
  const pub = pem("PUBLIC KEY", await crypto.subtle.exportKey("spki", kp.publicKey));
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  Object.assign(be.settings, { DAILY_REQUIRE_ATTESTATION: "true", ENTITLEMENT_PUBLIC_KEY_PEM: pub, ANDROID_PACKAGE_NAME: "com.mulliganhills.game" });
  assertEquals((await call(be, sub(be), jwt)).body.error, "missing_attestation");
  const good = await signIntegrityAttestation(priv, "com.mulliganhills.game", "daily_submit", be.now);
  assertEquals((await call(be, sub(be, { attestation: good }), jwt)).status, 200);
  be.now += 10;
  const wrong = await signIntegrityAttestation(priv, "com.mulliganhills.game", "cloud_save", be.now);
  assertEquals((await call(be, sub(be, { attestation: wrong }), jwt)).body.error, "attestation_mismatch");
  be.settings.ENTITLEMENT_PUBLIC_KEY_PEM = "";
  assertEquals((await call(be, sub(be, { attestation: good }), jwt)).status, 500, "misconfiguration is a server error, not a free pass");
  assert(true);
});
