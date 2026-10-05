// Run:  deno test --allow-read supabase/functions        (no network needed)
import { assert, assertEquals, assertIncludes, assertRejects } from "./testing.ts";
import { b64url, b64urlDecode, sha256hex } from "./crypto.ts";
import { signEntitlement, signIntegrityAttestation } from "./entitlement.ts";
import { evaluateIntegrity } from "./integrity.ts";
import { interpretProductPurchaseV2 } from "./play_purchases.ts";
import { importRsaPublicKey, verifyIntegrityAttestation } from "./attestation.ts";
import { codeFromBytes, formatCode, hashCode, normalizeCode, CODE_ALPHABET } from "./codes.ts";
import { parseSemver, semverGte } from "./versions.ts";
import { featureOn, validateRemoteConfig } from "./remote_config.ts";
import { catalog, validateBatch, validateEvent } from "./analytics.ts";
import { goodConfig } from "./fake_backend.ts";

// ---- helpers: a throwaway RSA key pair in PEM form, made at test time --------------------------------------------
async function makePems(): Promise<{ priv: string; pub: string }> {
  const kp = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const pem = (label: string, der: ArrayBuffer) => {
    const b64 = btoa(String.fromCharCode(...new Uint8Array(der)));
    return `-----BEGIN ${label}-----\n${b64.match(/.{1,64}/g)!.join("\n")}\n-----END ${label}-----\n`;
  };
  return { priv: pem("PRIVATE KEY", await crypto.subtle.exportKey("pkcs8", kp.privateKey)), pub: pem("PUBLIC KEY", await crypto.subtle.exportKey("spki", kp.publicKey)) };
}

Deno.test("crypto: sha256 vector and base64url round trip", async () => {
  assertEquals(await sha256hex("a|b|c"), "a52dd81bfd5e4e66d96b9f598382f6cbf8c5c3897654e6ae9055e03620fcf38e");
  const bytes = new Uint8Array([0, 250, 251, 252, 253, 254, 255, 1, 2]);
  assertEquals([...b64urlDecode(b64url(bytes))], [...bytes]);
});

Deno.test("entitlement token: 3 parts, mh1 prefix, signature verifies with the public key", async () => {
  const { priv, pub } = await makePems();
  const tok = await signEntitlement(priv, "com.mulliganhills.game", "mh_full_unlock", "GPA.1", "tok_abcdefghij", 1790000000);
  const parts = tok.split(".");
  assertEquals(parts.length, 3); assertEquals(parts[0], "mh1");
  const key = await importRsaPublicKey(pub);
  assert(await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64urlDecode(parts[2]), new TextEncoder().encode(`${parts[0]}.${parts[1]}`)), "signature must verify");
  const payload = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
  assertEquals(payload.pid, "mh_full_unlock"); assertEquals(payload.pth.length, 16);
  // tamper with the product id: signature must no longer verify
  const bad = b64url(new TextEncoder().encode(JSON.stringify({ ...payload, pid: "other" })));
  assert(!(await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64urlDecode(parts[2]), new TextEncoder().encode(`mh1.${bad}`))), "tampered token must fail");
});

Deno.test("integrity attestation (mhi1): good, wrong action, expired, tampered, wrong prefix", async () => {
  const { priv, pub } = await makePems();
  const key = await importRsaPublicKey(pub);
  const now = 1790000000;
  const tok = await signIntegrityAttestation(priv, "com.mulliganhills.game", "daily_submit", now);
  assertEquals((await verifyIntegrityAttestation(key, tok, "com.mulliganhills.game", "daily_submit", now + 5)).ok, true);
  assertEquals((await verifyIntegrityAttestation(key, tok, "com.mulliganhills.game", "other_action", now + 5)).reason, "attestation_mismatch");
  assertEquals((await verifyIntegrityAttestation(key, tok, "com.other", "daily_submit", now + 5)).reason, "attestation_mismatch");
  assertEquals((await verifyIntegrityAttestation(key, tok, "com.mulliganhills.game", "daily_submit", now + 601)).reason, "attestation_expired");
  const parts = tok.split(".");
  const evil = b64url(new TextEncoder().encode(JSON.stringify({ v: 1, kind: "integrity", pkg: "com.mulliganhills.game", action: "daily_submit", iat: now, exp: now + 99999 })));
  assertEquals((await verifyIntegrityAttestation(key, `mhi1.${evil}.${parts[2]}`, "com.mulliganhills.game", "daily_submit", now + 5)).reason, "bad_attestation_signature");
  assertEquals((await verifyIntegrityAttestation(key, "mh1." + parts[1] + "." + parts[2], "com.mulliganhills.game", "daily_submit", now)).reason, "bad_attestation_format");
  assertEquals((await verifyIntegrityAttestation(key, undefined, "p", "a", now)).reason, "missing_attestation");
  // an entitlement token (mh1) can never pass as an attestation
  const ent = await signEntitlement(priv, "com.mulliganhills.game", "mh_full_unlock", "GPA.1", "tok_abcdefghij", now);
  assertEquals((await verifyIntegrityAttestation(key, ent, "com.mulliganhills.game", "daily_submit", now)).ok, false);
});

