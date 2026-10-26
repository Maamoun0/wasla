// Drains notifications_outbox: claim a batch, push to every active device
// token of each user, and report each row back.

export interface ClaimedNotification {
  id: string;
  user_id: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  attempts: number;
  tokens: string[];
}

export type Outcome = "sent" | "skipped" | "failed";

export interface DispatchDeps {
  serviceRoleKey: string;
  claim(limit: number): Promise<ClaimedNotification[]>;
  send(token: string, n: ClaimedNotification): Promise<
    { kind: "sent" } | { kind: "invalid_token" } | { kind: "error"; message: string }
  >;
  complete(id: string, status: Outcome, error: string | null, invalidTokens: string[]): Promise<void>;
}

const BATCH_SIZE = 50;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

export async function dispatchOne(n: ClaimedNotification, deps: DispatchDeps): Promise<Outcome> {
  if (n.tokens.length === 0) {
    await deps.complete(n.id, "skipped", "no active device tokens", []);
    return "skipped";
  }

  const invalid: string[] = [];
  const errors: string[] = [];
  let delivered = 0;
  for (const token of n.tokens) {
    const r = await deps.send(token, n);
    if (r.kind === "sent") delivered++;
    else if (r.kind === "invalid_token") invalid.push(token);
    else errors.push(r.message);
  }

  if (delivered > 0) {
    await deps.complete(n.id, "sent", errors[0] ?? null, invalid);
    return "sent";
  }
  if (errors.length === 0) {
    await deps.complete(n.id, "skipped", "all device tokens are unregistered", invalid);
    return "skipped";
  }
  await deps.complete(n.id, "failed", errors[0], invalid);
  return "failed";
}

export async function handleDispatch(req: Request, deps: DispatchDeps): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method Not Allowed" }, 405);
  // Only the cron tick (or an operator) holding the service-role key may drain the queue.
  if (req.headers.get("Authorization") !== `Bearer ${deps.serviceRoleKey}`) {
    return json({ error: "unauthorized" }, 401);
  }

  const batch = await deps.claim(BATCH_SIZE);
  const summary = { claimed: batch.length, sent: 0, skipped: 0, failed: 0 };
  for (const n of batch) {
    try {
      summary[await dispatchOne(n, deps)]++;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await deps.complete(n.id, "failed", message, []);
      summary.failed++;
    }
  }
  console.info("dispatch-notifications:", JSON.stringify(summary));
  return json(summary, 200);
}
