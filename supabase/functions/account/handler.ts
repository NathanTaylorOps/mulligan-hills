// POST /functions/v1/account     (deploy with verify_jwt = false, see supabase/config.toml: the web deletion page has no JWT)
// Body: { action, ... }.  Actions:
//   create_transfer_code   (JWT)            -> { code:"ABCD-EFGH-JKLM", expires_in }
//   preview_transfer       (JWT) { code }   -> the saves behind a code, summaries only (nothing changes)
//   claim_transfer         (JWT) { code, slots:[..], overwrite_slots:[..] }
//                                           copies the code owner's cloud saves into THIS player's cloud slots.
//                                           A slot that already holds a save is only replaced when the player listed it in
//                                           overwrite_slots (DEC-058: the server never overwrites without being told).
//   delete_account         (JWT) { confirm:"DELETE", install_id? }
//   delete_with_code       (no JWT) { code, confirm:"DELETE", install_id? }   the web deletion page (DEC-031)
//
// What a transfer does NOT do: it never moves the unlock (the unlock belongs to the Google/Apple account; press Restore on
// the new device, DEC-030), never moves analytics, and never signs the new device in as the old anonymous user.
// Deleting an account never touches the purchase (it belongs to the store account).
import { corsHeaders, json, readJson } from "../_shared/http.ts";
import { requireUser } from "../_shared/backend.ts";
import type { Backend } from "../_shared/backend.ts";
import { CODE_TTL_SECONDS, codeFromBytes, formatCode, hashCode, normalizeCode } from "../_shared/codes.ts";
import { UUID_RE } from "../_shared/analytics.ts";

type Obj = Record<string, unknown>;
const slotList = (v: unknown): number[] | null =>
  Array.isArray(v) && v.length <= 5 && v.every((x) => typeof x === "number" && Number.isInteger(x) && x >= 0 && x <= 4) ? (v as number[]) : null;

async function deleteEverything(be: Backend, userId: string, installId: unknown): Promise<void> {
  const paths = (await be.rpc("cloud_save_all_paths", { p_user: userId })) as string[];
  await be.storage.remove(paths);
  if (typeof installId === "string" && UUID_RE.test(installId)) await be.rpc("analytics_delete_install", { p_install: installId });
  await be.deleteAuthUser(userId); // cascades: cloud_saves, daily_scores, transfer_codes
}

export async function handle(req: Request, be: Backend): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  try {
    const b = await readJson(req, 16_384);
    if (!b) return json({ ok: false, error: "bad_json" }, 400);
    const action = b.action;

    // --- web deletion: the code is the proof of ownership -----------------------------------------------------
    if (action === "delete_with_code") {
      if (b.confirm !== "DELETE") return json({ ok: false, error: "confirm_required" }, 400);
      const code = normalizeCode(b.code);
      if (!code) return json({ ok: false, error: "bad_code" }, 400);
      const r = (await be.rpc("transfer_code_consume", { p_hash: await hashCode(code) })) as Obj;
      if (r.status !== "ok") return json({ ok: false, error: "invalid_or_expired_code" }, 403);
      await deleteEverything(be, r.user_id as string, b.install_id);
      return json({ ok: true, deleted: true });
    }

    const user = await requireUser(req, be);
    if (!user) return json({ ok: false, error: "not_signed_in" }, 401);

    if (action === "create_transfer_code") {
      const code = codeFromBytes(be.randomBytes(12));
      const r = (await be.rpc("transfer_code_create", { p_user: user.id, p_hash: await hashCode(code), p_ttl_seconds: CODE_TTL_SECONDS })) as Obj;
      if (r.status === "too_fast") return json({ ok: false, error: "too_fast" }, 429);
      return json({ ok: true, code: formatCode(code), expires_in: CODE_TTL_SECONDS });
    }

    if (action === "delete_account") {
      if (b.confirm !== "DELETE") return json({ ok: false, error: "confirm_required" }, 400);
      await deleteEverything(be, user.id, b.install_id);
      return json({ ok: true, deleted: true });
    }

    if (action === "preview_transfer" || action === "claim_transfer") {
      const code = normalizeCode(b.code);
      if (!code) return json({ ok: false, error: "bad_code" }, 400);
      const hash = await hashCode(code);
      const peek = (await be.rpc("transfer_code_peek", { p_hash: hash })) as Obj;
      if (peek.status !== "ok") return json({ ok: false, error: "invalid_or_expired_code" }, 403);
      const sourceId = peek.user_id as string;
      if (sourceId === user.id) return json({ ok: false, error: "same_account" }, 400);
      const source = (await be.rpc("cloud_save_list", { p_user: sourceId })) as Obj[];

      if (action === "preview_transfer") {
        return json({ ok: true, saves: source.map(({ storage_path: _p, ...rest }) => rest) });
      }

      const slots = slotList(b.slots);
      const overwrite = slotList(b.overwrite_slots ?? []);
      if (!slots || slots.length === 0 || !overwrite) return json({ ok: false, error: "bad_slots" }, 400);
      const wanted = source.filter((s) => slots.includes(s.slot as number));
      if (wanted.length !== slots.length) return json({ ok: false, error: "slot_not_in_source" }, 400);

      // Ask-first check for the WHOLE request before anything is copied or the code is used up.
      const mine = (await be.rpc("cloud_save_list", { p_user: user.id })) as Obj[];
      const conflicts = mine.filter((m) => slots.includes(m.slot as number) && !overwrite.includes(m.slot as number))
        .map(({ storage_path: _p, ...rest }) => rest);
      if (conflicts.length > 0) return json({ ok: false, error: "conflict", conflicts }, 409);

      const used = (await be.rpc("transfer_code_consume", { p_hash: hash })) as Obj;
      if (used.status !== "ok") return json({ ok: false, error: "invalid_or_expired_code" }, 403);

      const results: Obj[] = [];
      for (const s of wanted) {
        const slot = s.slot as number;
        const to = `${user.id}/slot${slot}/${crypto.randomUUID()}.mhsave`;
        await be.storage.copy(s.storage_path as string, to);
        const r = (await be.rpc("cloud_save_import", {
          p_user: user.id, p_slot: slot, p_path: to, p_sha256: s.sha256, p_size: s.size_bytes,
          p_summary: s.summary, p_overwrite: overwrite.includes(slot),
        })) as Obj;
        if (typeof r.discard_path === "string") await be.storage.remove([r.discard_path]).catch(() => {});
        results.push({ slot, status: r.status, cloud: r.cloud ?? null });
      }
      return json({ ok: true, results });
    }

    return json({ ok: false, error: "unknown_action" }, 400);
  } catch (e) {
    console.error("account error", e instanceof Error ? e.message : e);
    return json({ ok: false, error: "server_error" }, 500);
  }
}
