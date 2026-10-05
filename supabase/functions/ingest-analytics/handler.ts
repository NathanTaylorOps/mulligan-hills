// POST /functions/v1/ingest-analytics     (the game sends the project anon key; no player sign in needed)
//   { events:[ ...up to 100 events of ONE install... ] }  -> { ok, accepted, duplicates, rejected:[{index,reason}] }
//   { delete_install_id:"<uuid>" }                        -> erases every stored event of that install (opt-out / reset)
// Opt-in only (DEC-057): the game must not call this before the player agreed. The server adds a second fence: events are
// checked against the catalog, and a "consent_decision" with analytics=false is refused so a "no" leaves nothing behind.
// Kill switch `analytics` (remote config) answers 200 {disabled:true} and stores nothing.
import { corsHeaders, json, readJson } from "../_shared/http.ts";
import { loadConfig } from "../_shared/backend.ts";
import type { Backend } from "../_shared/backend.ts";
import { UUID_RE, validateBatch } from "../_shared/analytics.ts";
import { featureOn } from "../_shared/remote_config.ts";

export const HOURLY_CAP_PER_INSTALL = 600;

export async function handle(req: Request, be: Backend): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  try {
    const b = await readJson(req, 262_144);
    if (!b) return json({ ok: false, error: "bad_json" }, 400);

    if ("delete_install_id" in b) {
      const id = b.delete_install_id;
      if (typeof id !== "string" || !UUID_RE.test(id)) return json({ ok: false, error: "bad_install_id" }, 400);
      const n = await be.rpc("analytics_delete_install", { p_install: id });
      return json({ ok: true, deleted: n });
    }

    if (!featureOn(await loadConfig(be), "analytics")) return json({ ok: true, disabled: true, accepted: 0 });

    const r = validateBatch(b.events, be.nowSeconds());
    if (r.fatal) return json({ ok: false, error: r.fatal }, 400);
    if (r.accepted.length === 0) return json({ ok: true, accepted: 0, duplicates: 0, rejected: r.rejected });
    const res = (await be.rpc("analytics_ingest", { p_install: r.install_id, p_events: r.accepted, p_hourly_cap: HOURLY_CAP_PER_INSTALL })) as Record<string, unknown>;
    if (res.status === "throttled") return json({ ok: false, error: "throttled" }, 429);
    return json({ ok: true, accepted: res.inserted, duplicates: res.duplicates, rejected: r.rejected });
  } catch (e) {
    console.error("ingest-analytics error", e instanceof Error ? e.message : e);
    return json({ ok: false, error: "server_error" }, 500);
  }
}
