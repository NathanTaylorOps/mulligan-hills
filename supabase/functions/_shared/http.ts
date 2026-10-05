// Minimal HTTP helpers shared by the Edge Functions (Deno runtime on Supabase).
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*", // native game client, not a browser; harmless
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function env(name: string, fallback?: string): string {
  // deno-lint-ignore no-explicit-any
  const v = (globalThis as any).Deno?.env.get(name) ?? fallback;
  if (v === undefined || v === "") throw new Error(`missing env ${name}`);
  return v;
}

/** Read and parse a JSON body, refusing anything larger than maxBytes (default 256 KiB). Returns null on any problem. */
export async function readJson(req: Request, maxBytes = 262_144): Promise<Record<string, unknown> | null> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > maxBytes) return null;
  const text = await req.text().catch(() => null);
  if (text === null || text.length > maxBytes) return null;
  try {
    const v = JSON.parse(text);
    return v !== null && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}
