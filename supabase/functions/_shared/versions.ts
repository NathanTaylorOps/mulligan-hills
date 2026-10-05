// "1.2.3" style versions (min_app_version, app_version).
export function parseSemver(v: unknown): [number, number, number] | null {
  if (typeof v !== "string") return null;
  const m = /^(\d{1,6})\.(\d{1,6})\.(\d{1,6})$/.exec(v);
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}

/** true when a >= b. Unparseable input gives false. */
export function semverGte(a: unknown, b: unknown): boolean {
  const x = parseSemver(a), y = parseSemver(b);
  if (!x || !y) return false;
  for (let i = 0; i < 3; i++) {
    if (x[i] !== y[i]) return x[i] > y[i];
  }
  return true;
}
