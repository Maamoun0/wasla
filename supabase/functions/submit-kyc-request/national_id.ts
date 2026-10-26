// The national ID is never stored: only its last 4 digits and a keyed hash
// (HMAC-SHA256) used to detect the same ID on another account.

const MIN_SECRET_LENGTH = 32;

// Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits.
const NON_ASCII_DIGITS = /[٠-٩۰-۹]/g;

/** Removes all whitespace and maps Arabic digits to ASCII, so every way of typing an ID gives the same value. */
export function normalizeNationalId(raw: string): string {
  return raw
    .replace(/\s+/g, "")
    .replace(NON_ASCII_DIGITS, (d) => {
      const code = d.charCodeAt(0);
      return String(code - (code >= 0x06f0 ? 0x06f0 : 0x0660));
    });
}

/** Hex HMAC-SHA256 of an already-normalized ID. */
export async function nationalIdHmac(normalizedId: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(normalizedId));
  return Array.from(new Uint8Array(signature), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** The secret from KYC_NATIONAL_ID_HMAC_SECRET; refuses to run without a strong one. */
export function hmacSecretFrom(value: string | undefined): string {
  if (!value || value.length < MIN_SECRET_LENGTH) {
    throw new Error(`KYC_NATIONAL_ID_HMAC_SECRET must be set (at least ${MIN_SECRET_LENGTH} characters)`);
  }
  return value;
}
