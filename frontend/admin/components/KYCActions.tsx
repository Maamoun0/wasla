'use client';

import { useState } from 'react';
import { moderateKYCAction } from '@/app/dashboard/kyc/actions';
import { Check, X, Loader2 } from 'lucide-react';

export default function KYCActions({ verificationId, userName }: { verificationId: string, userName: string }) {
  const [loading, setLoading] = useState(false);
  const [showReject, setShowReject] = useState(false);
  const [reason, setReason] = useState('');

  const handleApprove = async () => {
    if (!confirm(`هل أنت متأكد من توثيق حساب: ${userName}؟`)) return;
    setLoading(true);
    const result = await moderateKYCAction(verificationId, 'approved');
    if (!result.success) alert(result.error);
    setLoading(false);
  };

  const handleReject = async () => {
    if (!reason.trim()) {
      alert('يرجى ذكر سبب الرفض');
      return;
    }
    setLoading(true);
    const result = await moderateKYCAction(verificationId, 'rejected', reason);
    if (!result.success) alert(result.error);
    setLoading(false);
    setShowReject(false);
  };

  if (showReject) {
    return (
      <div className="flex flex-col space-y-2 min-w-[150px]">
        <input 
          type="text" 
          placeholder="سبب الرفض..." 
          className="text-xs p-2 border rounded font-cairo"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />
        <div className="flex space-x-1 space-x-reverse">
          <button onClick={handleReject} disabled={loading} className="flex-1 bg-red-600 text-white text-[10px] py-1 rounded">تأكيد</button>
          <button onClick={() => setShowReject(false)} className="flex-1 bg-gray-200 text-gray-600 text-[10px] py-1 rounded">إلغاء</button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex space-x-2 space-x-reverse">
      <button
        onClick={handleApprove}
        disabled={loading}
        className="flex items-center space-x-1 space-x-reverse bg-green-50 text-green-700 hover:bg-green-100 px-3 py-1.5 rounded-lg transition-colors border border-green-200 font-cairo text-xs font-bold"
      >
        {loading ? <Loader2 size={14} className="animate-spin" /> : <Check size={14} />}
        <span>توثيق</span>
      </button>
      <button
        onClick={() => setShowReject(true)}
        disabled={loading}
        className="flex items-center space-x-1 space-x-reverse bg-red-50 text-red-700 hover:bg-red-100 px-3 py-1.5 rounded-lg transition-colors border border-red-200 font-cairo text-xs font-bold"
      >
        <X size={14} />
        <span>رفض</span>
      </button>
    </div>
  );
}
