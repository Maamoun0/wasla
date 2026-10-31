'use server';

import { createAdminClient } from '@/lib/supabase/server';
import { getStaff, UNAUTHORIZED } from '@/lib/auth';
import { revalidatePath } from 'next/cache';

/**
 * What an admin may change on a payment package. The kind, boost type, plan
 * and duration stay fixed: create-payment prices from this table and
 * fulfill_payment reads the duration at payment time, so changing them would
 * change what people already paying receive. A price change is safe for
 * payments in progress: they are checked against the amount stored on their
 * transaction.
 */
export interface PackageChanges {
  price_egp?: number;
  name_ar?: string;
  is_active?: boolean;
  sort_order?: number;
}

const MAX_PRICE_EGP = 100_000;

export async function validatePackageChanges(changes: unknown): Promise<{ ok: true; values: PackageChanges } | { ok: false; error: string }> {
  if (!changes || typeof changes !== 'object' || Array.isArray(changes)) return { ok: false, error: 'تعديلات غير صالحة' };
  const allowed = new Set(['price_egp', 'name_ar', 'is_active', 'sort_order']);
  const entries = Object.entries(changes as Record<string, unknown>);
  if (entries.length === 0) return { ok: false, error: 'لا توجد تعديلات' };
  if (entries.some(([k]) => !allowed.has(k))) return { ok: false, error: 'لا يمكن تعديل هذا الحقل' };

  const values: PackageChanges = {};
  const c = changes as Record<string, unknown>;
  if ('price_egp' in c) {
    const price = c.price_egp;
    if (typeof price !== 'number' || !Number.isFinite(price) || price <= 0 || price > MAX_PRICE_EGP
        || Math.round(price * 100) !== price * 100) {
      return { ok: false, error: `السعر لازم يكون رقم أكبر من صفر، بحد أقصى قرشين عشريين و${MAX_PRICE_EGP} جنيه` };
    }
    values.price_egp = price;
  }
  if ('name_ar' in c) {
    const name = typeof c.name_ar === 'string' ? c.name_ar.trim() : '';
    if (name.length < 2 || name.length > 100) return { ok: false, error: 'الاسم من 2 لـ 100 حرف' };
    values.name_ar = name;
  }
  if ('is_active' in c) {
    if (typeof c.is_active !== 'boolean') return { ok: false, error: 'قيمة التفعيل غير صالحة' };
    values.is_active = c.is_active;
  }
  if ('sort_order' in c) {
    if (!Number.isInteger(c.sort_order) || (c.sort_order as number) < 0 || (c.sort_order as number) > 32767) {
      return { ok: false, error: 'الترتيب رقم صحيح من 0 لـ 32767' };
    }
    values.sort_order = c.sort_order as number;
  }
  return { ok: true, values };
}

// Prices are admin-only.
export async function updatePackageAction(id: string, changes: unknown) {
  const staff = await getStaff(['admin']);
  if (!staff) return UNAUTHORIZED;
  if (typeof id !== 'string' || !id.trim()) return { success: false, error: 'باقة غير صالحة' };

  const checked = await validatePackageChanges(changes);
  if (!checked.ok) return { success: false, error: checked.error };

  const supabase = createAdminClient();
  const { data: before } = await supabase
    .from('payment_packages')
    .select('id, name_ar, price_egp, is_active, sort_order')
    .eq('id', id)
    .maybeSingle();
  if (!before) return { success: false, error: 'الباقة غير موجودة' };

  const { error } = await supabase
    .from('payment_packages')
    .update({ ...checked.values, updated_at: new Date().toISOString() })
    .eq('id', id);
  if (error) {
    console.error('updatePackageAction failed:', error.code);
    return { success: false, error: 'حدث خطأ أثناء حفظ الباقة' };
  }

  await supabase.from('audit_logs').insert({
    actor_id: staff.id,
    action: 'update_payment_package',
    target_type: 'payment_package',
    changes: { id, before, after: checked.values },
  });

  revalidatePath('/dashboard/packages');
  return { success: true };
}
