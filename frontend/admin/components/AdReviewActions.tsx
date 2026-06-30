'use client';

import { useState } from 'react';
import { Check, X, Eye, Loader2 } from 'lucide-react';
import { moderateAdAction } from '@/app/dashboard/ads/actions';

interface Props {
  adId: string;
  adTitle: string;
}

export default function AdReviewActions({ adId, adTitle }: Props) {
  const [loading, setLoading] = useState(false);
  const [showRejectInput, setShowRejectInput] = useState(false);
  const [reason, setReason] = useState('');

  const handleApprove = async () => {
    if (!confirm(`هل أنت متأكد من قبول الإعلان: ${adTitle}؟`)) return;
    
    setLoading(true);
    const result = await moderateAdAction(adId, 'approved');
    if (!result.success) {
      alert(result.error);
    }
    setLoading(false);
  };

  const handleReject = async () => {
    if (!reason.trim()) {
      alert('يرجى كتابة سبب الرفض');
      return;
    }
    
    setLoading(true);
    const result = await moderateAdAction(adId, 'rejected', reason);
    if (!result.success) {
      alert(result.error);
    }
    setLoading(false);
    setShowRejectInput(false);
  };

  if (showRejectInput) {
    return (
      <div className="flex flex-col space-y-2 min-w-[200px]">
        <textarea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="سبب الرفض..."
          className="text-xs p-2 border border-red-200 rounded-lg focus:ring-1 focus:ring-red-500 outline-none font-cairo"
          rows={2}
        />
        <div className="flex space-x-2 space-x-reverse">
          <button
            onClick={handleReject}
            disabled={loading}
            className="flex-1 bg-red-600 text-white text-xs py-1 rounded-md font-cairo hover:bg-red-700 disabled:opacity-50"
          >
            تأكيد الرفض
          </button>
          <button
            onClick={() => setShowRejectInput(false)}
            className="flex-1 bg-gray-100 text-gray-600 text-xs py-1 rounded-md font-cairo hover:bg-gray-200"
          >
            إلغاء
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center space-x-2 space-x-reverse">
      <button 
        className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors" 
        title="عرض التفاصيل"
      >
        <Eye size={18} />
      </button>
      
      <button 
        onClick={handleApprove}
        disabled={loading}
        className="p-2 text-green-600 hover:bg-green-50 rounded-lg transition-colors disabled:opacity-50" 
        title="قبول"
      >
        {loading ? <Loader2 size={18} className="animate-spin" /> : <Check size={18} />}
      </button>
      
      <button 
        onClick={() => setShowRejectInput(true)}
        disabled={loading}
        className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50" 
        title="رفض"
      >
        <X size={18} />
      </button>
    </div>
  );
}
