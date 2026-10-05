// POST /functions/v1/cloud-save   (JWT of a signed-in or anonymous player required)
// Body: { action, app_version, ... }.  Actions:
//   list
//   begin_upload  { slot, expected_version, size_bytes, sha256 }
//   commit        { slot, expected_version, upload_id, size_bytes, sha256, summary }
//   download      { slot }
//   delete        { slot }
//
// DEC-058: cloud conflicts ALWAYS ask the player. The server never decides which copy wins:
//   * every write names the cloud version the device last saw (expected_version);
//   * if the cloud has moved on, the answer is 409 {error:"conflict", cloud:{...summary...}} and NOTHING is written;
//   * the game shows the player both sides (day, cash, holes, play time), and after the player chooses "keep mine"
//     it retries begin_upload with expected_version set to the cloud version it was just shown. That retry is the
//     player's explicit decision. "Use cloud" is a plain download; "keep both" is a download into a free local slot.
// The one exception to "ask" is byte-identical saves: if the sha256 matches the cloud copy there is nothing to ask,
// and the answer is 200 {in_sync:true}.
import { corsHeaders, json, readJson } from "../_shared/http.ts";
import { gate, requireUser } from "../_shared/backend.ts";
import type { Backend } from "../_shared/backend.ts";
import { UUID_RE } from "../_shared/analytics.ts";

type Obj = Record<string, unknown>;
const isObj = (v: unknown): v is Obj => v !== null && typeof v === "object" && !Array.isArray(v);
const intIn = (v: unknown, lo: number, hi: number): v is number => typeof v === "number" && Number.isInteger(v) && v >= lo && v <= hi;

export const DEFAULT_MAX_BYTES = 8 * 1024 * 1024;
export const DOWNLOAD_URL_TTL_SECONDS = 300;
const SUMMARY_KEYS: Record<string, [number, number]> = {
  day: [0, 100_000], cash: [-1_000_000_000_000, 1_000_000_000_000], holes: [0, 18], playtime_s: [0, 1_000_000_000],
  saved_at_unix: [0, Number.MAX_SAFE_INTEGER], save_version: [1, 1000], revision: [0, Number.MAX_SAFE_INTEGER],
  slot_kind_code: [0, 3],
};

/** The summary the conflict prompt shows. Only small whole numbers; no text from the player. Returns null if invalid. */
export function cleanSummary(s: unknown): Obj | null {
  if (!isObj(s)) return null;
  const out: Obj = {};
  for (const [k, v] of Object.entries(s)) {
    if (k === "app_version") {
      if (typeof v !== "string" || !/^[0-9]+\.[0-9]+\.[0-9]+$/.test(v)) return null;
      out[k] = v;
      continue;
    }
    const range = SUMMARY_KEYS[k];
    if (!range || !intIn(v, range[0], range[1])) return null;
    out[k] = v;
  }
  return out;
}

export function uploadPath(userId: string, slot: number, uploadId: string): string {
  return `${userId}/slot${slot}/${uploadId}.mhsave`;
}

function publicCloud(c: unknown): Obj | null {
  if (!isObj(c)) return null;
  const { storage_path: _drop, ...rest } = c;
  return rest;
}

