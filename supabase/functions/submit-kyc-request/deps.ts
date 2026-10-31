import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { DuplicateNationalIdError, type SubmitKycDeps } from "./handler.ts";
import { nationalIdHmac } from "./national_id.ts";

// Identity documents live in the private bucket; only the service role writes them.
export const KYC_BUCKET = "id-documents";

export function supabaseDeps(supabase: SupabaseClient, hmacSecret: string): SubmitKycDeps {
  return {
    async authenticate(token) {
      const { data, error } = await supabase.auth.getUser(token);
      return error || !data.user ? null : data.user.id;
    },
      async accountBlocked(userId) {
        const { data, error } = await supabase.rpc("account_blocked", { p_user_id: userId });
        if (error) throw error;
        return data === true;
      },
      async setting(key, fallback) {
        const { data, error } = await supabase.rpc("app_setting_bool", { p_key: key, p_default: fallback });
        if (error) throw error;
        return data === true;
      },
    async hasPendingRequest(userId) {
      const { data, error } = await supabase.from("user_verifications").select("id")
        .eq("user_id", userId).eq("status", "pending").eq("type", "national_id");
      if (error) throw error;
      return (data ?? []).length > 0;
    },
    nationalIdHmac: (normalizedId) => nationalIdHmac(normalizedId, hmacSecret),
    async nationalIdInUse(hmac, userId) {
      const { data, error } = await supabase.from("user_verifications").select("id")
        .eq("national_id_hmac", hmac).in("status", ["pending", "approved"]).neq("user_id", userId).limit(1);
      if (error) throw error;
      return (data ?? []).length > 0;
    },
    async uploadDocument(path, bytes) {
      const { error } = await supabase.storage.from(KYC_BUCKET).upload(path, bytes, { contentType: "image/jpeg", upsert: true });
      if (error) throw new Error(`فشل رفع صورة البطاقة: ${error.message}`);
    },
    async createVerification(row) {
      const { error } = await supabase.from("user_verifications").insert({
        ...row,
        type: "national_id",
        status: "pending",
        expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      });
      // 23505: user_verifications_national_id_hmac_live (another live request holds the ID).
      if (error?.code === "23505") throw new DuplicateNationalIdError();
      if (error) throw new Error(`فشل إدراج طلب التحقق: ${error.message}`);
    },
    async removeDocuments(paths) {
      const { error } = await supabase.storage.from(KYC_BUCKET).remove(paths);
      if (error) throw error;
    },
    async updateFullName(userId, fullName) {
      const { error } = await supabase.from("users").update({ full_name: fullName }).eq("id", userId);
      if (error) throw new Error(`فشل تحديث الاسم: ${error.message}`);
    },
    now: () => Date.now(),
  };
}
