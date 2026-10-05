import { assertEquals } from "../_shared/testing.ts";
import { FakeBackend, goodConfig, post } from "../_shared/fake_backend.ts";
import { handle } from "./handler.ts";

type J = Record<string, any>; // deno-lint-ignore no-explicit-any
const get = async (be: FakeBackend, qs = ""): Promise<{ status: number; body: J }> => {
  const r = await handle(new Request("https://x.test/fn" + qs), be); return { status: r.status, body: await r.json() };
};

Deno.test("remote-config: serves the active config, GET and POST, no sign in", async () => {
  const be = new FakeBackend();
  const g = await get(be);
  assertEquals(g.status, 200); assertEquals(g.body.config.config_version, 3); assertEquals(g.body.config.kill_switches.daily_challenge, true);
  const r = await handle(post({}), be); assertEquals(r.status, 200);
});

Deno.test("remote-config: not_modified when the game already holds this version", async () => {
  const be = new FakeBackend();
  assertEquals((await get(be, "?have=3")).body, { ok: true, not_modified: true, config_version: 3 });
  assertEquals((await get(be, "?have=2")).body.config.config_version, 3);
  assertEquals((await get(be, "?have=abc")).status, 200);
  const r = await handle(post({ have: 3 }), be); assertEquals((await r.json()).not_modified, true);
});

Deno.test("remote-config: a config that breaks the rules is never served", async () => {
  const be = new FakeBackend();
  be.config = goodConfig({ economy: { ...(goodConfig().economy as object), start_cash: 1 } });
  const r = await get(be); assertEquals(r.status, 503); assertEquals(r.body.error, "config_invalid");
  be.config = null; assertEquals((await get(be)).status, 404);
  const r2 = await handle(new Request("https://x.test", { method: "DELETE" }), be); assertEquals(r2.status, 405);
});
