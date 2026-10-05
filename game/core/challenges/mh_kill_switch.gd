class_name MHKillSwitch
extends RefCounted
## Reads a remote-config kill switch (docs/spec/data/remote_config.schema.json, kill_switches object).
## Semantics are the schema's: true = feature ON, false = disabled. Switch names: cloud_sync, daily_challenge,
## analytics, purchase_flow, tournaments, notifications.
## Fail-open on purpose: a missing key, a missing or non-boolean value, or no remote config at all (offline, first
## launch, bad push rejected by the clamp) leaves the shipped feature ON, because the client falls back to the
## bundled defaults and the game must play fully offline (DEC-012). Only an explicit boolean false turns a
## feature off. The caller passes in the last good config's kill_switches Dictionary.

const KEYS: Array = ["cloud_sync", "daily_challenge", "analytics", "purchase_flow", "tournaments", "notifications"]


static func is_on(kill_switches: Dictionary, key: String) -> bool:
	if not kill_switches.has(key):
		return true
	var v: Variant = kill_switches[key]
	if typeof(v) != TYPE_BOOL:
		return true
	return bool(v)
