// Google Play Developer API: verify a one-time product purchase token and acknowledge it.
// Endpoint names below are from memory of the androidpublisher v3 reference and are UNVERIFIED (the docs page
// fetched did not include them). Confirm against:
//   https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2/getproductpurchasev2
//   https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/acknowledge
import { getAccessToken } from "./google_auth.ts";
import type { ServiceAccount } from "./google_auth.ts";

export const SCOPE_ANDROID_PUBLISHER = "https://www.googleapis.com/auth/androidpublisher";
const BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";

export interface VerifiedPurchase {
  valid: boolean; // PURCHASED and contains the requested product
  reason: string;
  orderId: string;
  acknowledged: boolean;
  isTestPurchase: boolean;
}

// deno-lint-ignore no-explicit-any
export function interpretProductPurchaseV2(body: any, productId: string): VerifiedPurchase {
  const items: Array<{ productId?: string }> = body?.productLineItem ?? [];
  const has = items.some((i) => i.productId === productId);
  const state: string = body?.purchaseStateContext?.purchaseState ?? "";
  const ack: string = body?.acknowledgementState ?? "";
  const valid = has && state === "PURCHASED";
  return {
    valid,
    reason: valid ? "" : !has ? "product_not_in_purchase" : `state_${state || "unknown"}`,
    orderId: body?.orderId ?? "",
    acknowledged: ack === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    isTestPurchase: body?.testPurchaseContext != null,
  };
}

export async function verifyProductPurchase(
  sa: ServiceAccount,
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<VerifiedPurchase> {
  const at = await getAccessToken(sa, [SCOPE_ANDROID_PUBLISHER]);
  const url = `${BASE}/${encodeURIComponent(packageName)}/purchases/productsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${at}` } });
  if (res.status === 404 || res.status === 400) {
    return { valid: false, reason: `google_${res.status}`, orderId: "", acknowledged: false, isTestPurchase: false };
  }
  if (!res.ok) throw new Error(`productsv2.get ${res.status}: ${(await res.text()).slice(0, 300)}`);
  return interpretProductPurchaseV2(await res.json(), productId);
}

/** Best effort: purchases not acknowledged within 3 days are refunded by Google (verify current policy in Play docs). */
export async function acknowledgePurchase(
  sa: ServiceAccount,
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<boolean> {
  const at = await getAccessToken(sa, [SCOPE_ANDROID_PUBLISHER]);
  const url = `${BASE}/${encodeURIComponent(packageName)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json" },
    body: "{}",
  });
  return res.ok;
}
