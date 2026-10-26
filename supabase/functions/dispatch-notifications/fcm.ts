// Firebase Cloud Messaging HTTP v1 client.
// Authenticates with a service account (OAuth2 JWT bearer grant, RS256
// signed with Web Crypto) and sends one message per device token.

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export type SendResult =
  | { kind: "sent" }
  | { kind: "invalid_token" }
  | { kind: "error"; message: string };

type Fetch = typeof fetch;

const SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";

function base64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let bin = "";
  for (const b of raw) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem: string): Uint8Array {
  const b64 = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

export async function createSignedJwt(sa: ServiceAccount, nowSeconds: number): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope: SCOPE,
    aud: sa.token_uri ?? DEFAULT_TOKEN_URI,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  return `${unsigned}.${base64url(new Uint8Array(sig))}`;
}

export class FcmClient {
  private accessToken: string | null = null;
  private expiresAt = 0;

  constructor(
    private readonly sa: ServiceAccount,
    private readonly fetchFn: Fetch = fetch,
    private readonly now: () => number = () => Date.now(),
  ) {}

  async getAccessToken(): Promise<string> {
    if (this.accessToken && this.now() < this.expiresAt - 60_000) return this.accessToken;
    const assertion = await createSignedJwt(this.sa, Math.floor(this.now() / 1000));
    const res = await this.fetchFn(this.sa.token_uri ?? DEFAULT_TOKEN_URI, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
    });
    if (!res.ok) throw new Error(`OAuth token request failed: ${res.status}`);
    const body = await res.json() as { access_token: string; expires_in: number };
    this.accessToken = body.access_token;
    this.expiresAt = this.now() + body.expires_in * 1000;
    return this.accessToken;
  }

  async send(token: string, title: string, body: string, data: Record<string, unknown>): Promise<SendResult> {
    const accessToken = await this.getAccessToken();
    // FCM data values must be strings.
    const stringData = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]));
    const res = await this.fetchFn(`https://fcm.googleapis.com/v1/projects/${this.sa.project_id}/messages:send`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: stringData,
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
    });
    if (res.ok) return { kind: "sent" };

    const payload = await res.json().catch(() => ({})) as {
      error?: { status?: string; details?: { errorCode?: string }[] };
    };
    const codes = (payload.error?.details ?? []).map((d) => d.errorCode);
    if (res.status === 404 || codes.includes("UNREGISTERED")) return { kind: "invalid_token" };
    return { kind: "error", message: `FCM ${res.status} ${payload.error?.status ?? ""}`.trim() };
  }
}
