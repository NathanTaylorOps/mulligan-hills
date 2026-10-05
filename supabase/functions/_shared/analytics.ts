// Server side check of analytics events against the catalog (docs/spec/data/analytics_catalog.json, copied to
// _shared/analytics_catalog.json; a test fails if the two copies drift). Rules (PROP-04, DEC-057):
//   * only events and props named in the catalog, nothing else (no free text can sneak in);
//   * every value inside its declared type, range, enum or pattern;
//   * an install id is a random UUID; no ad ids or hardware ids exist in the envelope;
//   * "consent_decision" with analytics=false is REFUSED: a player who said no must leave no event behind.
import catalogJson from "./analytics_catalog.json" with { type: "json" };

type Obj = Record<string, unknown>;
const isObj = (v: unknown): v is Obj => v !== null && typeof v === "object" && !Array.isArray(v);

export interface PropSpec {
  type?: "boolean" | "integer" | "string";
  enum?: unknown[];
  minimum?: number;
  maximum?: number;
  pattern?: string;
}
export interface EventSpec { name: string; props: Record<string, PropSpec>; required: string[] }
export interface Catalog { events: EventSpec[]; privacy: { retention_days: number } & Obj }

export const catalog = catalogJson as unknown as Catalog;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const SEMVER = /^[0-9]+\.[0-9]+\.[0-9]+$/;
const ENVELOPE = ["schema_version", "event_id", "name", "ts_unix", "session_id", "install_id", "app_version", "platform", "build_kind", "props"];
export const MAX_EVENTS_PER_BATCH = 100;
export const MAX_AGE_SECONDS = 30 * 24 * 3600; // offline queue limit
export const MAX_FUTURE_SECONDS = 24 * 3600;

function checkProp(spec: PropSpec, v: unknown): string | null {
  if (spec.enum) return spec.enum.includes(v) ? null : "not an allowed value";
  switch (spec.type) {
    case "boolean": return typeof v === "boolean" ? null : "must be true or false";
    case "integer":
      if (typeof v !== "number" || !Number.isInteger(v)) return "must be a whole number";
      if (spec.minimum !== undefined && v < spec.minimum) return "below minimum";
      if (spec.maximum !== undefined && v > spec.maximum) return "above maximum";
      return null;
    case "string":
      if (typeof v !== "string" || v.length > 64) return "must be a short string";
      if (spec.pattern && !new RegExp(spec.pattern).test(v)) return "does not match the allowed pattern";
      return null;
    default: return "unsupported spec";
  }
}

/** null = acceptable, otherwise a short reason. nowSeconds is passed in so tests are deterministic. */
export function validateEvent(e: unknown, nowSeconds: number, cat: Catalog = catalog): string | null {
  if (!isObj(e)) return "event is not an object";
  for (const k of Object.keys(e)) if (!ENVELOPE.includes(k)) return `unknown field ${k}`;
  for (const k of ENVELOPE) if (!(k in e)) return `missing field ${k}`;
  if (e.schema_version !== 1) return "schema_version must be 1";
  if (typeof e.event_id !== "string" || !UUID.test(e.event_id)) return "bad event_id";
  if (typeof e.session_id !== "string" || !UUID.test(e.session_id)) return "bad session_id";
  if (typeof e.install_id !== "string" || !UUID.test(e.install_id)) return "bad install_id";
  if (typeof e.app_version !== "string" || !SEMVER.test(e.app_version)) return "bad app_version";
  if (e.platform !== "android" && e.platform !== "ios") return "bad platform";
  if (e.build_kind !== "demo" && e.build_kind !== "full") return "bad build_kind";
  if (typeof e.ts_unix !== "number" || !Number.isInteger(e.ts_unix)) return "bad ts_unix";
  if (e.ts_unix < nowSeconds - MAX_AGE_SECONDS) return "event too old";
  if (e.ts_unix > nowSeconds + MAX_FUTURE_SECONDS) return "event is from the future";
  const spec = cat.events.find((s) => s.name === e.name);
  if (typeof e.name !== "string" || !spec) return "unknown event name";
  if (!isObj(e.props)) return "props must be an object";
  const keys = Object.keys(e.props);
  if (keys.length > 8) return "too many props";
  for (const k of keys) {
    const ps = spec.props[k];
    if (!ps) return `unknown prop ${k}`;
    const bad = checkProp(ps, e.props[k]);
    if (bad) return `prop ${k}: ${bad}`;
  }
  for (const r of spec.required) if (!(r in e.props)) return `missing required prop ${r}`;
  if (e.name === "consent_decision" && e.props.analytics !== true) return "declined consent leaves no event";
  return null;
}

export interface BatchResult {
  install_id: string | null;
  accepted: Obj[];
  rejected: { index: number; reason: string }[];
  fatal?: string;
}

/** Validate a whole batch. A batch must come from ONE install (the SQL throttle is per install). */
export function validateBatch(events: unknown, nowSeconds: number, cat: Catalog = catalog): BatchResult {
  if (!Array.isArray(events) || events.length === 0) return { install_id: null, accepted: [], rejected: [], fatal: "events must be a non-empty list" };
  if (events.length > MAX_EVENTS_PER_BATCH) return { install_id: null, accepted: [], rejected: [], fatal: "too many events in one batch" };
  const ids = new Set<string>();
  for (const e of events) if (isObj(e) && typeof e.install_id === "string") ids.add(e.install_id);
  if (ids.size > 1) return { install_id: null, accepted: [], rejected: [], fatal: "one batch must come from one install" };
  const accepted: Obj[] = [];
  const rejected: { index: number; reason: string }[] = [];
  const seen = new Set<string>();
  events.forEach((e, index) => {
    const bad = validateEvent(e, nowSeconds, cat);
    if (bad) return rejected.push({ index, reason: bad });
    const id = (e as Obj).event_id as string;
    if (seen.has(id)) return rejected.push({ index, reason: "duplicate event_id in batch" });
    seen.add(id);
    accepted.push(e as Obj);
  });
  return { install_id: ids.size === 1 ? [...ids][0] : null, accepted, rejected };
}

export const UUID_RE = UUID;
