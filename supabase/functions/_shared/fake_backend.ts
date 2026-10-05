// TEST SUPPORT ONLY. An in-memory stand-in for Supabase that follows the same rules as the SQL functions in
// supabase/migrations (the SQL itself is tested separately by supabase/tests/run_sql_tests.sh against a real PostgreSQL).
// It lets the handler tests check status codes, kill switches, conflict answers and clean-up calls without a network.
import type { Backend } from "./backend.ts";

type Obj = Record<string, unknown>;
interface Row { version: number; storage_path: string | null; sha256: string | null; size_bytes: number | null; summary: Obj; pending_path: string | null }

export function goodConfig(over: Obj = {}): Obj {
  return {
    schema: "mh.remote_config", schema_version: 1, config_version: 3, issued_unix: 1790000000, min_app_version: "0.1.0",
    kill_switches: { cloud_sync: true, daily_challenge: true, analytics: true, purchase_flow: true, tournaments: true, notifications: true },
    economy: { parcel_base_cost: 25000, parcel_growth_pct: 130,
      hole_cost: 8000, start_cash: 40000, green_fee_min: 5, green_fee_max: 250 },
    events: { random_event_per_day_permille: 60, commission_offer_per_day_permille: 40, event_cash_scale_pct: 100 },
    ...over,
  };
}

export class FakeBackend implements Backend {
  now = 1_790_000_000;
  config: unknown = goodConfig();
  users = new Map<string, string>();               // jwt -> user id
  deletedUsers: string[] = [];
  objects = new Map<string, number>();             // storage path -> size
  removed: string[] = [];
  rows = new Map<string, Row>();
  codes = new Map<string, { user: string; expires: number; used: boolean; created: number }>();
  daily = new Map<string, { attempts: number; best: number; last: number }>();
  analytics = new Map<string, Obj>();              // event_id -> event
  analyticsDeleted: string[] = [];
  rpcLog: string[] = [];
  settings: Record<string, string> = {};
  failRpc: string | null = null;

  addUser(id: string): string { const jwt = `jwt-${id}-xxxxxxxx`; this.users.set(jwt, id); return jwt; }
  nowSeconds() { return this.now; }
  randomBytes(n: number) { const b = new Uint8Array(n); for (let i = 0; i < n; i++) b[i] = (i * 37 + this.now) & 255; return b; }
  env(name: string, fallback?: string) { return this.settings[name] ?? fallback; }
  getUser(jwt: string) { const id = this.users.get(jwt); return Promise.resolve(id ? { id } : null); }
  activeConfig() { return Promise.resolve(this.config); }
  deleteAuthUser(id: string) {
    this.deletedUsers.push(id);
    for (const k of [...this.rows.keys()]) if (k.startsWith(id + ":")) this.rows.delete(k);
    return Promise.resolve();
  }

  /** Pretend the game PUT its bytes to the signed upload URL. */
  putObject(path: string, size: number) { this.objects.set(path, size); }

  storage = {
    signedUploadUrl: (path: string) => Promise.resolve({ url: `https://fake.storage/upload/${path}`, token: "tok" }),
    signedDownloadUrl: (path: string, ttl: number) => Promise.resolve(`https://fake.storage/download/${path}?ttl=${ttl}`),
    objectInfo: (path: string) => Promise.resolve(this.objects.has(path) ? { size: this.objects.get(path)! } : null),
    copy: (from: string, to: string) => {
      if (!this.objects.has(from)) return Promise.reject(new Error("copy: source missing"));
      this.objects.set(to, this.objects.get(from)!);
      return Promise.resolve();
    },
    remove: (paths: string[]) => { for (const p of paths) { this.objects.delete(p); this.removed.push(p); } return Promise.resolve(); },
  };

  private row(user: string, slot: number): Row {
    const k = `${user}:${slot}`;
    if (!this.rows.has(k)) this.rows.set(k, { version: 0, storage_path: null, sha256: null, size_bytes: null, summary: {}, pending_path: null });
    return this.rows.get(k)!;
  }
  private pub(slot: number, r: Row): Obj { return { slot, version: r.version, sha256: r.sha256, size_bytes: r.size_bytes, summary: r.summary, updated_at: "now" }; }

