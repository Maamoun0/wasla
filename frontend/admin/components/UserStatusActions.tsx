'use client';

import { useState } from 'react';
import { updateUserStatusAction } from '@/app/dashboard/users/actions';
import { ShieldAlert, Ban, CheckCircle, Loader2 } from 'lucide-react';

interface Props {
  userId: string;
  currentStatus: string;
}

export default function UserStatusActions({ userId, currentStatus }: Props) {
  const [loading, setLoading] = useState(false);

  const handleStatusUpdate = async (newStatus: 'active' | 'suspended' | 'banned') => {
    let confirmMsg = '';
    switch (newStatus) {
      case 'suspended': confirmMsg = 'هل أنت متأكد من تعليق هذا الحساب؟ سيتم تسجيل خروج المستخدم فوراً.'; break;
      case 'banned': confirmMsg = '⚠️ حظر دائم؟ هذا الإجراء سيمنع المستخدم من الدخول نهائياً.'; break;
      case 'active': confirmMsg = 'هل تريد إعادة تفعيل الحساب؟'; break;
    }

    if (!confirm(confirmMsg)) return;

    setLoading(true);
    const result = await updateUserStatusAction(userId, newStatus);
    if (!result.success) {
      alert(result.error);
    }
    setLoading(false);
  };

  if (currentStatus === 'suspended' || currentStatus === 'banned') {
    return (
      <button
        onClick={() => handleStatusUpdate('active')}
        disabled={loading}
        className="w-full py-2 bg-green-600 text-white rounded-lg text-sm font-bold font-cairo hover:bg-green-700 transition-colors flex items-center justify-center gap-2"
      >
        {loading ? <Loader2 size={16} className="animate-spin" /> : <CheckCircle size={16} />}
        رفع الحظر / التفعيل
      </button>
    );
  }

  return (
    <div className="space-y-3">
      <button
        onClick={() => handleStatusUpdate('suspended')}
        disabled={loading}
        className="w-full py-2 bg-orange-600 text-white rounded-lg text-sm font-bold font-cairo hover:bg-orange-700 transition-colors flex items-center justify-center gap-2"
      >
        {loading ? <Loader2 size={16} className="animate-spin" /> : <ShieldAlert size={16} />}
        تعليق الحساب (Suspension)
      </button>
      <button
        onClick={() => handleStatusUpdate('banned')}
        disabled={loading}
        className="w-full py-2 bg-red-600 text-white rounded-lg text-sm font-bold font-cairo hover:bg-red-700 transition-colors flex items-center justify-center gap-2"
      >
        {loading ? <Loader2 size={16} className="animate-spin" /> : <Ban size={16} />}
        حظر دائم (Permanent Ban)
      </button>
    </div>
  );
}
