// Runs under Node >= 22.6:  node --experimental-strip-types supabase/functions/_shared/selftest.node.ts OUTDIR
// Pure-logic checks (no network, no Deno). Prints a golden token signed by the TypeScript signer so the
// Python side can verify cross-implementation compatibility.
import { signEntitlement } from "./entitlement.ts";
import { evaluateIntegrity } from "./integrity.ts";
import { interpretProductPurchaseV2 } from "./play_purchases.ts";
import { sha256hex } from "./crypto.ts";
import { readFileSync, writeFileSync } from "node:fs";

let failed = 0;
function check(name: string, cond: boolean) {
  console.log((cond ? "PASS " : "FAIL ") + name);
  if (!cond) failed++;
}

const out = process.argv[2] ?? ".";
const priv = readFileSync(`${out}/ts_test_private_pkcs8.pem`, "utf8");
const tok = await signEntitlement(priv, "com.mulliganhills.game", "mh_full_unlock", "GPA.1", "tok_abcdefghij", 1790000000);
writeFileSync(`${out}/ts_token.txt`, tok);
check("token has 3 parts, mh1 prefix", tok.split(".").length === 3 && tok.startsWith("mh1."));

check("sha256hex vector", (await sha256hex("a|b|c")) === "a52dd81bfd5e4e66d96b9f598382f6cbf8c5c3897654e6ae9055e03620fcf38e");

const pol = { packageName: "p", expectedRequestHash: "h", nowMillis: 1_000_000, maxAgeMillis: 600_000,
  requireLicensed: false, allowBasicIntegrity: false };
const good = { requestDetails: { requestPackageName: "p", requestHash: "h", timestampMillis: "999000" },
  appIntegrity: { appRecognitionVerdict: "PLAY_RECOGNIZED" },
  deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_DEVICE_INTEGRITY"] },
  accountDetails: { appLicensingVerdict: "LICENSED" } };
check("integrity good", evaluateIntegrity(good, pol).ok);
check("integrity wrong hash", evaluateIntegrity({ ...good, requestDetails: { ...good.requestDetails, requestHash: "x" } }, pol).reasons.includes("request_hash_mismatch"));
check("integrity stale", evaluateIntegrity({ ...good, requestDetails: { ...good.requestDetails, timestampMillis: "1" } }, pol).reasons.includes("stale_or_future_token"));
check("integrity emulator", evaluateIntegrity({ ...good, deviceIntegrity: { deviceRecognitionVerdict: [] } }, pol).reasons.includes("device_integrity_failed"));
check("basic only rejected by default", !evaluateIntegrity({ ...good, deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY"] } }, pol).ok);
check("basic accepted when allowed", evaluateIntegrity({ ...good, deviceIntegrity: { deviceRecognitionVerdict: ["MEETS_BASIC_INTEGRITY"] } }, { ...pol, allowBasicIntegrity: true }).ok);
check("unlicensed rejected when required", evaluateIntegrity({ ...good, accountDetails: { appLicensingVerdict: "UNLICENSED" } }, { ...pol, requireLicensed: true }).reasons.includes("not_licensed"));
check("sideload not play recognized", evaluateIntegrity({ ...good, appIntegrity: { appRecognitionVerdict: "UNRECOGNIZED_VERSION" } }, pol).reasons.includes("app_not_play_recognized"));

const pv = interpretProductPurchaseV2({ productLineItem: [{ productId: "mh_full_unlock" }], purchaseStateContext: { purchaseState: "PURCHASED" },
  orderId: "GPA.1", acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING" }, "mh_full_unlock");
check("purchase valid", pv.valid && !pv.acknowledged && pv.orderId === "GPA.1");
check("purchase pending invalid", !interpretProductPurchaseV2({ productLineItem: [{ productId: "mh_full_unlock" }], purchaseStateContext: { purchaseState: "PENDING" } }, "mh_full_unlock").valid);
check("purchase wrong product invalid", !interpretProductPurchaseV2({ productLineItem: [{ productId: "x" }], purchaseStateContext: { purchaseState: "PURCHASED" } }, "mh_full_unlock").valid);

process.exit(failed ? 1 : 0);
