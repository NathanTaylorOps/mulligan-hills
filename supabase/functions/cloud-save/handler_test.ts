import { assert, assertEquals } from "../_shared/testing.ts";
import { FakeBackend, goodConfig, post } from "../_shared/fake_backend.ts";
import { cleanSummary, handle, uploadPath } from "./handler.ts";

const SHA_A = "a".repeat(64), SHA_B = "b".repeat(64);
const U1 = "11111111-1111-4111-8111-111111111111";
const summary = { day: 5, cash: 1200, holes: 6, playtime_s: 3600, saved_at_unix: 1790000000, save_version: 1, app_version: "0.1.0" };
type J = Record<string, any>; // deno-lint-ignore no-explicit-any
const call = async (be: FakeBackend, body: unknown, jwt?: string): Promise<{ status: number; body: J }> => {
  const r = await handle(post(body, jwt), be); return { status: r.status, body: await r.json() };
};

/** Full happy path upload from a device: begin, PUT, commit. Returns the commit answer. */
async function upload(be: FakeBackend, jwt: string, uid: string, slot: number, expected: number, sha: string, size = 1000) {
  const b = await call(be, { action: "begin_upload", app_version: "0.1.0", slot, expected_version: expected, size_bytes: size, sha256: sha }, jwt);
  if (b.status !== 200 || b.body.in_sync) return b;
  be.putObject(uploadPath(uid, slot, b.body.upload_id), size);
  return await call(be, { action: "commit", app_version: "0.1.0", slot, expected_version: expected, upload_id: b.body.upload_id, size_bytes: size, sha256: sha, summary }, jwt);
}

Deno.test("cloud-save: needs a signed-in player", async () => {
  const be = new FakeBackend();
  assertEquals((await call(be, { action: "list", app_version: "0.1.0" })).status, 401);
  assertEquals((await call(be, { action: "list", app_version: "0.1.0" }, "jwt-unknown-xxxxxxxx")).status, 401);
  assertEquals((await handle(new Request("https://x.test", { method: "GET" }), be)).status, 405);
});

Deno.test("cloud-save: first upload, list, download", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  const r = await upload(be, jwt, U1, 0, 0, SHA_A);
  assertEquals(r.status, 200); assertEquals(r.body.cloud.version, 1);
  assert(!("storage_path" in r.body.cloud), "storage path never leaves the server");
  const l = await call(be, { action: "list", app_version: "0.1.0" }, jwt);
  assertEquals(l.body.saves.length, 1); assertEquals(l.body.saves[0].summary.day, 5);
  const d = await call(be, { action: "download", app_version: "0.1.0", slot: 0 }, jwt);
  assertEquals(d.status, 200); assert(d.body.download_url.includes("ttl=300")); assertEquals(d.body.cloud.sha256, SHA_A);
  assertEquals((await call(be, { action: "download", app_version: "0.1.0", slot: 3 }, jwt)).status, 404);
});

Deno.test("cloud-save DEC-058: a device that never synced before is ASKED, nothing is overwritten", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  await upload(be, jwt, U1, 0, 0, SHA_A);
  const before = [...be.rows.values()][0].storage_path;
  const r = await call(be, { action: "begin_upload", app_version: "0.1.0", slot: 0, expected_version: 0, size_bytes: 1000, sha256: SHA_B }, jwt);
  assertEquals(r.status, 409); assertEquals(r.body.error, "conflict");
  assertEquals(r.body.cloud.version, 1); assertEquals(r.body.cloud.summary.holes, 6);
  assertEquals([...be.rows.values()][0].storage_path, before, "cloud untouched");
});

Deno.test("cloud-save DEC-058: the player picks 'keep mine' -> retry with the shown version succeeds", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  await upload(be, jwt, U1, 0, 0, SHA_A);
  const conflict = await call(be, { action: "begin_upload", app_version: "0.1.0", slot: 0, expected_version: 0, size_bytes: 1000, sha256: SHA_B }, jwt);
  const r = await upload(be, jwt, U1, 0, conflict.body.cloud.version, SHA_B);
  assertEquals(r.status, 200); assertEquals(r.body.cloud.version, 2); assertEquals(r.body.cloud.sha256, SHA_B);
  assertEquals(be.removed.length, 1, "the replaced cloud object is deleted afterwards");
});

