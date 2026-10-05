import { assert, assertEquals } from "../_shared/testing.ts";
import { FakeBackend, post } from "../_shared/fake_backend.ts";
import { handle } from "./handler.ts";

const OLD = "11111111-1111-4111-8111-111111111111", NEW = "22222222-2222-4222-8222-222222222222";
const SHA = "a".repeat(64);
type J = Record<string, any>; // deno-lint-ignore no-explicit-any
const call = async (be: FakeBackend, body: unknown, jwt?: string): Promise<{ status: number; body: J }> => {
  const r = await handle(post(body, jwt), be); return { status: r.status, body: await r.json() };
};
function seedSave(be: FakeBackend, user: string, slot: number, day: number): string {
  const path = `${user}/slot${slot}/seed${day}.mhsave`;
  be.putObject(path, 500);
  be.rows.set(`${user}:${slot}`, { version: 1, storage_path: path, sha256: SHA, size_bytes: 500, summary: { day, holes: 6 }, pending_path: null });
  return path;
}

Deno.test("account: create a transfer code, shown as XXXX-XXXX-XXXX, only the hash is stored", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(OLD);
  const r = await call(be, { action: "create_transfer_code" }, jwt);
  assertEquals(r.status, 200); assert(/^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(r.body.code)); assertEquals(r.body.expires_in, 900);
  const stored = [...be.codes.keys()][0];
  assertEquals(stored.length, 64); assert(!stored.includes(r.body.code.replaceAll("-", "")));
  assertEquals((await call(be, { action: "create_transfer_code" }, jwt)).status, 429, "two codes within 10 s");
  assertEquals((await call(be, { action: "create_transfer_code" })).status, 401);
});

Deno.test("account: preview shows summaries only; nothing changes", async () => {
  const be = new FakeBackend(); const jwtOld = be.addUser(OLD); const jwtNew = be.addUser(NEW);
  seedSave(be, OLD, 0, 12);
  const { body } = await call(be, { action: "create_transfer_code" }, jwtOld);
  const p = await call(be, { action: "preview_transfer", code: body.code.toLowerCase() }, jwtNew);
  assertEquals(p.status, 200); assertEquals(p.body.saves.length, 1); assertEquals(p.body.saves[0].summary.day, 12);
  assert(!("storage_path" in p.body.saves[0]));
  assertEquals([...be.codes.values()][0].used, false, "preview does not use the code");
  assertEquals((await call(be, { action: "preview_transfer", code: "AAAA-AAAA-AAAA" }, jwtNew)).status, 403);
  assertEquals((await call(be, { action: "preview_transfer", code: "short" }, jwtNew)).body.error, "bad_code");
  assertEquals((await call(be, { action: "preview_transfer", code: body.code }, jwtOld)).body.error, "same_account");
});

Deno.test("account DEC-058: claim into an empty slot works, into an occupied slot ASKS first and uses nothing up", async () => {
  const be = new FakeBackend(); const jwtOld = be.addUser(OLD); const jwtNew = be.addUser(NEW);
  seedSave(be, OLD, 0, 12); seedSave(be, OLD, 1, 30);
  const mine = seedSave(be, NEW, 1, 2);                                   // the new device already has something in slot 1
  const { body } = await call(be, { action: "create_transfer_code" }, jwtOld);

  const ask = await call(be, { action: "claim_transfer", code: body.code, slots: [0, 1] }, jwtNew);
  assertEquals(ask.status, 409); assertEquals(ask.body.error, "conflict");
  assertEquals(ask.body.conflicts.map((c: J) => c.slot), [1]); assertEquals(ask.body.conflicts[0].summary.day, 2);
  assertEquals([...be.codes.values()][0].used, false, "code not used up by a refused claim");
  assert(be.objects.has(mine), "nothing was copied or deleted");
  assertEquals(be.rows.get(`${NEW}:0`), undefined);

  const ok = await call(be, { action: "claim_transfer", code: body.code, slots: [0, 1], overwrite_slots: [1] }, jwtNew);
  assertEquals(ok.status, 200); assertEquals(ok.body.results.map((r: J) => r.status), ["ok", "ok"]);
  assertEquals(be.rows.get(`${NEW}:1`)!.summary.day, 30);
  assertEquals(be.rows.get(`${NEW}:0`)!.version, 1);
  assert(be.removed.includes(mine), "the replaced object is deleted after the player confirmed");
  assertEquals(be.rows.get(`${OLD}:0`)!.version, 1, "the original owner's cloud copy is left alone");
  assertEquals((await call(be, { action: "claim_transfer", code: body.code, slots: [0] }, jwtNew)).status, 403, "a code works once");
});

Deno.test("account: claim input checks", async () => {
  const be = new FakeBackend(); const jwtOld = be.addUser(OLD); const jwtNew = be.addUser(NEW);
  seedSave(be, OLD, 0, 1);
  const { body } = await call(be, { action: "create_transfer_code" }, jwtOld);
  assertEquals((await call(be, { action: "claim_transfer", code: body.code, slots: [] }, jwtNew)).body.error, "bad_slots");
  assertEquals((await call(be, { action: "claim_transfer", code: body.code, slots: [7] }, jwtNew)).body.error, "bad_slots");
  assertEquals((await call(be, { action: "claim_transfer", code: body.code, slots: [3] }, jwtNew)).body.error, "slot_not_in_source");
  be.now += 901;
  assertEquals((await call(be, { action: "claim_transfer", code: body.code, slots: [0] }, jwtNew)).status, 403, "expired after 15 minutes");
});

Deno.test("account: delete_account removes saves, objects, analytics and the sign in", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(OLD);
  const path = seedSave(be, OLD, 0, 1);
  const inst = "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d";
  assertEquals((await call(be, { action: "delete_account" }, jwt)).body.error, "confirm_required");
  assertEquals((await call(be, { action: "delete_account", confirm: "yes" }, jwt)).status, 400);
  const r = await call(be, { action: "delete_account", confirm: "DELETE", install_id: inst }, jwt);
  assertEquals(r.status, 200);
  assert(be.removed.includes(path)); assertEquals(be.deletedUsers, [OLD]); assertEquals(be.analyticsDeleted, [inst]);
  assertEquals((await call(be, { action: "delete_account", confirm: "DELETE", install_id: "not-a-uuid" }, be.addUser(NEW))).status, 200);
});

Deno.test("account: web deletion with a code needs no JWT but needs a valid code and the word DELETE", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(OLD);
  seedSave(be, OLD, 0, 1);
  const { body } = await call(be, { action: "create_transfer_code" }, jwt);
  assertEquals((await call(be, { action: "delete_with_code", code: body.code })).body.error, "confirm_required");
  assertEquals((await call(be, { action: "delete_with_code", code: "AAAA-BBBB-CCCC", confirm: "DELETE" })).status, 403);
  assertEquals(be.deletedUsers.length, 0);
  const r = await call(be, { action: "delete_with_code", code: body.code, confirm: "DELETE" });
  assertEquals(r.status, 200); assertEquals(be.deletedUsers, [OLD]);
  assertEquals((await call(be, { action: "delete_with_code", code: body.code, confirm: "DELETE" })).status, 403, "code is single use");
});

Deno.test("account: unknown action and bad body", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(OLD);
  assertEquals((await call(be, { action: "nope" }, jwt)).body.error, "unknown_action");
  assertEquals((await call(be, { action: "nope" })).status, 401);
  const r = await handle(new Request("https://x.test", { method: "POST", body: "not json" }), be);
  assertEquals(r.status, 400);
});
