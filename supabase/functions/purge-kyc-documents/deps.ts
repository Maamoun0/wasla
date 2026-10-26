import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import type { DueDocuments, PurgeKycDeps } from "./handler.ts";

export function supabaseDeps(supabase: SupabaseClient, serviceRoleKey: string): PurgeKycDeps {
  return {
    serviceRoleKey,
    async listDue(limit) {
      const { data, error } = await supabase.rpc("list_due_kyc_documents", { p_limit: limit });
      if (error) throw error;
      return (data ?? []) as DueDocuments[];
    },
    async removeFiles(paths) {
      const { error } = await supabase.storage.from("id-documents").remove(paths);
      if (error) throw error;
    },
    async markDeleted(verificationId) {
      const { error } = await supabase.rpc("mark_kyc_documents_deleted", { p_verification_id: verificationId });
      if (error) throw error;
    },
  };
}
