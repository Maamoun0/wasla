// Deletes identity documents once they are no longer needed: 7 days after an
// approval, 30 days after a rejection (appeal window). Files are removed
// through the Storage API; the verification row (the decision) is kept with
// its paths cleared. A failure leaves the row due, so the next run retries.

export interface DueDocuments {
  verification_id: string;
  paths: string[];
}

export interface PurgeKycDeps {
  serviceRoleKey: string;
  listDue(limit: number): Promise<DueDocuments[]>;
  removeFiles(paths: string[]): Promise<void>;
  markDeleted(verificationId: string): Promise<void>;
}

const BATCH_SIZE = 100;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

export async function handlePurgeKyc(req: Request, deps: PurgeKycDeps): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method Not Allowed" }, 405);
  if (req.headers.get("Authorization") !== `Bearer ${deps.serviceRoleKey}`) {
    return json({ error: "unauthorized" }, 401);
  }

  const due = await deps.listDue(BATCH_SIZE);
  const summary = { due: due.length, purged: 0, failed: 0, files_removed: 0 };
  for (const d of due) {
    try {
      await deps.removeFiles(d.paths);
      await deps.markDeleted(d.verification_id);
      summary.purged++;
      summary.files_removed += d.paths.length;
    } catch (err) {
      console.error(`purge-kyc-documents: ${d.verification_id} failed:`, err instanceof Error ? err.message : err);
      summary.failed++;
    }
  }
  console.info("purge-kyc-documents:", JSON.stringify(summary));
  return json(summary, 200);
}
