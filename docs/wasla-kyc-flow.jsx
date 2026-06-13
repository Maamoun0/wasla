import React, { useState } from 'react';
import { Camera, UploadCloud, CheckCircle, Shield, AlertTriangle, ArrowRight, UserCheck, ChevronRight } from 'lucide-react';

// Wasla Brand Colors
const C = {
  p50: '#F0F9FF', p500: '#0EA5E9', p600: '#0284C7', p900: '#0C4A6E',
  a500: '#F59E0B',
  dark: '#0F172A',
  gray: '#64748B',
  lightGray: '#F8FAFC',
  success: '#10B981',
};

const KycFlowPrototype = () => {
  const [step, setStep] = useState(1);

  const nextStep = () => setStep(step < 4 ? step + 1 : 4);
  const resetFlow = () => setStep(1);

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-slate-100 p-6 font-sans dir-rtl">
      {/* Mobile Device Mockup */}
      <div className="w-full max-w-sm bg-white rounded-[40px] shadow-2xl overflow-hidden border-8 border-slate-800 h-[800px] flex flex-col relative">
        
        {/* Status Bar Mock */}
        <div className="bg-slate-800 text-white text-xs px-6 py-2 flex justify-between items-center">
          <span>9:41</span>
          <div className="flex gap-1">
            <span className="w-4 h-4 rounded-full border border-white"></span>
          </div>
        </div>

        {/* Header */}
        <div className="p-6 pb-2" style={{ backgroundColor: C.p50 }}>
          <div className="flex items-center gap-2 mb-4">
            <Shield size={28} color={C.p600} />
            <h1 className="text-xl font-bold" style={{ color: C.p900, fontFamily: 'Cairo, sans-serif' }}>
              وصلة - التوثيق الأمني
            </h1>
          </div>
          
          {/* Progress Bar */}
          <div className="flex gap-2 mb-4">
            {[1, 2, 3].map((i) => (
              <div 
                key={i} 
                className={`h-2 flex-1 rounded-full ${step >= i ? 'bg-blue-600' : 'bg-blue-200'}`}
                style={{ backgroundColor: step >= i ? C.p600 : C.p100 }}
              />
            ))}
          </div>
        </div>

        {/* Dynamic Screens */}
        <div className="flex-1 p-6 overflow-y-auto">
          
          {/* STEP 1: Intro & Selection */}
          {step === 1 && (
            <div className="animate-fade-in text-right">
              <h2 className="text-2xl font-bold mb-2" style={{ color: C.dark }}>تأكيد الهوية (KYC)</h2>
              <p className="text-sm mb-8" style={{ color: C.gray }}>
                لحماية مجتمع وصلة، نطلب من مُقدمي الخدمات ومؤجري السكن توثيق هويتهم رسمياً. لن يتم مشاركة بياناتك علناً.
              </p>

              <div className="space-y-4">
                <div className="p-4 rounded-xl border-2 border-blue-100 bg-blue-50 relative cursor-pointer hover:border-blue-500 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="p-3 bg-white rounded-lg text-blue-600">
                      <Camera size={24} />
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-800">صورة البطاقة</h3>
                      <p className="text-xs text-gray-500">وجه وظهر البطاقة القومية</p>
                    </div>
                  </div>
                </div>

                <div className="p-4 rounded-xl border-2 border-slate-100 bg-slate-50 relative">
                  <div className="flex items-center gap-3">
                    <div className="p-3 bg-white rounded-lg text-slate-400">
                      <UserCheck size={24} />
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-400">صورة سيلفي</h3>
                      <p className="text-xs text-gray-400">للمطابقة مع صورة البطاقة</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* STEP 2: ID Upload */}
          {step === 2 && (
            <div className="animate-fade-in text-right">
              <h2 className="text-2xl font-bold mb-2" style={{ color: C.dark }}>تصوير البطاقة</h2>
              <p className="text-sm mb-6" style={{ color: C.gray }}>
                يرجى تصوير بطاقة الرقم القومي الحالية والمطابقة لبياناتك.
              </p>

              <div className="bg-slate-100 border-2 border-dashed border-slate-300 rounded-2xl h-48 flex flex-col items-center justify-center mb-4 cursor-pointer hover:bg-slate-200">
                <Camera size={40} color={C.gray} className="mb-2" />
                <span className="font-bold text-slate-600">التقط صورة الوجه الأمامي</span>
              </div>

              <div className="bg-slate-50 border-2 border-dashed border-slate-200 rounded-2xl h-32 flex flex-col items-center justify-center cursor-pointer opacity-50">
                <UploadCloud size={30} color={C.gray} className="mb-2" />
                <span className="text-sm text-slate-500">الوجه الخلفي (مغلق حالياً)</span>
              </div>
              
              <div className="mt-4 flex items-start gap-2 p-3 bg-amber-50 rounded-lg border border-amber-200">
                <AlertTriangle size={20} color={C.a500} className="shrink-0 mt-0.5" />
                <p className="text-xs text-amber-800 font-medium">يجب أن تكون الصورة واضحة والبيانات مقروءة، ولا يُسمح برفع صور من المعرض.</p>
              </div>
            </div>
          )}

          {/* STEP 3: Selfie Verification */}
          {step === 3 && (
            <div className="animate-fade-in text-right">
              <h2 className="text-2xl font-bold mb-2" style={{ color: C.dark }}>صورة سيلفي</h2>
              <p className="text-sm mb-6" style={{ color: C.gray }}>
                خطوة أخيرة للمطابقة! انظر مباشرة للكاميرا في إضاءة جيدة.
              </p>

              <div className="relative w-full h-80 bg-slate-800 rounded-[2rem] overflow-hidden flex items-center justify-center border-4 border-blue-500">
                {/* Mock Camera Feed */}
                <div className="absolute inset-0 bg-slate-700 opacity-50"></div>
                <div className="w-48 h-64 border-2 border-dashed border-white rounded-[100px] opacity-70 relative">
                  {/* Face Outline Guide */}
                  <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-32 h-40 border-2 border-blue-400 rounded-full blur-sm"></div>
                </div>
                <div className="absolute bottom-6 flex flex-col items-center">
                  <div className="w-16 h-16 rounded-full bg-white border-4 border-slate-300 flex items-center justify-center shadow-lg">
                    <div className="w-12 h-12 rounded-full bg-blue-600"></div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* STEP 4: Success & Review */}
          {step === 4 && (
            <div className="animate-fade-in text-center flex flex-col items-center justify-center h-full pb-10">
              <div className="w-24 h-24 bg-green-100 rounded-full flex items-center justify-center mb-6">
                <CheckCircle size={48} color={C.success} />
              </div>
              <h2 className="text-2xl font-bold mb-2" style={{ color: C.dark }}>تم إرسال طلبك!</h2>
              <p className="text-sm mb-8" style={{ color: C.gray }}>
                جاري مراجعة بيانات هويتك من قبل فريق وصلة لضمان الأمان. عادة ما يستغرق هذا الأمر أقل من ساعتين.
              </p>
              
              <div className="w-full p-4 bg-slate-50 rounded-xl border border-slate-200 text-right">
                <h4 className="font-bold text-sm text-slate-700 mb-2">حالة الحساب:</h4>
                <div className="flex items-center gap-2">
                  <span className="relative flex h-3 w-3">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-3 w-3 bg-amber-500"></span>
                  </span>
                  <span className="text-sm font-bold text-amber-600">قيد المراجعة (Pending)</span>
                </div>
              </div>
            </div>
          )}

        </div>

        {/* Footer Actions */}
        <div className="p-6 border-t border-slate-100 bg-white">
          {step < 4 ? (
            <button 
              onClick={nextStep}
              className="w-full py-4 rounded-xl text-white font-bold text-lg flex items-center justify-center gap-2 transition-transform active:scale-95"
              style={{ backgroundColor: C.p600 }}
            >
              <span>{step === 1 ? 'البدء في التوثيق' : step === 2 ? 'تأكيد البطاقة' : 'التقاط السيلفي'}</span>
              <ArrowRight size={20} className="rotate-180" />
            </button>
          ) : (
             <button 
              onClick={resetFlow}
              className="w-full py-4 rounded-xl text-blue-600 font-bold text-lg border-2 border-blue-100 transition-transform active:scale-95 hover:bg-blue-50"
            >
              العودة للرئيسية
            </button>
          )}
        </div>

      </div>

      {/* Explainer Note for the User */}
      <div className="max-w-md w-full mt-8 p-6 bg-white rounded-2xl shadow-sm text-right" dir="rtl">
        <h3 className="font-bold text-lg text-slate-800 mb-2">💡 ملاحظات (Wireframe)</h3>
        <ul className="list-disc list-inside text-sm text-slate-600 space-y-1">
          <li><strong>الأمان:</strong> منع رفع الصور من الاستوديو يضمن أن الشخص حقيقي.</li>
          <li><strong>تقليل الاحتكاك:</strong> الواجهة تبدو صديقة وليست معقدة كالبنوك.</li>
          <li><strong>الوضوح:</strong> إخبار المستخدم بمدة المراجعة يقلل من قلقه.</li>
        </ul>
      </div>
    </div>
  );
};

export default KycFlowPrototype;
