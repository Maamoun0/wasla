// Health check for uptime monitors (NFR-3.1): is the database answering, and
// is Storage reachable? 200 when both are, 503 otherwise. The body names the
// failing check only, never an error message or a secret, and is not cached.

export type CheckName = "database" | "storage";

export interface HealthDeps {
  /** Resolves if the check passes; throws (or times out) otherwise. */
  check(name: CheckName): Promise<void>;
  now(): number;
  timeoutMs: number;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

async function timed(deps: HealthDeps, name: CheckName): Promise<{ ok: boolean; ms: number }> {
  const started = deps.now();
  let timer: number | undefined;
  try {
    await Promise.race([
      deps.check(name),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error("timeout")), deps.timeoutMs);
      }),
    ]);
    return { ok: true, ms: deps.now() - started };
  } catch {
    return { ok: false, ms: deps.now() - started };
  } finally {
    clearTimeout(timer);
  }
}

export async function handleHealth(req: Request, deps: HealthDeps): Promise<Response> {
  if (req.method !== "GET" && req.method !== "HEAD") return json({ error: "method not allowed" }, 405);
  const [database, storage] = await Promise.all([timed(deps, "database"), timed(deps, "storage")]);
  const ok = database.ok && storage.ok;
  return json({
    status: ok ? "ok" : "degraded",
    checks: {
      database: { ok: database.ok, latency_ms: database.ms },
      storage: { ok: storage.ok, latency_ms: storage.ms },
    },
  }, ok ? 200 : 503);
}