Deno.test("play integrity policy (ported from selftest.node.ts)", () => {
  const pol = { packageName: "p", expectedRequestHash: "h", nowMillis: 1_000_000, maxAgeMillis: 600_000, requireLicensed: false, allowBasicIntegrity: false };
  const good = { requestDetails: { requestPackageName: "p", requestHash: "h", timestampMillis: "999000" },
    appIntegrity: { appRecognitionVerdict: "PLAY_RECOGNIZED" }, deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_DEVICE_INTEGRITY"] },
    accountDetails: { appLicensingVerdict: "LICENSED" } };
  assert(evaluateIntegrity(good, pol).ok);
  assert(evaluateIntegrity({ ...good, requestDetails: { ...good.requestDetails, requestHash: "x" } }, pol).reasons.includes("request_hash_mismatch"));
  assert(evaluateIntegrity({ ...good, requestDetails: { ...good.requestDetails, timestampMillis: "1" } }, pol).reasons.includes("stale_or_future_token"));
  assert(evaluateIntegrity({ ...good, requestDetails: { ...good.requestDetails, timestampMillis: "2000000" } }, pol).reasons.includes("stale_or_future_token"), "future token");
  assert(evaluateIntegrity({ ...good, deviceIntegrity: { deviceRecognitionVerdict: [] } }, pol).reasons.includes("device_integrity_failed"));
  assert(!evaluateIntegrity({ ...good, deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY"] } }, pol).ok);
  assert(evaluateIntegrity({ ...good, deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY"] } }, { ...pol, allowBasicIntegrity: true }).ok);
  assert(evaluateIntegrity({ ...good, accountDetails: { appLicensingVerdict: "UNLICENSED" } }, { ...pol, requireLicensed: true }).reasons.includes("not_licensed"));
  assert(evaluateIntegrity({ ...good, appIntegrity: { appRecognitionVerdict: "UNRECOGNIZED_VERSION" } }, pol).reasons.includes("app_not_play_recognized"));
  assert(evaluateIntegrity({ ...good, requestDetails: { ...good.requestDetails, requestPackageName: "evil" } }, pol).reasons.includes("package_mismatch"));
});

Deno.test("play purchase interpretation (ported)", () => {
  const ok = { productLineItem: [{ productId: "mh_full_unlock" }], purchaseStateContext: { purchaseState: "PURCHASED" }, orderId: "GPA.1", acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING" };
  const pv = interpretProductPurchaseV2(ok, "mh_full_unlock");
  assert(pv.valid && !pv.acknowledged && pv.orderId === "GPA.1");
  assert(interpretProductPurchaseV2({ ...ok, acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED" }, "mh_full_unlock").acknowledged);
  assert(!interpretProductPurchaseV2({ ...ok, purchaseStateContext: { purchaseState: "PENDING" } }, "mh_full_unlock").valid);
  assert(!interpretProductPurchaseV2({ ...ok, purchaseStateContext: { purchaseState: "CANCELLED" } }, "mh_full_unlock").valid);
  assert(!interpretProductPurchaseV2({ ...ok, productLineItem: [{ productId: "x" }] }, "mh_full_unlock").valid);
  assert(interpretProductPurchaseV2({ ...ok, testPurchaseContext: {} }, "mh_full_unlock").isTestPurchase);
  assert(!interpretProductPurchaseV2(null, "mh_full_unlock").valid);
});

Deno.test("versions", () => {
  assertEquals(parseSemver("1.2.3"), [1, 2, 3]); assertEquals(parseSemver("1.2"), null); assertEquals(parseSemver(5), null);
  assert(semverGte("0.1.0", "0.1.0")); assert(semverGte("0.10.0", "0.9.9")); assert(!semverGte("0.1.0", "0.2.0"));
  assert(!semverGte("nope", "0.1.0")); assert(!semverGte(undefined, "0.1.0"));
});

Deno.test("transfer codes: alphabet, format, normalize, hash", async () => {
  const bytes = new Uint8Array(12).map((_, i) => i * 21);
  const code = codeFromBytes(bytes);
  assertEquals(code.length, 12);
  for (const ch of code) assert(CODE_ALPHABET.includes(ch), "char in alphabet");
  assertEquals(CODE_ALPHABET.length, 32);
  assert(!/[01IO]/.test(CODE_ALPHABET), "no look-alike characters");
  const shown = formatCode(code);
  assert(/^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(shown));
  assertEquals(normalizeCode(shown.toLowerCase()), code);
  assertEquals(normalizeCode(" " + shown + " "), code);
  assertEquals(normalizeCode("ABCD-EFGH"), null);
  assertEquals(normalizeCode("ABCD-EFGH-JKL0"), null, "0 is not in the alphabet");
  assertEquals(normalizeCode(12345), null);
  assertEquals((await hashCode(code)).length, 64);
  assert((await hashCode(code)) !== (await hashCode(codeFromBytes(new Uint8Array(12).fill(5)))));
});

Deno.test("remote config: example from docs validates; each rule catches its mistake", async () => {
  const example = JSON.parse(await Deno.readTextFile(new URL("../../../docs/spec/data/remote_config.example.json", import.meta.url)));
  assertEquals(validateRemoteConfig(example), []);
  assertEquals(validateRemoteConfig(goodConfig()), []);
  const bad = (mut: (c: Record<string, any>) => void): string[] => { const c = structuredClone(goodConfig()) as Record<string, any>; mut(c); return validateRemoteConfig(c); }; // deno-lint-ignore no-explicit-any
  assert(bad((c) => { c.extra = 1; }).length > 0, "unknown top key");
  assert(bad((c) => { delete c.kill_switches.tournaments; }).length > 0, "missing switch");
  assert(bad((c) => { c.kill_switches.cloud_sync = "yes"; }).length > 0, "switch type");
  assert(bad((c) => { c.economy.start_cash = 5; }).length > 0, "start cash range");
  assert(bad((c) => { c.economy.price = 1; }).length > 0, "price smuggled");
  assert(bad((c) => { c.economy.sim_speed = 1; }).length > 0, "sim parameter smuggled");
  assert(bad((c) => { c.economy.green_fee_min = 300; }).length > 0, "fee order");
  assert(bad((c) => { c.economy.cost_multiplier_x100 = [1, 2]; }).length > 0, "multiplier count");
  assert(bad((c) => { c.min_app_version = "1.0"; }).length > 0, "version format");
  assert(bad((c) => { c.banner_key = "Bad Key"; }).length > 0, "banner key");
  assert(bad((c) => { c.events.event_cash_scale_pct = 1000; }).length > 0, "events range");
  assert(bad((c) => { c.config_version = 1.5; }).length > 0, "int only");
  assertEquals(bad((c) => { c.banner_key = "banner.maintenance"; }), []);
  assertEquals(validateRemoteConfig(null).length, 1);
  assert(featureOn(goodConfig(), "daily_challenge"));
  assert(!featureOn(goodConfig({ kill_switches: { ...(goodConfig().kill_switches as object), daily_challenge: false } }), "daily_challenge"));
  assert(featureOn(null, "cloud_sync"), "no config means fail open");
});

Deno.test("analytics catalog copy matches docs/spec and example event is accepted", async () => {
  const spec = JSON.parse(await Deno.readTextFile(new URL("../../../docs/spec/data/analytics_catalog.json", import.meta.url)));
  assertEquals(catalog, spec, "supabase/functions/_shared/analytics_catalog.json drifted from docs/spec/data/analytics_catalog.json; copy the docs file over it");
  const ex = JSON.parse(await Deno.readTextFile(new URL("../../../docs/spec/data/analytics_event.example.json", import.meta.url)));
  assertEquals(validateEvent(ex, ex.ts_unix + 60), null);
});

Deno.test("analytics events: rules", () => {
  const now = 1790000200;
  const ev = (over: Record<string, unknown> = {}, props: Record<string, unknown> = { building: "clubhouse", tier: 2, day: 17 }) => ({
    schema_version: 1, event_id: "0b5c2a3e-1111-4222-8333-444455556666", name: "building_upgraded", ts_unix: 1790000100,
    session_id: "aaaaaaaa-1111-4222-8333-444455556666", install_id: "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d", app_version: "0.1.0",
    platform: "android", build_kind: "demo", props, ...over });
  assertEquals(validateEvent(ev(), now), null);
  assertIncludes(validateEvent(ev({ name: "ad_click" }), now)!, "unknown event");
  assertIncludes(validateEvent(ev({}, { building: "clubhouse", tier: 2, note: "hi" }), now)!, "unknown prop");
  assertIncludes(validateEvent(ev({}, { building: "clubhouse", tier: 9 }), now)!, "above maximum");
  assertIncludes(validateEvent(ev({}, { building: "casino", tier: 1 }), now)!, "allowed value");
  assertIncludes(validateEvent(ev({}, { tier: 1 }), now)!, "missing required");
  assertIncludes(validateEvent(ev({}, { building: "clubhouse", tier: 1.5 }), now)!, "whole number");
  assertIncludes(validateEvent(ev({ advertising_id: "x" }), now)!, "unknown field");
  assertIncludes(validateEvent(ev({ install_id: "not-a-uuid" }), now)!, "install_id");
  assertIncludes(validateEvent(ev({ ts_unix: now - 31 * 24 * 3600 }), now)!, "too old");
  assertIncludes(validateEvent(ev({ ts_unix: now + 3 * 24 * 3600 }), now)!, "future");
  assertIncludes(validateEvent(ev({ platform: "windows" }), now)!, "platform");
  // free text can never get through: a card_id must match its pattern, a feedback event holds no text
  assertIncludes(validateEvent(ev({ name: "card_choice" }, { card_id: "Hello World!", choice: "a" }), now)!, "pattern");
  assertIncludes(validateEvent(ev({ name: "feedback_sent" }, { kind: "bug", text: "my email is x" }), now)!, "unknown prop");
  // consent: yes is stored, no is not
  assertEquals(validateEvent(ev({ name: "consent_decision" }, { analytics: true }), now), null);
  assertIncludes(validateEvent(ev({ name: "consent_decision" }, { analytics: false }), now)!, "declined consent");
});

Deno.test("analytics batch: one install, duplicates, size", () => {
  const now = 1790000200;
  const mk = (id: string, inst = "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d") => ({
    schema_version: 1, event_id: id, name: "app_open", ts_unix: 1790000100, session_id: "aaaaaaaa-1111-4222-8333-444455556666", install_id: inst,
    app_version: "0.1.0", platform: "ios", build_kind: "full", props: { first_run: true, build_kind: "full" } });
  const a = "0b5c2a3e-1111-4222-8333-444455556661", b = "0b5c2a3e-1111-4222-8333-444455556662";
  const r = validateBatch([mk(a), mk(b), mk(a), { junk: 1 }], now);
  assertEquals(r.accepted.length, 2); assertEquals(r.rejected.length, 2); assertEquals(r.install_id, "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d");
  assertIncludes(validateBatch([mk(a), mk(b, "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6e")], now).fatal!, "one install");
  assertIncludes(validateBatch([], now).fatal!, "non-empty");
  assertIncludes(validateBatch(Array(101).fill(mk(a)), now).fatal!, "too many");
  assertIncludes(validateBatch("nope", now).fatal!, "non-empty");
});

Deno.test("fixtures: daily attempts constant equals docs/spec", async () => {
  const dc = JSON.parse(await Deno.readTextFile(new URL("../../../docs/spec/data/daily_challenges.json", import.meta.url)));
  const { ATTEMPTS_PER_DAY } = await import("../daily-challenge/handler.ts");
  assertEquals(ATTEMPTS_PER_DAY, dc.attempts_per_day);
});

Deno.test("assertRejects helper works", async () => { await assertRejects(() => Promise.reject(new Error("x"))); });
