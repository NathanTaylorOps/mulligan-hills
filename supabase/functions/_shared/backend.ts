// The ONE seam between our Edge Function logic and Supabase. Handlers only talk to this interface, so tests can use an
// in-memory fake (fake_backend.ts) and the real thing (supabase_backend.ts) is the only file that imports supabase-js.
import { featureOn, minAppVersion, validateRemoteConfig } from "./remote_config.ts";
import type { KillSwitch } from "./remote_config.ts";
import { semverGte } from "./versions.ts";

export interface StorageApi {
  /** URL the game PUTs the save bytes to. */
  signedUploadUrl(path: string): Promise<{ url: string; token?: string }>;
  signedDownloadUrl(path: string, ttlSeconds: number): Promise<string>;
  /** null when the object does not exist; size is null when Storage did not report one */
  objectInfo(path: string): Promise<{ size: number | null } | null>;
  copy(fromPath: string, toPath: string): Promise<void>;
  remove(paths: string[]): Promise<void>;
}

export interface Backend {
  /** Calls a service-role-only SQL function (see supabase/migrations). Throws on database errors. */
  rpc(fn: string, args: Record<string, unknown>): Promise<unknown>;
  /** Looks up the signed-in player from a JWT. null when the token is not valid. */
  getUser(jwt: string): Promise<{ id: string } | null>;
  /** The active remote config JSON, or null. */
  activeConfig(): Promise<unknown | null>;
  deleteAuthUser(userId: string): Promise<void>;
  storage: StorageApi;
  nowSeconds(): number;
  randomBytes(n: number): Uint8Array;
  /** Secrets and settings (Deno.env in production, a plain object in tests). */
  env(name: string, fallback?: string): string | undefined;
}

export function bearer(req: Request): string | null {
  const h = req.headers.get("authorization") ?? "";
  const m = /^Bearer\s+(\S{10,4096})$/i.exec(h);
  return m ? m[1] : null;
}

/** Signed-in player (anonymous sign-ins count) or null. */
export async function requireUser(req: Request, be: Backend): Promise<{ id: string } | null> {
  const jwt = bearer(req);
  if (!jwt) return null;
  try {
    return await be.getUser(jwt);
  } catch {
    return null;
  }
}

// --- remote config with a 30 second cache per Edge Function instance ----------------------------------------------
const cache = new WeakMap<Backend, { at: number; config: unknown }>();
export const CONFIG_CACHE_SECONDS = 30;

/** The active config if it is present AND valid; otherwise null (callers then fail open, see featureOn). */
export async function loadConfig(be: Backend): Promise<unknown | null> {
  const hit = cache.get(be);
  const now = be.nowSeconds();
  if (hit && now - hit.at < CONFIG_CACHE_SECONDS) return hit.config;
  let config: unknown | null = null;
  try {
    const c = await be.activeConfig();
    if (c && validateRemoteConfig(c).length === 0) config = c;
  } catch (e) {
    console.error("loadConfig failed", e instanceof Error ? e.message : e);
  }
  cache.set(be, { at: now, config });
  return config;
}

export type Gate = { ok: true } | { ok: false; status: number; error: string };

/** Kill switch + minimum app version. appVersion comes from the request body. */
export async function gate(be: Backend, feature: KillSwitch, appVersion: unknown): Promise<Gate> {
  const cfg = await loadConfig(be);
  if (!featureOn(cfg, feature)) return { ok: false, status: 503, error: "feature_disabled" };
  const min = minAppVersion(cfg);
  if (min && !semverGte(appVersion, min)) return { ok: false, status: 426, error: "update_required" };
  return { ok: true };
}
