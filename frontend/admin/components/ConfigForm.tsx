'use client';

import { useState } from 'react';
import { updateConfigAction } from '@/app/dashboard/settings/actions';
import { Save, Loader2, CheckCircle } from 'lucide-react';

interface Props {
  configKey: string;
  label: string;
  initialValue: any;
  type: 'number' | 'text' | 'boolean';
}

export default function ConfigForm({ configKey, label, initialValue, type }: Props) {
  const [value, setValue] = useState(initialValue);
  const [loading, setLoading] = useState(false);
  const [saved, setSaved] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setSaved(false);

    const result = await updateConfigAction(configKey, type === 'number' ? Number(value) : value);
    
    if (result.success) {
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } else {
      alert(result.error);
    }
    setLoading(false);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-2">
      <label className="block text-xs font-bold font-cairo text-gray-600">{label}</label>
      <div className="flex gap-2">
        {type === 'boolean' ? (
          <select 
            value={value.toString()} 
            onChange={(e) => setValue(e.target.value === 'true')}
            className="flex-1 bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 text-sm font-cairo"
          >
            <option value="true">مفعّل</option>
            <option value="false">معطّل</option>
          </select>
        ) : (
          <input
            type={type}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            className="flex-1 bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 text-sm font-cairo"
          />
        )}
        <button
          type="submit"
          disabled={loading}
          className={`px-4 py-2 rounded-lg flex items-center gap-2 transition-all ${
            saved ? 'bg-green-600 text-white' : 'bg-blue-600 text-white hover:bg-blue-700'
          }`}
        >
          {loading ? <Loader2 size={16} className="animate-spin" /> : saved ? <CheckCircle size={16} /> : <Save size={16} />}
          <span className="text-xs font-cairo">{saved ? 'تم الحفظ' : 'حفظ'}</span>
        </button>
      </div>
    </form>
  );
}