  // deno-lint-ignore require-await
  async rpc(fn: string, a: Record<string, unknown>): Promise<unknown> {
    this.rpcLog.push(fn);
    if (this.failRpc === fn) throw new Error("boom " + fn);
    switch (fn) {
      case "cloud_save_begin": {
        const r = this.row(a.p_user as string, a.p_slot as number);
        if (r.version !== a.p_expected) return { status: "conflict", cloud: this.pub(a.p_slot as number, r) };
        const old = r.pending_path; r.pending_path = a.p_new_path as string;
        return { status: "ok", version: r.version, discard_path: old };
      }
      case "cloud_save_commit": {
        const slot = a.p_slot as number; const r = this.row(a.p_user as string, slot);
        if (r.version !== a.p_expected) return { status: "conflict", cloud: this.pub(slot, r), discard_path: a.p_path };
        if (r.pending_path !== a.p_path) return { status: "stale_upload", cloud: this.pub(slot, r), discard_path: a.p_path };
        const old = r.storage_path;
        Object.assign(r, { version: r.version + 1, storage_path: a.p_path, sha256: a.p_sha256, size_bytes: a.p_size, summary: a.p_summary, pending_path: null });
        return { status: "ok", cloud: this.pub(slot, r), discard_path: old };
      }
      case "cloud_save_list": {
        const out: Obj[] = [];
        for (const [k, r] of this.rows) if (k.startsWith(a.p_user + ":") && r.version > 0) out.push({ ...this.pub(Number(k.split(":")[1]), r), storage_path: r.storage_path });
        return out.sort((x, y) => (x.slot as number) - (y.slot as number));
      }
      case "cloud_save_delete": {
        const k = `${a.p_user}:${a.p_slot}`; const r = this.rows.get(k);
        if (!r) return { status: "not_found", discard_paths: [] };
        this.rows.delete(k);
        return { status: "ok", discard_paths: [r.storage_path, r.pending_path].filter((x) => x) };
      }
      case "cloud_save_all_paths": {
        const out: string[] = [];
        for (const [k, r] of this.rows) if (k.startsWith(a.p_user + ":")) { if (r.storage_path) out.push(r.storage_path); if (r.pending_path) out.push(r.pending_path); }
        return out;
      }
      case "cloud_save_import": {
        const slot = a.p_slot as number; const r = this.row(a.p_user as string, slot);
        if (r.version > 0 && !a.p_overwrite) return { status: "conflict", cloud: this.pub(slot, r), discard_path: a.p_path };
        const old = r.storage_path;
        Object.assign(r, { version: r.version + 1, storage_path: a.p_path, sha256: a.p_sha256, size_bytes: a.p_size, summary: a.p_summary });
        return { status: "ok", cloud: this.pub(slot, r), discard_path: old };
      }
      case "transfer_code_create": {
        const user = a.p_user as string;
        for (const c of this.codes.values()) if (c.user === user && this.now - c.created < 10) return { status: "too_fast" };
        for (const [h, c] of [...this.codes]) if (c.user === user) this.codes.delete(h);
        this.codes.set(a.p_hash as string, { user, expires: this.now + (a.p_ttl_seconds as number), used: false, created: this.now });
        return { status: "ok", expires_in: a.p_ttl_seconds };
      }
      case "transfer_code_peek": {
        const c = this.codes.get(a.p_hash as string);
        return c && !c.used && c.expires > this.now ? { status: "ok", user_id: c.user } : { status: "invalid" };
      }
      case "transfer_code_consume": {
        const c = this.codes.get(a.p_hash as string);
        if (!c || c.used || c.expires <= this.now) return { status: "invalid" };
        c.used = true;
        return { status: "ok", user_id: c.user };
      }
      case "daily_submit": {
        const k = `${a.p_day}:${a.p_user}`; const d = this.daily.get(k);
        const today = Math.floor(this.now / 86400);
        if ((a.p_day as number) < today - 1 || (a.p_day as number) > today) return { status: "bad_day", today };
        if (!d) { this.daily.set(k, { attempts: 1, best: a.p_score_pm as number, last: this.now }); return { status: "ok", attempts: 1, best_score_pm: a.p_score_pm, improved: true }; }
        if (d.attempts >= (a.p_max_attempts as number)) return { status: "attempts_exhausted", attempts: d.attempts, best_score_pm: d.best };
        if (this.now - d.last < (a.p_min_interval_s as number)) return { status: "too_fast" };
        const improved = (a.p_score_pm as number) > d.best;
        d.attempts++; d.last = this.now; if (improved) d.best = a.p_score_pm as number;
        return { status: "ok", attempts: d.attempts, best_score_pm: d.best, improved };
      }
      case "daily_leaderboard": return { day: a.p_day, total: 0, top: [], me: null };
      case "analytics_ingest": {
        const evs = a.p_events as Obj[]; let inserted = 0;
        for (const e of evs) if (!this.analytics.has(e.event_id as string)) { this.analytics.set(e.event_id as string, e); inserted++; }
        return { status: "ok", inserted, duplicates: evs.length - inserted };
      }
      case "analytics_delete_install": {
        this.analyticsDeleted.push(a.p_install as string);
        let n = 0;
        for (const [id, e] of [...this.analytics]) if (e.install_id === a.p_install) { this.analytics.delete(id); n++; }
        return n;
      }
      default: throw new Error("fake rpc not implemented: " + fn);
    }
  }
}

export function post(body: unknown, jwt?: string, url = "https://x.test/fn"): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (jwt) headers.authorization = `Bearer ${jwt}`;
  return new Request(url, { method: "POST", headers, body: JSON.stringify(body) });
}
