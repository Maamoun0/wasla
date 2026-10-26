import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import type { ClaimedNotification, DispatchDeps } from "./handler.ts";

// Wires the dispatcher to the claim_notifications / complete_notification RPCs.
export function supabaseDeps(
  supabase: SupabaseClient,
  serviceRoleKey: string,
  send: DispatchDeps["send"],
): DispatchDeps {
  return {
    serviceRoleKey,
    async claim(limit) {
      const { data, error } = await supabase.rpc("claim_notifications", { p_limit: limit });
      if (error) throw error;
      return (data ?? []) as ClaimedNotification[];
    },
    send,
    async complete(id, status, error, invalidTokens) {
      const { error: rpcError } = await supabase.rpc("complete_notification", {
        p_id: id,
        p_status: status,
        p_error: error,
        p_invalid_tokens: invalidTokens,
      });
      if (rpcError) throw rpcError;
    },
  };
}
