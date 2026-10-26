'use client';

import { useState } from 'react';
import { getKycDocumentUrl, type KycDocumentSide } from '@/app/dashboard/kyc/actions';
import { Eye, X } from 'lucide-react';

export default function KYCImagePreview({
  verificationId,
  side,
  label,
}: {
  verificationId: string;
  side: KycDocumentSide;
  label: string;
}) {
  const [url, setUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [showModal, setShowModal] = useState(false);

  const handlePreview = async () => {
    setLoading(true);
    const result = await getKycDocumentUrl(verificationId, side);
    if (result.success) {
      setUrl(result.url);
      setShowModal(true);
    } else {
      alert(result.error);
    }
    setLoading(false);
  };

  return (
    <>
      <button
        onClick={handlePreview}
        disabled={loading}
        className="text-xs flex items-center space-x-1 space-x-reverse bg-gray-100 hover:bg-gray-200 px-2 py-1 rounded transition-colors"
      >
        <Eye size={12} />
        <span>{loading ? 'جاري التحميل...' : label}</span>
      </button>

      {showModal && url && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
          <div className="relative bg-white rounded-xl overflow-hidden max-w-4xl w-full max-h-[90vh] flex flex-col">
            <div className="p-4 border-b flex justify-between items-center">
              <h3 className="font-cairo font-bold">{label}</h3>
              <button onClick={() => setShowModal(false)} className="text-gray-500 hover:text-black">
                <X size={24} />
              </button>
            </div>
            <div className="flex-1 overflow-auto p-4 flex justify-center bg-gray-100">
              <img 
                src={url} 
                alt={label} 
                className="max-w-full h-auto shadow-lg"
                onContextMenu={(e) => e.preventDefault()} // Basic protection
              />
            </div>
            <div className="p-4 bg-yellow-50 text-yellow-800 text-xs font-cairo text-center">
              رابط الصورة مؤقت وسينتهي خلال 5 دقائق. يمنع تداول هذه الصور خارج إطار العمل.
            </div>
          </div>
        </div>
      )}
    </>
  );
}
