import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import type { DueDeletion, PurgeDeps } from "./handler.ts";

const PAGE = 100;

// Lists every object path under a prefix, descending into folders
// (Storage list() returns folders as entries without an id).
async function listAll(supabase: SupabaseClient, bucket: string, prefix: string): Promise<string[]> {
  const paths: string[] = [];
  for (let offset = 0; ; offset += PAGE) {
    const { data, error } = await supabase.storage.from(bucket).list(prefix, { limit: PAGE, offset });
    if (error) throw error;
    for (const entry of data ?? []) {
      const path = `${prefix}/${entry.name}`;
      if (entry.id) paths.push(path);
      else paths.push(...await listAll(supabase, bucket, path));
    }
    if (!data || data.length < PAGE) return paths;
  }
}

export function supabaseDeps(supabase: SupabaseClient, serviceRoleKey: string): PurgeDeps {
  return {
    serviceRoleKey,
    async listDue(limit) {
      const { data, error } = await supabase.rpc("list_due_account_deletions", { p_limit: limit });
      if (error) throw error;
      return (data ?? []) as DueDeletion[];
    },
    async removeUserFiles(bucket, userId) {
      const paths = await listAll(supabase, bucket, userId);
      for (let i = 0; i < paths.length; i += PAGE) {
        const { error } = await supabase.storage.from(bucket).remove(paths.slice(i, i + PAGE));
        if (error) throw error;
      }
      return paths.length;
    },
    async deleteAuthUser(userId) {
      const { error } = await supabase.auth.admin.deleteUser(userId);
      if (error && error.status !== 404) throw error;
    },
    async complete(requestId) {
      const { error } = await supabase.rpc("complete_account_deletion", { p_request_id: requestId });
      if (error) throw error;
    },
  };
}
