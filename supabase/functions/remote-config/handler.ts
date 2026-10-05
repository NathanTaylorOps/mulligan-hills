// GET or POST /functions/v1/remote-config      optional body/query: { have: <config_version the game already holds> }
// 200 { ok:true, config:{...} } | 200 { ok:true, not_modified:true, config_version } | 503 { error:"config_invalid" }
// The config is validated again here against docs/spec/data/remote_config.schema.json (see _shared/remote_config.ts). On any
// problem the game keeps its last good config or its bundled defaults. This endpoint needs no player sign in.
import { corsHeaders, json, readJson } from "../_shared/http.ts";
import type { Backend } from "../_shared/backend.ts";
import { validateRemoteConfig } from "../_shared/remote_config.ts";

export async function handle(req: Request, be: Backend): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET" && req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  try {
    let have: number | null = null;
    if (req.method === "GET") {
      const q = new URL(req.url).searchParams.get("have");
      if (q !== null && /^[0-9]{1,7}$/.test(q)) have = Number(q);
    } else {
      const b = await readJson(req, 1024);
      if (b && typeof b.have === "number" && Number.isInteger(b.have)) have = b.have;
    }
    const cfg = await be.activeConfig();
    if (!cfg) return json({ ok: false, error: "no_config" }, 404);
    const errs = validateRemoteConfig(cfg);
    if (errs.length > 0) {
      console.error("remote-config invalid", errs.join("; "));
      return json({ ok: false, error: "config_invalid" }, 503);
    }
    const version = (cfg as { config_version: number }).config_version;
    if (have !== null && have === version) return json({ ok: true, not_modified: true, config_version: version });
    return json({ ok: true, config: cfg });
  } catch (e) {
    console.error("remote-config error", e instanceof Error ? e.message : e);
    return json({ ok: false, error: "server_error" }, 500);
  }
}