Deno.test("cloud-save: identical bytes are in sync, no prompt, no upload", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  await upload(be, jwt, U1, 0, 0, SHA_A);
  const r = await call(be, { action: "begin_upload", app_version: "0.1.0", slot: 0, expected_version: 0, size_bytes: 1000, sha256: SHA_A }, jwt);
  assertEquals(r.status, 200); assertEquals(r.body.in_sync, true); assertEquals(r.body.cloud.version, 1);
});

Deno.test("cloud-save: two devices racing; the loser is refused and then asked", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  const a = await call(be, { action: "begin_upload", app_version: "0.1.0", slot: 1, expected_version: 0, size_bytes: 500, sha256: SHA_A }, jwt);
  be.putObject(uploadPath(U1, 1, a.body.upload_id), 500);
  await upload(be, jwt, U1, 1, 0, SHA_B, 700); // device B begins (which cancels A's pending upload) and finishes first
  const c = await call(be, { action: "commit", app_version: "0.1.0", slot: 1, expected_version: 0, upload_id: a.body.upload_id, size_bytes: 500, sha256: SHA_A, summary }, jwt);
  assertEquals(c.status, 400); assertEquals(c.body.error, "upload_missing");
  assertEquals([...be.rows.values()][0].sha256, SHA_B, "device B's save survives");
  const retry = await call(be, { action: "begin_upload", app_version: "0.1.0", slot: 1, expected_version: 0, size_bytes: 500, sha256: SHA_A }, jwt);
  assertEquals(retry.status, 409, "device A is now asked about the conflict");
  assertEquals(retry.body.cloud.version, 1);
});

Deno.test("cloud-save: commit with a stale expected version is a conflict even if the file is there", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  const a = await call(be, { action: "begin_upload", app_version: "0.1.0", slot: 2, expected_version: 0, size_bytes: 500, sha256: SHA_A }, jwt);
  be.putObject(uploadPath(U1, 2, a.body.upload_id), 500);
  const row = [...be.rows.values()][0]; row.version = 4; row.storage_path = "x"; row.sha256 = SHA_B; row.size_bytes = 1; // someone else moved the cloud on
  const c = await call(be, { action: "commit", app_version: "0.1.0", slot: 2, expected_version: 0, upload_id: a.body.upload_id, size_bytes: 500, sha256: SHA_A, summary }, jwt);
  assertEquals(c.status, 409); assertEquals(c.body.error, "conflict"); assertEquals(row.version, 4);
});

Deno.test("cloud-save: validation", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  const base = { action: "begin_upload", app_version: "0.1.0", slot: 0, expected_version: 0, size_bytes: 1000, sha256: SHA_A };
  assertEquals((await call(be, { ...base, slot: 5 }, jwt)).body.error, "bad_slot");
  assertEquals((await call(be, { ...base, slot: "0" }, jwt)).body.error, "bad_slot");
  assertEquals((await call(be, { ...base, size_bytes: 0 }, jwt)).body.error, "bad_size");
  assertEquals((await call(be, { ...base, size_bytes: 9 * 1024 * 1024 }, jwt)).body.error, "bad_size");
  be.settings.CLOUD_SAVE_MAX_BYTES = "20000000";
  assertEquals((await call(be, { ...base, size_bytes: 9 * 1024 * 1024 }, jwt)).status, 200);
  assertEquals((await call(be, { ...base, sha256: "xyz" }, jwt)).body.error, "bad_sha256");
  assertEquals((await call(be, { ...base, expected_version: -1 }, jwt)).body.error, "bad_expected_version");
  assertEquals((await call(be, { ...base, action: "nope" }, jwt)).body.error, "unknown_action");
  const c = { action: "commit", app_version: "0.1.0", slot: 0, expected_version: 0, upload_id: "../../etc/passwd", size_bytes: 10, sha256: SHA_A, summary };
  assertEquals((await call(be, c, jwt)).body.error, "bad_upload_id");
  const id = "0b5c2a3e-1111-4222-8333-444455556666";
  assertEquals((await call(be, { ...c, upload_id: id }, jwt)).body.error, "upload_missing");
  be.putObject(uploadPath(U1, 0, id), 99);
  assertEquals((await call(be, { ...c, upload_id: id }, jwt)).body.error, "size_mismatch");
  assert(!be.objects.has(uploadPath(U1, 0, id)), "mismatched object is deleted");
  assertEquals((await call(be, { ...c, upload_id: id, summary: { day: 1, note: "text" } }, jwt)).body.error, "bad_summary");
});

