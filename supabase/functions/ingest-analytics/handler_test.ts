import { assert, assertEquals } from "../_shared/testing.ts";
import { FakeBackend, goodConfig, post } from "../_shared/fake_backend.ts";
import { handle } from "./handler.ts";

type J = Record<string, any>; // deno-lint-ignore no-explicit-any
const INST = "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d";
const call = async (be: FakeBackend, body: unknown): Promise<{ status: number; body: J }> => {
  const r = await handle(post(body), be); return { status: r.status, body: await r.json() };
};
const ev = (id: string, over: Record<string, unknown> = {}) => ({
  schema_version: 1, event_id: id, name: "app_open", ts_unix: 1790000000 - 5, session_id: "aaaaaaaa-1111-4222-8333-444455556666",
  install_id: INST, app_version: "0.1.0", platform: "android", build_kind: "demo", props: { first_run: true, build_kind: "demo" }, ...over });
const ID = (n: number) => `0b5c2a3e-1111-4222-8333-44445555${String(n).padStart(4, "0")}`;

Deno.test("analytics: valid events are stored, retries are duplicates", async () => {
  const be = new FakeBackend();
  const r = await call(be, { events: [ev(ID(1)), ev(ID(2))] });
  assertEquals(r.status, 200); assertEquals(r.body.accepted, 2); assertEquals(be.analytics.size, 2);
  const again = await call(be, { events: [ev(ID(1))] });
  assertEquals(again.body.accepted, 0); assertEquals(again.body.duplicates, 1);
});

Deno.test("analytics: bad events are rejected one by one, the good ones still go in", async () => {
  const be = new FakeBackend();
  const r = await call(be, { events: [ev(ID(1)), ev(ID(2), { name: "ad_click" }), ev(ID(3), { props: { first_run: "yes", build_kind: "demo" } })] });
  assertEquals(r.body.accepted, 1); assertEquals(r.body.rejected.length, 2); assertEquals(r.body.rejected[0].index, 1);
});

Deno.test("analytics: a declined consent leaves no event (DEC-057)", async () => {
  const be = new FakeBackend();
  const r = await call(be, { events: [ev(ID(1), { name: "consent_decision", props: { analytics: false } })] });
  assertEquals(r.body.accepted, 0); assert(String(r.body.rejected[0].reason).includes("declined"));
  assertEquals(be.analytics.size, 0);
  const yes = await call(be, { events: [ev(ID(2), { name: "consent_decision", props: { analytics: true, notifications: false } })] });
  assertEquals(yes.body.accepted, 1);
});

Deno.test("analytics: kill switch stores nothing", async () => {
  const be = new FakeBackend();
  be.config = goodConfig({ kill_switches: { ...(goodConfig().kill_switches as object), analytics: false } });
  const r = await call(be, { events: [ev(ID(1))] });
  assertEquals(r.status, 200); assertEquals(r.body.disabled, true); assertEquals(be.analytics.size, 0);
  assertEquals((await call(be, { delete_install_id: INST })).status, 200, "erasure still works when collection is off");
});

Deno.test("analytics: batch rules, erasure, bad input", async () => {
  const be = new FakeBackend();
  assertEquals((await call(be, { events: [] })).status, 400);
  assertEquals((await call(be, { events: [ev(ID(1)), ev(ID(2), { install_id: "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6e" })] })).status, 400);
  assertEquals((await call(be, { nothing: 1 })).status, 400);
  await call(be, { events: [ev(ID(1)), ev(ID(2))] });
  const d = await call(be, { delete_install_id: INST });
  assertEquals(d.body.deleted, 2); assertEquals(be.analytics.size, 0);
  assertEquals((await call(be, { delete_install_id: "x" })).status, 400);
  const r = await handle(new Request("https://x.test", { method: "GET" }), be); assertEquals(r.status, 405);
});
