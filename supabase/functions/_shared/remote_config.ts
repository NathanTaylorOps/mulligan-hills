// Remote config rules in TypeScript. Mirrors docs/spec/data/remote_config.schema.json and the SQL function
// public.mh_validate_remote_config (migration 20261004000300). Keep the three in step.
// The Edge Function runs this before it serves a config, so even a config that slipped past the database is held back.

export const KILL_SWITCHES = [
  "cloud_sync", "daily_challenge", "analytics", "purchase_flow", "tournaments", "notifications",
] as const;
export type KillSwitch = (typeof KILL_SWITCHES)[number];

type Obj = Record<string, unknown>;
const isObj = (v: unknown): v is Obj => v !== null && typeof v === "object" && !Array.isArray(v);

function intIn(o: Obj, k: string, lo: number, hi: number): boolean {
  const v = o[k];
  return typeof v === "number" && Number.isInteger(v) && v >= lo && v <= hi;
}

function keysOk(o: unknown, required: string[], optional: string[], where: string, errs: string[]): o is Obj {
  if (!isObj(o)) {
    errs.push(`${where} must be an object`);
    return false;
  }
  const allowed = new Set([...required, ...optional]);
  for (const k of Object.keys(o)) if (!allowed.has(k)) errs.push(`${where}: unknown key ${k}`);
  for (const r of required) if (!(r in o)) errs.push(`${where}: missing key ${r}`);
  return true;
}

/** Returns a list of problems. An empty list means the config is valid. */
export function validateRemoteConfig(c: unknown): string[] {
  const errs: string[] = [];
  if (!keysOk(c, ["schema", "schema_version", "config_version", "issued_unix", "min_app_version", "kill_switches", "economy", "events"],
              ["banner_key"], "config", errs)) return errs;
  if (c.schema !== "mh.remote_config") errs.push("schema must be mh.remote_config");
  if (!intIn(c, "schema_version", 1, 1)) errs.push("schema_version must be 1");
  if (!intIn(c, "config_version", 1, 1_000_000)) errs.push("config_version out of range");
  if (!intIn(c, "issued_unix", 0, Number.MAX_SAFE_INTEGER)) errs.push("issued_unix out of range");
  if (typeof c.min_app_version !== "string" || !/^[0-9]+\.[0-9]+\.[0-9]+$/.test(c.min_app_version)) errs.push("min_app_version must look like 0.1.0");
  if ("banner_key" in c) {
    const b = c.banner_key;
    if (typeof b !== "string" || b.length > 80 || !/^[a-z][a-z0-9_]*(\.[a-z0-9_]+){1,4}$/.test(b)) errs.push("banner_key is not a valid string key");
  }
  const ks = c.kill_switches;
  if (keysOk(ks, [...KILL_SWITCHES], [], "kill_switches", errs)) {
    for (const k of KILL_SWITCHES) if (k in ks && typeof ks[k] !== "boolean") errs.push(`kill switch ${k} must be true or false`);
  }
  const eco = c.economy;
  if (keysOk(eco, ["parcel_base_cost", "parcel_growth_pct", "hole_cost",
                   "start_cash", "green_fee_min", "green_fee_max"], [], "economy", errs)) {
    if (!intIn(eco, "parcel_base_cost", 1000, 1_000_000)) errs.push("parcel_base_cost must be 1000 to 1000000");
    if (!intIn(eco, "parcel_growth_pct", 100, 200)) errs.push("parcel_growth_pct must be 100 to 200");
    if (!intIn(eco, "hole_cost", 500, 100_000)) errs.push("hole_cost must be 500 to 100000");
    if (!intIn(eco, "start_cash", 1000, 1_000_000)) errs.push("start_cash must be 1000 to 1000000");
    if (!intIn(eco, "green_fee_min", 1, 1000)) errs.push("green_fee_min must be 1 to 1000");
    if (!intIn(eco, "green_fee_max", 1, 10_000)) errs.push("green_fee_max must be 1 to 10000");
    if (intIn(eco, "green_fee_min", 1, 1000) && intIn(eco, "green_fee_max", 1, 10_000) &&
        (eco.green_fee_min as number) > (eco.green_fee_max as number)) errs.push("green_fee_min is above green_fee_max");
  }
  const ev = c.events;
  if (keysOk(ev, ["random_event_per_day_permille", "commission_offer_per_day_permille", "event_cash_scale_pct"], [], "events", errs)) {
    if (!intIn(ev, "random_event_per_day_permille", 0, 500)) errs.push("random_event_per_day_permille must be 0 to 500");
    if (!intIn(ev, "commission_offer_per_day_permille", 0, 500)) errs.push("commission_offer_per_day_permille must be 0 to 500");
    if (!intIn(ev, "event_cash_scale_pct", 25, 400)) errs.push("event_cash_scale_pct must be 25 to 400");
  }
  return errs;
}

/** true = feature ON. A missing or unreadable config means ON (fail open: a database hiccup must not disable the game). */
export function featureOn(config: unknown, name: KillSwitch): boolean {
  if (!isObj(config) || !isObj(config.kill_switches)) return true;
  return config.kill_switches[name] !== false;
}

export function minAppVersion(config: unknown): string | null {
  return isObj(config) && typeof config.min_app_version === "string" ? config.min_app_version : null;
}
