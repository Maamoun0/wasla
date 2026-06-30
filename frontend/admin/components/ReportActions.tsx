'use client';

import { useState } from 'react';
import { handleReportAction } from '@/app/dashboard/reports/actions';
import { CheckCircle2, XCircle, Loader2 } from 'lucide-react';

export default function ReportActions({ reportId }: { reportId: string }) {
  const [loading, setLoading] = useState(false);

  const handleAction = async (status: 'resolved' | 'dismissed') => {
    const confirmMsg = status === 'resolved' 
      ? 'هل تم حل مشكلة هذا البلاغ؟' 
      : 'هل تريد تجاهل هذا البلاغ لعدم جديته؟';
    
    if (!confirm(confirmMsg)) return;

    setLoading(true);
    const result = await handleReportAction(reportId, status);
    if (!result.success) {
      alert(result.error);
    }
    setLoading(false);
  };

  return (
    <div className="flex items-center gap-2">
      <button
        onClick={() => handleAction('resolved')}
        disabled={loading}
        className="flex items-center gap-1 bg-green-50 text-green-700 hover:bg-green-100 px-3 py-1.5 rounded-lg border border-green-200 font-cairo text-xs font-bold transition-colors"
      >
        {loading ? <Loader2 size={14} className="animate-spin" /> : <CheckCircle2 size={14} />}
        <span>حلّ</span>
      </button>
      <button
        onClick={() => handleAction('dismissed')}
        disabled={loading}
        className="flex items-center gap-1 bg-gray-50 text-gray-600 hover:bg-gray-100 px-3 py-1.5 rounded-lg border border-gray-200 font-cairo text-xs font-bold transition-colors"
      >
        <XCircle size={14} />
        <span>تجاهل</span>
      </button>
    </div>
  );
}