Deno.test("cloud-save: a player can never point a commit at somebody else's object", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  const U2 = "22222222-2222-4222-8222-222222222222";
  const id = "0b5c2a3e-1111-4222-8333-444455556666";
  be.putObject(uploadPath(U2, 0, id), 1000);                       // object that belongs to player 2
  const r = await call(be, { action: "commit", app_version: "0.1.0", slot: 0, expected_version: 0, upload_id: id, size_bytes: 1000, sha256: SHA_A, summary }, jwt);
  assertEquals(r.body.error, "upload_missing");                    // the server looks under player 1's own folder only
});

Deno.test("cloud-save: kill switch and minimum version", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  await upload(be, jwt, U1, 0, 0, SHA_A);
  be.config = goodConfig({ kill_switches: { ...(goodConfig().kill_switches as object), cloud_sync: false } }); be.now += 100;
  const r = await call(be, { action: "list", app_version: "0.1.0" }, jwt);
  assertEquals(r.status, 503); assertEquals(r.body.error, "feature_disabled");
  assertEquals((await call(be, { action: "begin_upload", app_version: "0.1.0", slot: 0, expected_version: 1, size_bytes: 5, sha256: SHA_A }, jwt)).status, 503);
  const del = await call(be, { action: "delete", slot: 0 }, jwt);
  assertEquals(del.status, 200, "deleting your own data still works while sync is off");
  be.config = goodConfig({ min_app_version: "0.5.0" }); be.now += 100;
  assertEquals((await call(be, { action: "list", app_version: "0.4.9" }, jwt)).status, 426);
  assertEquals((await call(be, { action: "list", app_version: "0.5.0" }, jwt)).status, 200);
  assertEquals((await call(be, { action: "list" }, jwt)).status, 426, "missing app_version counts as too old");
});

Deno.test("cloud-save: a broken config fails OPEN (a database hiccup must not switch the game off)", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  be.config = { junk: true };
  assertEquals((await call(be, { action: "list", app_version: "0.1.0" }, jwt)).status, 200);
});

Deno.test("cloud-save: delete removes the object and the row; database errors give 500, not details", async () => {
  const be = new FakeBackend(); const jwt = be.addUser(U1);
  await upload(be, jwt, U1, 2, 0, SHA_A);
  const path = [...be.rows.values()][0].storage_path!;
  const d = await call(be, { action: "delete", slot: 2 }, jwt);
  assertEquals(d.body.deleted, true); assert(be.removed.includes(path));
  assertEquals((await call(be, { action: "delete", slot: 2 }, jwt)).body.deleted, false);
  be.failRpc = "cloud_save_list";
  const e = await call(be, { action: "list", app_version: "0.1.0" }, jwt);
  assertEquals(e.status, 500); assertEquals(e.body, { ok: false, error: "server_error" });
});

Deno.test("cloud-save: summary cleaning", () => {
  assertEquals(cleanSummary(summary), summary);
  assertEquals(cleanSummary({ day: 1.5 }), null);
  assertEquals(cleanSummary({ holes: 19 }), null);
  assertEquals(cleanSummary({ name: "x" }), null);
  assertEquals(cleanSummary("x"), null);
  assertEquals(cleanSummary({ app_version: "x" }), null);
  assertEquals(cleanSummary({}), {});
});
