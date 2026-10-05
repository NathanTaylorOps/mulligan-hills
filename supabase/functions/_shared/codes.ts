// Typed transfer codes: 12 characters from a 32 character alphabet (60 bits), shown as XXXX-XXXX-XXXX.
// The alphabet leaves out 0, 1, I and O so a code can be read aloud or typed from a screenshot.
// Only sha256("mhcode1|" + code) is stored.
import { sha256hex } from "./crypto.ts";

export const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 32 characters
export const CODE_LENGTH = 12;
export const CODE_TTL_SECONDS = 900;

/** randomBytes must hold at least CODE_LENGTH bytes. 256 is a multiple of 32, so masking is unbiased. */
export function codeFromBytes(randomBytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < CODE_LENGTH; i++) s += CODE_ALPHABET[randomBytes[i] & 31];
  return s;
}

export function formatCode(code: string): string {
  return `${code.slice(0, 4)}-${code.slice(4, 8)}-${code.slice(8, 12)}`;
}

/** Upper-case, drop spaces and dashes. Returns null when the result cannot be a code. */
export function normalizeCode(input: unknown): string | null {
  if (typeof input !== "string" || input.length > 40) return null;
  const s = input.toUpperCase().replace(/[\s-]/g, "");
  if (s.length !== CODE_LENGTH) return null;
  for (const ch of s) if (!CODE_ALPHABET.includes(ch)) return null;
  return s;
}

export async function hashCode(normalized: string): Promise<string> {
  return await sha256hex("mhcode1|" + normalized);
}