export async function handle(req: Request, be: Backend): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  try {
    const user = await requireUser(req, be);
    if (!user) return json({ ok: false, error: "not_signed_in" }, 401);
    const b = await readJson(req, 65_536);
    if (!b) return json({ ok: false, error: "bad_json" }, 400);
    const action = b.action;

    // Deleting your own data is allowed even when the cloud is switched off (privacy first).
    if (action !== "delete") {
      const g = await gate(be, "cloud_sync", b.app_version);
      if (!g.ok) return json({ ok: false, error: g.error }, g.status);
    }
    const maxBytes = Number(be.env("CLOUD_SAVE_MAX_BYTES", String(DEFAULT_MAX_BYTES)));

    if (action === "list") {
      const rows = (await be.rpc("cloud_save_list", { p_user: user.id })) as unknown[];
      return json({ ok: true, saves: rows.map(publicCloud) });
    }

    const slot = b.slot;
    if (!intIn(slot, 0, 4)) return json({ ok: false, error: "bad_slot" }, 400);

    if (action === "begin_upload") {
      const { expected_version, size_bytes, sha256 } = b;
      if (!intIn(expected_version, 0, 2_000_000_000)) return json({ ok: false, error: "bad_expected_version" }, 400);
      if (!intIn(size_bytes, 1, maxBytes)) return json({ ok: false, error: "bad_size" }, 400);
      if (typeof sha256 !== "string" || !/^[0-9a-f]{64}$/.test(sha256)) return json({ ok: false, error: "bad_sha256" }, 400);
      const uploadId = crypto.randomUUID();
      const path = uploadPath(user.id, slot, uploadId);
      const r = (await be.rpc("cloud_save_begin", { p_user: user.id, p_slot: slot, p_expected: expected_version, p_new_path: path })) as Obj;
      if (r.status === "conflict") {
        const cloud = publicCloud(r.cloud);
        if (cloud && cloud.sha256 === sha256) return json({ ok: true, in_sync: true, cloud });
        return json({ ok: false, error: "conflict", cloud }, 409);
      }
      if (typeof r.discard_path === "string") await be.storage.remove([r.discard_path]).catch(() => {});
      const up = await be.storage.signedUploadUrl(path);
      return json({ ok: true, upload_id: uploadId, upload_url: up.url, upload_token: up.token ?? null, max_bytes: maxBytes });
    }

    if (action === "commit") {
      const { expected_version, upload_id, size_bytes, sha256 } = b;
      if (!intIn(expected_version, 0, 2_000_000_000)) return json({ ok: false, error: "bad_expected_version" }, 400);
      if (typeof upload_id !== "string" || !UUID_RE.test(upload_id)) return json({ ok: false, error: "bad_upload_id" }, 400);
      if (!intIn(size_bytes, 1, maxBytes)) return json({ ok: false, error: "bad_size" }, 400);
      if (typeof sha256 !== "string" || !/^[0-9a-f]{64}$/.test(sha256)) return json({ ok: false, error: "bad_sha256" }, 400);
      const summary = cleanSummary(b.summary);
      if (!summary) return json({ ok: false, error: "bad_summary" }, 400);
      const path = uploadPath(user.id, slot, upload_id);
      const info = await be.storage.objectInfo(path);
      if (!info) return json({ ok: false, error: "upload_missing" }, 400);
      if (info.size !== null && info.size !== size_bytes) {
        await be.storage.remove([path]).catch(() => {});
        return json({ ok: false, error: "size_mismatch" }, 400);
      }
      const r = (await be.rpc("cloud_save_commit", {
        p_user: user.id, p_slot: slot, p_expected: expected_version, p_path: path,
        p_sha256: sha256, p_size: size_bytes, p_summary: summary,
      })) as Obj;
      if (typeof r.discard_path === "string") await be.storage.remove([r.discard_path]).catch(() => {});
      if (r.status === "ok") return json({ ok: true, cloud: publicCloud(r.cloud) });
      if (r.status === "conflict") return json({ ok: false, error: "conflict", cloud: publicCloud(r.cloud) }, 409);
      return json({ ok: false, error: "stale_upload", cloud: publicCloud(r.cloud) }, 409);
    }

    if (action === "download") {
      const rows = (await be.rpc("cloud_save_list", { p_user: user.id })) as Obj[];
      const row = rows.find((x) => x.slot === slot);
      if (!row || typeof row.storage_path !== "string") return json({ ok: false, error: "not_found" }, 404);
      const url = await be.storage.signedDownloadUrl(row.storage_path, DOWNLOAD_URL_TTL_SECONDS);
      return json({ ok: true, download_url: url, expires_in: DOWNLOAD_URL_TTL_SECONDS, cloud: publicCloud(row) });
    }

    if (action === "delete") {
      const r = (await be.rpc("cloud_save_delete", { p_user: user.id, p_slot: slot })) as Obj;
      const paths = Array.isArray(r.discard_paths) ? (r.discard_paths as string[]) : [];
      await be.storage.remove(paths).catch(() => {});
      return json({ ok: true, deleted: r.status === "ok" });
    }

    return json({ ok: false, error: "unknown_action" }, 400);
  } catch (e) {
    console.error("cloud-save error", e instanceof Error ? e.message : e);
    return json({ ok: false, error: "server_error" }, 500);
  }
}
