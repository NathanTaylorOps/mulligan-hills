// Minimal HTTP helpers shared by the Edge Functions (Deno runtime on Supabase).
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*", // native game client, not a browser; harmless
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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
