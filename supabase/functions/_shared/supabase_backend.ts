// Real Backend: supabase-js on Deno. NOT RUN in the sandbox where this was written (no Supabase project, no network
// to npm). Method names follow the supabase-js v2 documentation as remembered; check the first deploy's logs.
import { createClient } from "npm:@supabase/supabase-js@2";
import type { Backend } from "./backend.ts";

// deno-lint-ignore no-explicit-any
const D = (globalThis as any).Deno;

export function makeBackend(): Backend {
  const url: string = D.env.get("SUPABASE_URL");
  const serviceKey: string = D.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const sb = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const bucket = () => sb.storage.from(D.env.get("CLOUD_SAVE_BUCKET") ?? "cloud-saves");

  return {
    async rpc(fn, args) {
      const { data, error } = await sb.rpc(fn, args);
      if (error) throw new Error(`rpc ${fn}: ${error.message}`);
      return data;
    },
    async getUser(jwt) {
      const { data, error } = await sb.auth.getUser(jwt);
      if (error || !data?.user) return null;
      return { id: data.user.id };
    },
    async activeConfig() {
      const { data, error } = await sb.from("remote_config_versions").select("config").eq("is_active", true).maybeSingle();
      if (error) throw new Error(`activeConfig: ${error.message}`);
      return data?.config ?? null;
    },
    async deleteAuthUser(userId) {
      const { error } = await sb.auth.admin.deleteUser(userId);
      if (error) throw new Error(`deleteUser: ${error.message}`);
    },
    storage: {
      async signedUploadUrl(path) {
        const { data, error } = await bucket().createSignedUploadUrl(path);
        if (error || !data) throw new Error(`signedUploadUrl: ${error?.message}`);
        return { url: data.signedUrl, token: data.token };
      },
      async signedDownloadUrl(path, ttl) {
        const { data, error } = await bucket().createSignedUrl(path, ttl);
        if (error || !data) throw new Error(`signedDownloadUrl: ${error?.message}`);
        return data.signedUrl;
      },
      async objectInfo(path) {
        const slash = path.lastIndexOf("/");
        const { data, error } = await bucket().list(path.slice(0, slash), { search: path.slice(slash + 1), limit: 5 });
        if (error) throw new Error(`objectInfo: ${error.message}`);
        const hit = (data ?? []).find((o: { name: string }) => o.name === path.slice(slash + 1));
        if (!hit) return null;
        const size = (hit as { metadata?: { size?: number } }).metadata?.size;
        return { size: typeof size === "number" ? size : null };
      },
      async copy(fromPath, toPath) {
        const { error } = await bucket().copy(fromPath, toPath);
        if (error) throw new Error(`copy: ${error.message}`);
      },
      async remove(paths) {
        if (paths.length === 0) return;
        const { error } = await bucket().remove(paths);
        if (error) throw new Error(`remove: ${error.message}`);
      },
    },
    nowSeconds: () => Math.floor(Date.now() / 1000),
    randomBytes: (n) => crypto.getRandomValues(new Uint8Array(n)),
    env: (name, fallback) => D.env.get(name) ?? fallback,
  };
}
