// Purges accounts whose deletion request is 30 days old: removes the
// user's files through the Storage API, deletes the auth user through the
// Auth API (public data cascades from it), then closes the request.
// A failure leaves the request pending, so the next daily run retries.

export const USER_BUCKETS = ["ads", "avatars", "id-documents"] as const;

export interface DueDeletion {
  request_id: string;
  user_id: string;
}

export interface PurgeDeps {
  serviceRoleKey: string;
  listDue(limit: number): Promise<DueDeletion[]>;
  /** Removes every object under `{userId}/` in the bucket; returns how many. */
  removeUserFiles(bucket: string, userId: string): Promise<number>;
  deleteAuthUser(userId: string): Promise<void>;
  complete(requestId: string): Promise<void>;
}

const BATCH_SIZE = 25;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

export async function purgeOne(d: DueDeletion, deps: PurgeDeps): Promise<number> {
  let files = 0;
  for (const bucket of USER_BUCKETS) files += await deps.removeUserFiles(bucket, d.user_id);
  await deps.deleteAuthUser(d.user_id);
  await deps.complete(d.request_id);
  return files;
}

export async function handlePurge(req: Request, deps: PurgeDeps): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method Not Allowed" }, 405);
  if (req.headers.get("Authorization") !== `Bearer ${deps.serviceRoleKey}`) {
    return json({ error: "unauthorized" }, 401);
  }

  const due = await deps.listDue(BATCH_SIZE);
  const summary = { due: due.length, purged: 0, failed: 0, files_removed: 0 };
  for (const d of due) {
    try {
      summary.files_removed += await purgeOne(d, deps);
      summary.purged++;
    } catch (err) {
      // Log the request id only; no personal data.
      console.error(`purge-deleted-accounts: request ${d.request_id} failed:`, err instanceof Error ? err.message : err);
      summary.failed++;
    }
  }
  console.info("purge-deleted-accounts:", JSON.stringify(summary));
  return json(summary, 200);
}
