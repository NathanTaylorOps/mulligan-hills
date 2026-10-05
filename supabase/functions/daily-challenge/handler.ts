// POST /functions/v1/daily-challenge   (JWT of a signed-in or anonymous player required)
//   { action:"submit", app_version, day, score_pm, name_preset_id, template_id, rating_version, sim_version,
//     content_hash?, attestation? }
//   { action:"leaderboard", app_version, day, limit? }
//
// DEC-036: bounds and rate checks only; the server does not re-simulate. DEC-029: engine versions are sent with every
// submission; Play Integrity is optional here (env DAILY_REQUIRE_ATTESTATION=true turns it on, using the "mhi1" token from
// verify-integrity with action "daily_submit"). DEC-016/043: names are presets only. DEC-059: kill switch `daily_challenge`.
import { corsHeaders, json, readJson } from "../_shared/http.ts";
import { gate, requireUser } from "../_shared/backend.ts";
import type { Backend } from "../_shared/backend.ts";
import { importRsaPublicKey, verifyIntegrityAttestation } from "../_shared/attestation.ts";

type Obj = Record<string, unknown>;
const intIn = (v: unknown, lo: number, hi: number): v is number => typeof v === "number" && Number.isInteger(v) && v >= lo && v <= hi;
const str = (v: unknown, re: RegExp): v is string => typeof v === "string" && v.length <= 64 && re.test(v);

export const ATTEMPTS_PER_DAY = 3;  // docs/spec/data/daily_challenges.json attempts_per_day (a test keeps them equal)
export const MIN_SECONDS_BETWEEN_SUBMITS = 5;

export interface SubmitInput {
  day: number; score_pm: number; name_preset_id: number; template_id: string;
  rating_version: string; sim_version: string; content_hash: string | null; app_version: string;
}

/** Returns an error code, or the cleaned input. */
export function validateSubmit(b: Obj): string | SubmitInput {
  if (!intIn(b.day, 0, 100_000)) return "bad_day";
  if (!intIn(b.score_pm, 0, 1000)) return "bad_score";
  if (!intIn(b.name_preset_id, 0, 999)) return "bad_name_preset";
  if (!str(b.template_id, /^[a-z][a-z0-9_]{1,39}$/)) return "bad_template";
  if (!str(b.rating_version, /^MHRATE-[0-9]+\.[0-9]+\.[0-9]+$/)) return "bad_rating_version";
  if (!str(b.sim_version, /^MHSIM-[0-9]+\.[0-9]+\.[0-9]+$/)) return "bad_sim_version";
  if (b.content_hash !== undefined && b.content_hash !== null && !str(b.content_hash, /^[0-9a-f]{8,64}$/)) return "bad_content_hash";
  if (!str(b.app_version, /^[0-9]+\.[0-9]+\.[0-9]+$/)) return "bad_app_version";
  return {
    day: b.day, score_pm: b.score_pm, name_preset_id: b.name_preset_id, template_id: b.template_id,
    rating_version: b.rating_version, sim_version: b.sim_version, content_hash: (b.content_hash as string | null | undefined) ?? null,
    app_version: b.app_version,
  };
}

export async function handle(req: Request, be: Backend): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  try {
    const user = await requireUser(req, be);
    if (!user) return json({ ok: false, error: "not_signed_in" }, 401);
    const b = await readJson(req, 8192);
    if (!b) return json({ ok: false, error: "bad_json" }, 400);
    const g = await gate(be, "daily_challenge", b.app_version);
    if (!g.ok) return json({ ok: false, error: g.error }, g.status);

    if (b.action === "leaderboard") {
      if (!intIn(b.day, 0, 100_000)) return json({ ok: false, error: "bad_day" }, 400);
      const limit = b.limit === undefined ? 50 : b.limit;
      if (!intIn(limit, 1, 100)) return json({ ok: false, error: "bad_limit" }, 400);
      const board = await be.rpc("daily_leaderboard", { p_user: user.id, p_day: b.day, p_limit: limit });
      return json({ ok: true, board });
    }

    if (b.action === "submit") {
      const v = validateSubmit(b);
      if (typeof v === "string") return json({ ok: false, error: v }, 400);
      const allowed = be.env("ALLOWED_RATING_VERSIONS");
      if (allowed && !allowed.split(",").map((s) => s.trim()).includes(v.rating_version)) {
        return json({ ok: false, error: "rating_version_not_allowed" }, 426);
      }
      if (be.env("DAILY_REQUIRE_ATTESTATION", "false") === "true") {
        const pem = be.env("ENTITLEMENT_PUBLIC_KEY_PEM");
        const pkg = be.env("ANDROID_PACKAGE_NAME");
        if (!pem || !pkg) throw new Error("attestation required but ENTITLEMENT_PUBLIC_KEY_PEM / ANDROID_PACKAGE_NAME not set");
        const check = await verifyIntegrityAttestation(await importRsaPublicKey(pem), b.attestation, pkg, "daily_submit", be.nowSeconds());
        if (!check.ok) return json({ ok: false, error: check.reason }, 403);
      }
      const r = (await be.rpc("daily_submit", {
        p_user: user.id, p_day: v.day, p_score_pm: v.score_pm, p_name_preset: v.name_preset_id, p_template: v.template_id,
        p_rating_version: v.rating_version, p_sim_version: v.sim_version, p_content_hash: v.content_hash, p_app_version: v.app_version,
        p_max_attempts: ATTEMPTS_PER_DAY, p_min_interval_s: MIN_SECONDS_BETWEEN_SUBMITS,
      })) as Obj;
      switch (r.status) {
        case "ok": return json({ ok: true, attempts: r.attempts, best_score_pm: r.best_score_pm, improved: r.improved });
        case "attempts_exhausted": return json({ ok: false, error: "attempts_exhausted", attempts: r.attempts, best_score_pm: r.best_score_pm }, 429);
        case "too_fast": return json({ ok: false, error: "too_fast" }, 429);
        case "bad_day": return json({ ok: false, error: "bad_day", today: r.today }, 400);
        default: return json({ ok: false, error: String(r.status ?? "rejected") }, 400);
      }
    }
    return json({ ok: false, error: "unknown_action" }, 400);
  } catch (e) {
    console.error("daily-challenge error", e instanceof Error ? e.message : e);
    return json({ ok: false, error: "server_error" }, 500);
  }
}
