// Tiny assertion helpers so the tests run with plain `deno test` and NO network (the std library lives on jsr.io,
// which some sandboxes block). Swap for `jsr:@std/assert` any time if you prefer.
export function assert(cond: unknown, msg = "assertion failed"): asserts cond {
  if (!cond) throw new Error(msg);
}

function canon(v: unknown): string {
  return JSON.stringify(v, (_k, x) =>
    x && typeof x === "object" && !Array.isArray(x)
      ? Object.fromEntries(Object.entries(x as Record<string, unknown>).sort(([a], [b]) => (a < b ? -1 : 1)))
      : x);
}

export function assertEquals(actual: unknown, expected: unknown, msg = ""): void {
  if (canon(actual) !== canon(expected)) {
    throw new Error(`${msg ? msg + ": " : ""}expected ${canon(expected)} but got ${canon(actual)}`);
  }
}

export function assertIncludes(haystack: string, needle: string, msg = ""): void {
  if (!haystack.includes(needle)) throw new Error(`${msg ? msg + ": " : ""}"${haystack}" does not include "${needle}"`);
}

export async function assertRejects(fn: () => Promise<unknown>, msg = "expected a rejection"): Promise<void> {
  try {
    await fn();
  } catch {
    return;
  }
  throw new Error(msg);
}
