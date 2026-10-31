'use client';

import { useState } from 'react';
import { Loader2, Save } from 'lucide-react';
import { updatePackageAction } from '@/app/dashboard/packages/actions';

interface Pkg {
  id: string;
  name_ar: string;
  price_egp: number;
  duration_days: number;
  is_active: boolean;
  sort_order: number;
}

export default function PackageRow({ pkg }: { pkg: Pkg }) {
  const [name, setName] = useState(pkg.name_ar);
  const [price, setPrice] = useState(String(pkg.price_egp));
  const [sortOrder, setSortOrder] = useState(String(pkg.sort_order));
  const [active, setActive] = useState(pkg.is_active);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  const changes = {
    ...(name.trim() !== pkg.name_ar ? { name_ar: name } : {}),
    ...(Number(price) !== pkg.price_egp ? { price_egp: Number(price) } : {}),
    ...(Number(sortOrder) !== pkg.sort_order ? { sort_order: Number(sortOrder) } : {}),
    ...(active !== pkg.is_active ? { is_active: active } : {}),
  };
  const dirty = Object.keys(changes).length > 0;

  const save = async () => {
    if (changes.price_egp !== undefined
        && !window.confirm(`تغيير سعر "${pkg.name_ar}" من ${pkg.price_egp} إلى ${changes.price_egp} ج.م؟`)) {
      return;
    }
    setSaving(true);
    setMessage(null);
    const result = await updatePackageAction(pkg.id, changes);
    setSaving(false);
    setMessage(result.success ? { ok: true, text: 'تم الحفظ' } : { ok: false, text: result.error ?? 'تعذّر الحفظ' });
  };

  const input = 'bg-gray-50 border border-gray-200 rounded-lg px-2 py-1 text-sm font-cairo';
  return (
    <tr className="text-sm font-cairo">
      <td className="px-6 py-3">
        <input className={`${input} w-56`} value={name} onChange={(e) => setName(e.target.value)} aria-label="اسم الباقة" />
      </td>
      <td className="px-6 py-3 text-gray-500">{pkg.duration_days > 0 ? `${pkg.duration_days} يوم` : '—'}</td>
      <td className="px-6 py-3">
        <input className={`${input} w-28`} type="number" min="0.01" step="0.01" value={price}
          onChange={(e) => setPrice(e.target.value)} aria-label="السعر" />
      </td>
      <td className="px-6 py-3">
        <input className={`${input} w-20`} type="number" min="0" step="1" value={sortOrder}
          onChange={(e) => setSortOrder(e.target.value)} aria-label="الترتيب" />
      </td>
      <td className="px-6 py-3">
        <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} aria-label="مفعّلة" />
      </td>
      <td className="px-6 py-3">
        <div className="flex items-center gap-2">
          <button
            onClick={save}
            disabled={!dirty || saving}
            className="px-3 py-1 rounded-lg bg-blue-600 text-white disabled:opacity-40 flex items-center gap-1"
          >
            {saving ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
            <span>حفظ</span>
          </button>
          {message && <span className={message.ok ? 'text-green-600' : 'text-red-600'}>{message.text}</span>}
        </div>
      </td>
    </tr>
  );
}
