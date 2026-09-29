class_name MHPlatformConfig
extends RefCounted
## Central, non-secret platform configuration. NOTHING in this file may be a secret.
## The Supabase anon key is public by design. The entitlement PUBLIC key is public by design.
## Fill the placeholders (see docs/phase0/platform.md, "For Nathan").

## Android application id / iOS bundle id. DECISION PENDING (placeholder).
const PACKAGE_NAME: String = "com.mulliganhills.game"

## The single non-consumable product. Create it with EXACTLY this id in Play Console and App Store Connect.
const PRODUCT_UNLOCK: String = "mh_full_unlock"

## Supabase project URL, e.g. https://abcdxyz.supabase.co (no trailing slash). Empty = verification disabled.
const SUPABASE_URL: String = ""
## Supabase anon (public) key. Empty = verification disabled.
const SUPABASE_ANON_KEY: String = ""

## Google Cloud PROJECT NUMBER (digits) linked to the app in Play Console (App integrity). Not the project id.
const CLOUD_PROJECT_NUMBER: String = ""

## PEM of the RSA-2048 PUBLIC key matching the server secret ENTITLEMENT_SIGNING_KEY_PEM.
## Empty = tokens cannot be verified, so real (non-mock) entitlement services will refuse to unlock.
const ENTITLEMENT_PUBLIC_KEY_PEM: String = ""

const CACHE_PATH: String = "user://mh_entitlement.json"
const VERIFY_PURCHASE_PATH: String = "/functions/v1/verify-purchase"
const VERIFY_INTEGRITY_PATH: String = "/functions/v1/verify-integrity"
const HTTP_TIMEOUT_SECONDS: float = 20.0

static func verification_configured() -> bool:
	return SUPABASE_URL != "" and SUPABASE_ANON_KEY != "" and ENTITLEMENT_PUBLIC_KEY_PEM != ""
