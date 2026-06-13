import { useState } from "react";

const C = {
  p50:"#E4F4F6",p100:"#B8E2E6",p200:"#74C4CC",
  p600:"#0D7A84",p700:"#0A606A",p900:"#032B30",
  a50:"#FEF5E4",a100:"#FDE5B0",a500:"#E89510",a600:"#C97C0C",
  n0:"#FFFFFF",n50:"#F9F7F3",n100:"#F0EDE7",n200:"#EAE4DA",
  n400:"#B0A89C",n500:"#8A8278",n600:"#6E6459",n700:"#4E473E",n900:"#161210",
  green:"#16A34A",red:"#DC2626",purple:"#7C3AED",
};

// ═══════════════════════════════════════
//  DATA
// ═══════════════════════════════════════
const PERSONAS = [
  {
    avatar:"🔧", name:"محمد السباك", type:"مقدّم خدمة", age:28, city:"المعادي، القاهرة",
    color:{bg:"#E0F2FE",fg:"#0369A1"},
    userType:"Regular → Verified",
    goal:"يجد عملاء في حيّه بسرعة ويبني سمعة موثوقة بدون وسيط",
    pains:["يعتمد على التوصيات الشفهية فقط","لا يعرف كيف يُسعّر خدماته تنافسياً","يضيع وقته في مكالمات غير جدية"],
    behavior:["موبايل 8+ ساعات يومياً","واتساب هو عالمه","يفضّل الاتصال الصوتي على الكتابة","فيسبوك مجموعات الحي"],
    scenario:"محمد يريد نشر إعلان «سباك محترف - أعمال صرف صحي وسيراميك» في أقل من دقيقتين، والانتظار لتلقّي اتصالات.",
    keyScreens:["نشر إعلان","حسابي - إعلاناتي","الإشعارات","سجل المكالمات"],
  },
  {
    avatar:"🏠", name:"سارة المهندسة", type:"باحثة عن خدمة", age:34, city:"مصر الجديدة، القاهرة",
    color:{bg:"#DCFCE7",fg:"#15803D"},
    userType:"Regular → Verified",
    goal:"تجد حرفياً موثوقاً وتعرف سعره مسبقاً بدون مفاجآت",
    pains:["لا تثق في الإعلانات بدون تحقق","لا تعرف إن كان السعر معقولاً","تخسر وقتاً في التواصل مع غير المتاحين"],
    behavior:["تبحث على Google أولاً","تقرأ التقييمات قبل أي قرار","تحفظ عدة خيارات وتقارن","تفضّل الكتابة على الاتصال في البداية"],
    scenario:"سارة اكتشفت مشكلة في الحمام مساءً وتبحث عن سباك موثّق في مصر الجديدة يرد بسرعة ويعطيها سعراً مبدئياً.",
    keyScreens:["البحث والتصفية","تفاصيل الإعلان","ملف المعلن","التقييمات","Watchlist"],
  },
  {
    avatar:"🏢", name:"حسن المكتب العقاري", type:"معلن تجاري", age:42, city:"المهندسين، الجيزة",
    color:{bg:C.a50,fg:C.a600},
    userType:"Business",
    goal:"ينشر إعلانات عقارية كثيرة ويتابع أداءها ويحوّل المهتمين لعملاء",
    pains:["ينشر في 5 منصات مختلفة يومياً","لا يعرف أي إعلاناته يؤدي بشكل أفضل","يتلقى مكالمات من خارج نطاق اهتمامه"],
    behavior:["Laptop + Mobile","يريد dashboard وأرقام","يدفع للـ Boost بشكل منتظم","يهتم بـ ROI كل إعلان"],
    scenario:"حسن ينشر 5-10 إعلانات عقارية أسبوعياً ويريد معرفة أي منها يحصل على أكثر مكالمات ومشاهدات.",
    keyScreens:["نشر إعلان","لوحة تحليلات","Boost","اشتراك Business","سجل المكالمات"],
  },
];

const SCREEN_MAP = [
  {
    group:"🚀 الـ Onboarding",color:{bg:"#EDE9FE",fg:"#5B21B6",border:"#C4B5FD"},
    screens:[
      {name:"Splash Screen",icon:"💫",desc:"شعار وصلة لمدة 2 ثانية"},
      {name:"Welcome (3 Slides)",icon:"👋",desc:"3 شرائح: ابحث | انشر | تواصل"},
      {name:"Login / Register",icon:"📱",desc:"رقم الهاتف أو Google/Facebook"},
      {name:"Phone OTP",icon:"🔐",desc:"كود 6 أرقام خلال 60 ثانية"},
      {name:"Profile Setup",icon:"👤",desc:"الاسم + الصورة + المدينة"},
    ],
  },
  {
    group:"🏠 الرئيسية (Tab 1)",color:{bg:C.p50,fg:C.p600,border:C.p100},
    screens:[
      {name:"Home Feed",icon:"🏠",desc:"بانر مميز + أقسام سريعة + إعلانات قريبة"},
      {name:"Category Landing",icon:"🗂️",desc:"إعلانات قسم معين بتصفية"},
      {name:"Notifications Center",icon:"🔔",desc:"كل الإشعارات مرتبة"},
    ],
  },
  {
    group:"🔍 الاكتشاف (Tab 2)",color:{bg:"#DCFCE7",fg:"#15803D",border:"#86EFAC"},
    screens:[
      {name:"Explore / Search",icon:"🔍",desc:"بحث + فلاتر متقدمة"},
      {name:"Results List",icon:"📋",desc:"عرض قائمة مع فلاتر جانبية"},
      {name:"Results Map",icon:"🗺️",desc:"عرض الإعلانات على الخريطة"},
      {name:"Filter Bottom Sheet",icon:"⚙️",desc:"سعر | منطقة | نوع | تاريخ"},
      {name:"Ad Detail",icon:"📄",desc:"كل تفاصيل الإعلان + تواصل"},
      {name:"Seller Profile",icon:"👤",desc:"كل إعلانات المعلن + تقييماته"},
      {name:"Photo Viewer",icon:"🖼️",desc:"معرض صور fullscreen"},
    ],
  },
  {
    group:"➕ نشر إعلان (Tab 3 — Center)",color:{bg:"#FEE2E2",fg:"#B91C1C",border:"#FCA5A5"},
    screens:[
      {name:"Step 1: اختر القسم",icon:"1️⃣",desc:"شبكة الأقسام الرئيسية والفرعية"},
      {name:"Step 2: التفاصيل",icon:"2️⃣",desc:"Form ديناميكي حسب القسم"},
      {name:"Step 3: الصور",icon:"3️⃣",desc:"رفع حتى 8 صور + ترتيب"},
      {name:"Step 4: الموقع والسعر",icon:"4️⃣",desc:"خريطة + نوع السعر"},
      {name:"Step 5: المعاينة",icon:"5️⃣",desc:"Preview قبل النشر"},
      {name:"Pending Confirmation",icon:"⏳",desc:"تأكيد الإرسال — قيد المراجعة"},
    ],
  },
  {
    group:"❤️ المحفوظة (Tab 4)",color:{bg:"#FEF5E4",fg:C.a600,border:"#FCD34D"},
    screens:[
      {name:"Favorite Ads",icon:"❤️",desc:"الإعلانات المحفوظة مع الملاحظات"},
      {name:"Saved Searches",icon:"🔔",desc:"Watchlist — بحوث تلقّي إشعارات"},
      {name:"Watchlist Results",icon:"✨",desc:"نتائج جديدة لبحث محفوظ"},
    ],
  },
  {
    group:"👤 حسابي (Tab 5)",color:{bg:"#F1F5F9",fg:"#475569",border:"#CBD5E1"},
    screens:[
      {name:"My Profile",icon:"👤",desc:"معلوماتي + التقييمات + trust score"},
      {name:"My Ads",icon:"📋",desc:"نشطة | معلّقة | منتهية | مرفوضة"},
      {name:"Ad Performance",icon:"📊",desc:"مشاهدات + مكالمات + مفضلة"},
      {name:"Boost Ad",icon:"⭐",desc:"اختر نوع ومدة التعزيز"},
      {name:"Subscription",icon:"💳",desc:"خطتي الحالية + الترقية"},
      {name:"Verification",icon:"✅",desc:"تحقق الهاتف / الرقم القومي"},
      {name:"Reviews",icon:"⭐",desc:"تقييماتي وردودي"},
      {name:"Settings",icon:"⚙️",desc:"الإشعارات + اللغة + حذف الحساب"},
    ],
  },
];

const FLOWS = [
  {
    id:"onboarding",
    title:"Onboarding & التسجيل",
    icon:"🚀",
    color:{bg:"#EDE9FE",fg:"#5B21B6",accent:"#C4B5FD"},
    desc:"رحلة المستخدم الجديد من أول فتح للتطبيق حتى دخول الرئيسية",
    steps:[
      {n:1,screen:"Splash",action:"شعار وصلة — 2 ثانية",type:"auto"},
      {n:2,screen:"Welcome Slides",action:"3 شرائح تشرح: ابحث | انشر | تواصل",type:"swipe"},
      {n:3,screen:"الدخول",action:"هل عندك حساب؟",type:"decision",
       branches:[
         {label:"مستخدم جديد",steps:["أدخل رقم الهاتف","كود OTP","اسمك + صورتك","اختر مدينتك","الرئيسية ✓"]},
         {label:"مستخدم قديم",steps:["أدخل رقم الهاتف","كود OTP","الرئيسية ✓"]},
         {label:"تصفح بدون تسجيل",steps:["الرئيسية (Guest Mode) ✓"]},
       ]},
    ],
    uxNotes:["OTP يُرسَل خلال 10 ثوانٍ أو زر إعادة الإرسال","لا يُطلب الاسم من المستخدم القديم","Guest يرى كل الإعلانات لكن التواصل محجوب"],
  },
  {
    id:"post",
    title:"نشر إعلان جديد",
    icon:"➕",
    color:{bg:"#FEE2E2",fg:"#B91C1C",accent:"#FCA5A5"},
    desc:"من الضغط على + حتى ظهور الإعلان في نتائج البحث",
    steps:[
      {n:1,screen:"Tab ➕",action:"الضغط على زر النشر المركزي",type:"tap"},
      {n:2,screen:"اختر القسم",action:"شبكة أقسام رئيسية → فرعية → تفصيلية",type:"select"},
      {n:3,screen:"Form التفاصيل",action:"حقول ديناميكية حسب القسم (السعر، الحالة، المواصفات...)",type:"fill"},
      {n:4,screen:"رفع الصور",action:"حتى 8 صور من الكاميرا أو الألبوم",type:"upload"},
      {n:5,screen:"الموقع والسعر",action:"اختر الحي من الخريطة + حدد السعر ونوعه",type:"fill"},
      {n:6,screen:"المعاينة",action:"شكل الإعلان كما سيظهر للمستخدمين",type:"review"},
      {n:7,screen:"النشر",action:"إرسال للمراجعة",type:"submit"},
      {n:8,screen:"Confirmation",action:"«إعلانك قيد المراجعة — ستُخطَر خلال ساعة»",type:"success"},
    ],
    uxNotes:["Progress bar في الأعلى (1/5 → 5/5)","حفظ مسودة تلقائياً كل 30 ثانية","زر الرجوع يحافظ على البيانات","الخطأ في حقل يُحدّد بالأحمر مع وصف واضح"],
  },
  {
    id:"search",
    title:"البحث والاكتشاف",
    icon:"🔍",
    color:{bg:"#DCFCE7",fg:"#15803D",accent:"#86EFAC"},
    desc:"كيف يجد المستخدم ما يريده بأسرع طريقة ممكنة",
    steps:[
      {n:1,screen:"Home / Explore",action:"بحث بالكلمة أو تصفح الأقسام",type:"input"},
      {n:2,screen:"النتائج",action:"قائمة إعلانات مرتبة بالقرب والحداثة",type:"view",
       variants:["📋 List View","⊞ Grid View","🗺️ Map View"]},
      {n:3,screen:"فلاتر",action:"Bottom Sheet: السعر | المنطقة | نوع الإعلان | التاريخ",type:"filter"},
      {n:4,screen:"تفاصيل الإعلان",action:"صور + معلومات كاملة + معلومات المعلن",type:"view"},
      {n:5,screen:"القرار",action:"تواصل أو احفظ أو تابع البحث",type:"decision",
       branches:[
         {label:"تواصل",steps:["اتصل / واتساب / إيميل","تُسجَّل في سجل المكالمات"]},
         {label:"احفظ",steps:["يُضاف للمفضلة","أضف ملاحظة شخصية (اختياري)"]},
         {label:"ارفع بلاغ",steps:["اختر السبب","يُرسَل للمشرف"]},
       ]},
    ],
    uxNotes:["Skeleton loading للنتائج أسرع من spinner","«لا نتائج» → اقتراح بحث أوسع","سجل التاريخ يظهر آخر 5 عمليات بحث","Map View يُجمّع الإعلانات القريبة في cluster"],
  },
  {
    id:"watchlist",
    title:"Watchlist — البحث المحفوظ",
    icon:"🔔",
    color:{bg:C.p50,fg:C.p600,accent:C.p100},
    desc:"المستخدم يحفظ بحثاً ويستقبل إشعاراً بكل إعلان جديد يطابقه تلقائياً",
    steps:[
      {n:1,screen:"نتائج بحث",action:"زر «احفظ هذا البحث» في الأعلى",type:"tap"},
      {n:2,screen:"تسمية البحث",action:"Bottom Sheet: اسم اختياري + طريقة الإشعار",type:"fill"},
      {n:3,screen:"تأكيد",action:"«سيصلك إشعار فور نشر إعلان يطابق بحثك»",type:"success"},
      {n:4,screen:"الإشعار",action:"Push: «وُجد 3 إعلانات جديدة: سباك المعادي»",type:"notify"},
      {n:5,screen:"نتائج الـ Watchlist",action:"قائمة الإعلانات الجديدة المطابقة",type:"view"},
      {n:6,screen:"تفاصيل الإعلان",action:"نفس flow البحث الاعتيادي",type:"view"},
    ],
    uxNotes:["إشعار واحد يجمع كل الإعلانات الجديدة (لا spam)","المستخدم يتحكم في وقت الإشعارات (فوري/يومي)","يمكن تعطيل Watchlist مؤقتاً بدون حذفه"],
  },
  {
    id:"contact",
    title:"التواصل مع المعلن",
    icon:"📞",
    color:{bg:"#F3E8FF",fg:"#7C3AED",accent:"#E9D5FF"},
    desc:"رحلة التواصل من الاهتمام بالإعلان حتى إتمام الصفقة",
    steps:[
      {n:1,screen:"تفاصيل الإعلان",action:"زر «تواصل» يفتح خيارات التواصل",type:"tap"},
      {n:2,screen:"اختيار التواصل",action:"Bottom Sheet: هاتف | واتساب | إيميل",type:"select"},
      {n:3,screen:"التواصل الفعلي",action:"يفتح الاتصال أو واتساب مباشرة",type:"action"},
      {n:4,screen:"سجل المكالمات",action:"يُسجَّل تلقائياً في سجل تواصلاتك مع هذا الإعلان",type:"auto"},
      {n:5,screen:"بعد الصفقة",action:"«هل أتممت صفقة مع هذا المعلن؟» — دعوة للتقييم",type:"prompt"},
      {n:6,screen:"كتابة التقييم",action:"1-5 نجوم + تعليق اختياري",type:"fill"},
    ],
    uxNotes:["رقم الهاتف مخفي جزئياً للزوار (حافز للتسجيل)","«اتصلت بهذا الإعلان منذ يومين» يظهر تلقائياً","دعوة التقييم تظهر مرة واحدة فقط — 24 ساعة بعد التواصل"],
  },
  {
    id:"boost",
    title:"Boost — تعزيز الإعلان",
    icon:"⭐",
    color:{bg:C.a50,fg:C.a600,accent:C.a100},
    desc:"المعلن يدفع لتثبيت إعلانه في أعلى النتائج وزيادة المشاهدات",
    steps:[
      {n:1,screen:"حسابي → إعلاناتي",action:"يضغط «عزّز» على إعلان معين",type:"tap"},
      {n:2,screen:"اختر نوع التعزيز",action:"3 خيارات: مميز ⭐ | عاجل 🔴 | رفع للأعلى ↑",type:"select"},
      {n:3,screen:"اختر المدة",action:"3 أيام | 7 أيام | 14 يوم | 30 يوم",type:"select"},
      {n:4,screen:"ملخص الطلب",action:"الخدمة + المدة + السعر النهائي",type:"review"},
      {n:5,screen:"الدفع (Paymob)",action:"Visa | Fawry | Vodafone Cash | InstaPay",type:"pay"},
      {n:6,screen:"التأكيد",action:"«إعلانك الآن مميز — حتى [التاريخ]»",type:"success"},
      {n:7,screen:"الإعلان المُعزَّز",action:"يظهر بشارة ⭐ مميز في أعلى النتائج",type:"result"},
    ],
    uxNotes:["عرض مقارنة: «بدون Boost: 45 مشاهدة | مع Boost: ~450 مشاهدة»","تنبيه قبل 24 ساعة من انتهاء الـ Boost","تجديد بضغطة واحدة من إشعار انتهاء الـ Boost"],
  },
];

const NAV_TABS = [
  {icon:"🏠",label:"الرئيسية",key:"home",desc:"Feed + أقسام + قريب منك"},
  {icon:"🔍",label:"اكتشف",key:"explore",desc:"بحث + خريطة + فلاتر"},
  {icon:"➕",label:"أضف",key:"post",desc:"زر مركزي بارز — نشر إعلان",highlight:true},
  {icon:"❤️",label:"المحفوظة",key:"saved",desc:"المفضلة + Watchlist"},
  {icon:"👤",label:"حسابي",key:"profile",desc:"إعلاناتي + إعدادات + اشتراك"},
];

const UX_EGYPT = [
  {icon:"📱",title:"الموبايل أولاً — بلا استثناء",desc:"95%+ من المستخدمين المصريين يدخلون من الموبايل. كل شاشة تُصمَّم للـ 360px أولاً — الـ tablet وDeskop ثانياً."},
  {icon:"🇪🇬",title:"العربية المصرية في النصوص",desc:"استخدم «دلوقتي» لا «الآن»، «عايز تبيع؟» لا «هل تريد البيع؟» — اللهجة المصرية تزيد التفاعل 40%+."},
  {icon:"📶",title:"اعتبر الإنترنت بطيئاً",desc:"Skeleton loading لكل القوائم. ضغط الصور تلقائياً. Offline mode للمفضلة. حجم التطبيق أقل من 25MB."},
  {icon:"💳",title:"الكاش ملك",desc:"زر Fawry يظهر أول الخيارات — أكثر المصريين لا يملكون بطاقة بنكية. Vodafone Cash ثانياً. Card ثالثاً."},
  {icon:"🔒",title:"الثقة تُباع بالشارة",desc:"«موثّق» بجانب اسم المعلن تزيد نسبة الاتصال بـ 3x وفق دراسات OLX. اعمل الـ Verification سهلاً جداً."},
  {icon:"📞",title:"الاتصال يتفوق على الرسائل",desc:"المصريون يتصلون أكثر مما يكتبون. زر الاتصال يكون الـ Primary CTA — ليس زر الرسائل."},
];

// ═══════════════════════════════════════
//  COMPONENTS
// ═══════════════════════════════════════
function FlowStep({ step, isLast }) {
  const typeColor = {
    auto:{bg:"#F1F5F9",fg:"#475569"},
    tap:{bg:C.p50,fg:C.p600},
    swipe:{bg:"#EDE9FE",fg:"#5B21B6"},
    select:{bg:"#DCFCE7",fg:"#15803D"},
    fill:{bg:C.a50,fg:C.a600},
    upload:{bg:"#FEE2E2",fg:"#B91C1C"},
    review:{bg:"#FEF9C3",fg:"#854D0E"},
    submit:{bg:"#DCFCE7",fg:"#15803D"},
    success:{bg:"#DCFCE7",fg:"#15803D"},
    notify:{bg:"#F3E8FF",fg:"#7C3AED"},
    view:{bg:C.p50,fg:C.p600},
    input:{bg:C.p50,fg:C.p600},
    filter:{bg:C.a50,fg:C.a600},
    action:{bg:"#DCFCE7",fg:"#15803D"},
    pay:{bg:C.a50,fg:C.a600},
    result:{bg:C.a50,fg:C.a600},
    decision:{bg:"#FEF9C3",fg:"#854D0E"},
    prompt:{bg:"#F3E8FF",fg:"#7C3AED"},
  }[step.type]||{bg:C.n100,fg:C.n600};

  return (
    <div style={{display:"flex",flexDirection:"column",alignItems:"center",flex:"0 0 auto"}}>
      <div style={{
        background:typeColor.bg,border:`2px solid ${typeColor.fg}33`,
        borderRadius:"12px",padding:"12px 14px",
        minWidth:"130px",maxWidth:"160px",textAlign:"center",
        position:"relative",
      }}>
        <div style={{
          position:"absolute",top:"-10px",right:"50%",transform:"translateX(50%)",
          background:typeColor.fg,color:"#FFF",
          width:"20px",height:"20px",borderRadius:"50%",
          display:"flex",alignItems:"center",justifyContent:"center",
          fontSize:"10px",fontWeight:800,fontFamily:"'IBM Plex Mono',monospace",
        }}>{step.n}</div>
        <div style={{fontSize:"12px",fontWeight:800,color:typeColor.fg,marginBottom:"4px",marginTop:"4px"}}>{step.screen}</div>
        <div style={{fontSize:"11px",color:typeColor.fg,opacity:0.8,lineHeight:1.5}}>{step.action}</div>
        {step.variants && (
          <div style={{display:"flex",gap:"4px",marginTop:"6px",justifyContent:"center",flexWrap:"wrap"}}>
            {step.variants.map(v=>(
              <span key={v} style={{fontSize:"9px",background:C.n0,color:typeColor.fg,padding:"1px 6px",borderRadius:"4px",fontWeight:600}}>{v}</span>
            ))}
          </div>
        )}
      </div>
      {!isLast && <div style={{color:typeColor.fg,fontSize:"18px",marginTop:"4px",opacity:0.5}}>↓</div>}
    </div>
  );
}

// ═══════════════════════════════════════
//  MAIN
// ═══════════════════════════════════════
export default function WaslaUX() {
  const [tab, setTab] = useState("personas");
  const [activeFlow, setActiveFlow] = useState("onboarding");
  const tabs = [
    {id:"personas",ar:"شخصيات المستخدمين"},
    {id:"screens", ar:"خريطة الشاشات"},
    {id:"flows",   ar:"User Flows (6)"},
    {id:"nav",     ar:"الـ Navigation + UX"},
  ];

  const currentFlow = FLOWS.find(f=>f.id===activeFlow);

  return (
    <div style={{fontFamily:"'Cairo',sans-serif",direction:"rtl",background:C.n50,minHeight:"100vh",color:C.n900}}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700;800;900&family=IBM+Plex+Mono:wght@400;600&display=swap');
        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
        ::-webkit-scrollbar{width:5px;height:5px;}
        ::-webkit-scrollbar-thumb{background:${C.p200};border-radius:4px;}
      `}</style>

      {/* HEADER */}
      <div style={{background:`linear-gradient(145deg,${C.p900},${C.p700})`,padding:"22px 26px 0",position:"sticky",top:0,zIndex:200}}>
        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"16px"}}>
          <div>
            <div style={{display:"flex",alignItems:"center",gap:"12px"}}>
              <span style={{fontSize:"20px",fontWeight:900,color:"#FFF"}}>وصلة</span>
              <span style={{background:"rgba(255,255,255,0.15)",color:"rgba(255,255,255,0.75)",padding:"2px 10px",borderRadius:"20px",fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace"}}>
                UX/UI & User Flow
              </span>
            </div>
            <p style={{color:"rgba(255,255,255,0.5)",fontSize:"12px",marginTop:"3px"}}>
              3 personas · {SCREEN_MAP.reduce((a,g)=>a+g.screens.length,0)} شاشة · 6 flows رئيسية · 5 tabs navigation
            </p>
          </div>
          <div style={{display:"flex",gap:"6px"}}>
            {["Flutter","RTL","Arabic UX"].map(t=>(
              <span key={t} style={{background:"rgba(255,255,255,0.12)",border:"1px solid rgba(255,255,255,0.2)",color:"rgba(255,255,255,0.8)",padding:"4px 10px",borderRadius:"6px",fontSize:"11px"}}>{t}</span>
            ))}
          </div>
        </div>
        <div style={{display:"flex",gap:"2px"}}>
          {tabs.map(t=>(
            <button key={t.id} onClick={()=>setTab(t.id)} style={{
              background:tab===t.id?"rgba(255,255,255,0.15)":"transparent",
              border:"none",borderBottom:tab===t.id?`3px solid ${C.a500}`:"3px solid transparent",
              padding:"9px 16px",cursor:"pointer",fontSize:"13px",
              fontFamily:"'Cairo',sans-serif",fontWeight:tab===t.id?700:500,
              color:tab===t.id?"#FFF":"rgba(255,255,255,0.55)",
              borderRadius:"6px 6px 0 0",transition:"all 0.15s",
            }}>{t.ar}</button>
          ))}
        </div>
      </div>

      <div style={{maxWidth:"1100px",margin:"0 auto",padding:"24px 20px 60px"}}>

        {/* ══ TAB 1: PERSONAS ══ */}
        {tab==="personas" && (
          <div style={{display:"flex",flexDirection:"column",gap:"20px"}}>
            {PERSONAS.map(p=>(
              <div key={p.name} style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"16px",overflow:"hidden"}}>
                <div style={{background:p.color.bg,padding:"18px 22px",display:"flex",alignItems:"flex-start",gap:"16px"}}>
                  <div style={{fontSize:"40px",lineHeight:1}}>{p.avatar}</div>
                  <div style={{flex:1}}>
                    <div style={{display:"flex",alignItems:"center",gap:"10px",marginBottom:"4px"}}>
                      <span style={{fontSize:"18px",fontWeight:900,color:p.color.fg}}>{p.name}</span>
                      <span style={{fontSize:"11px",background:`${p.color.fg}22`,color:p.color.fg,padding:"2px 10px",borderRadius:"20px",fontWeight:700}}>{p.type}</span>
                      <span style={{fontSize:"11px",background:C.n0,color:p.color.fg,padding:"2px 10px",borderRadius:"20px",fontFamily:"'IBM Plex Mono',monospace",fontWeight:600,border:`1px solid ${p.color.fg}44`}}>{p.userType}</span>
                    </div>
                    <div style={{fontSize:"13px",color:p.color.fg,opacity:0.75}}>{p.age} سنة · {p.city}</div>
                  </div>
                  <div style={{background:C.n0,borderRadius:"10px",padding:"10px 16px",maxWidth:"320px"}}>
                    <div style={{fontSize:"11px",fontWeight:700,color:p.color.fg,marginBottom:"4px"}}>الهدف الرئيسي</div>
                    <div style={{fontSize:"13px",color:p.color.fg,lineHeight:1.6}}>{p.goal}</div>
                  </div>
                </div>
                <div style={{padding:"18px 22px",display:"grid",gridTemplateColumns:"1fr 1fr 1fr",gap:"16px"}}>
                  <div>
                    <div style={{fontSize:"11px",fontWeight:800,color:C.n500,marginBottom:"8px",letterSpacing:"0.06em"}}>نقاط الألم</div>
                    {p.pains.map((pain,i)=>(
                      <div key={i} style={{display:"flex",gap:"6px",marginBottom:"6px",fontSize:"13px",color:C.n700}}>
                        <span style={{color:C.red,fontWeight:700,flexShrink:0}}>✗</span>{pain}
                      </div>
                    ))}
                  </div>
                  <div>
                    <div style={{fontSize:"11px",fontWeight:800,color:C.n500,marginBottom:"8px",letterSpacing:"0.06em"}}>السلوك الرقمي</div>
                    {p.behavior.map((b,i)=>(
                      <div key={i} style={{display:"flex",gap:"6px",marginBottom:"6px",fontSize:"13px",color:C.n700}}>
                        <span style={{color:C.p600,fontWeight:700,flexShrink:0}}>→</span>{b}
                      </div>
                    ))}
                  </div>
                  <div>
                    <div style={{fontSize:"11px",fontWeight:800,color:C.n500,marginBottom:"8px",letterSpacing:"0.06em"}}>السيناريو الرئيسي</div>
                    <div style={{background:C.n50,borderRadius:"10px",padding:"12px",fontSize:"13px",color:C.n600,lineHeight:1.65,fontStyle:"italic"}}>
                      «{p.scenario}»
                    </div>
                    <div style={{marginTop:"10px"}}>
                      <div style={{fontSize:"11px",fontWeight:700,color:C.n500,marginBottom:"6px"}}>شاشاته المهمة</div>
                      <div style={{display:"flex",flexWrap:"wrap",gap:"5px"}}>
                        {p.keyScreens.map(s=>(
                          <span key={s} style={{fontSize:"11px",background:p.color.bg,color:p.color.fg,padding:"2px 8px",borderRadius:"5px",fontWeight:600}}>{s}</span>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ══ TAB 2: SCREEN MAP ══ */}
        {tab==="screens" && (
          <div style={{display:"flex",flexDirection:"column",gap:"14px"}}>
            {SCREEN_MAP.map(group=>(
              <div key={group.group} style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden"}}>
                <div style={{background:group.color.bg,padding:"12px 18px",display:"flex",alignItems:"center",justifyContent:"space-between"}}>
                  <span style={{fontSize:"14px",fontWeight:800,color:group.color.fg}}>{group.group}</span>
                  <span style={{fontSize:"11px",background:`${group.color.fg}22`,color:group.color.fg,padding:"2px 8px",borderRadius:"6px",fontWeight:700}}>{group.screens.length} شاشات</span>
                </div>
                <div style={{padding:"14px 18px",display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(180px,1fr))",gap:"10px"}}>
                  {group.screens.map(screen=>(
                    <div key={screen.name} style={{
                      border:`1px solid ${group.color.border}`,borderRadius:"10px",
                      padding:"10px 14px",background:`${group.color.bg}50`,
                    }}>
                      <div style={{display:"flex",alignItems:"center",gap:"7px",marginBottom:"4px"}}>
                        <span style={{fontSize:"16px"}}>{screen.icon}</span>
                        <span style={{fontSize:"12px",fontWeight:700,color:group.color.fg}}>{screen.name}</span>
                      </div>
                      <div style={{fontSize:"11px",color:group.color.fg,opacity:0.75,lineHeight:1.5}}>{screen.desc}</div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
            <div style={{background:C.p900,borderRadius:"12px",padding:"14px 18px",display:"flex",alignItems:"center",justifyContent:"space-between"}}>
              <span style={{color:"rgba(255,255,255,0.8)",fontSize:"13px",fontWeight:600}}>إجمالي الشاشات</span>
              <span style={{color:C.a500,fontSize:"22px",fontWeight:900,fontFamily:"'IBM Plex Mono',monospace"}}>
                {SCREEN_MAP.reduce((a,g)=>a+g.screens.length,0)} شاشة
              </span>
            </div>
          </div>
        )}

        {/* ══ TAB 3: FLOWS ══ */}
        {tab==="flows" && (
          <div>
            {/* Flow selector */}
            <div style={{display:"flex",gap:"8px",marginBottom:"20px",flexWrap:"wrap"}}>
              {FLOWS.map(f=>(
                <button key={f.id} onClick={()=>setActiveFlow(f.id)} style={{
                  background:activeFlow===f.id?f.color.bg:"transparent",
                  border:`1.5px solid ${activeFlow===f.id?f.color.fg:C.n200}`,
                  padding:"8px 16px",borderRadius:"10px",cursor:"pointer",
                  fontSize:"13px",fontFamily:"'Cairo',sans-serif",
                  fontWeight:activeFlow===f.id?700:500,
                  color:activeFlow===f.id?f.color.fg:C.n600,
                  display:"flex",alignItems:"center",gap:"6px",
                }}>
                  <span>{f.icon}</span>{f.title}
                </button>
              ))}
            </div>

            {currentFlow && (
              <div>
                {/* Flow header */}
                <div style={{background:currentFlow.color.bg,border:`1px solid ${currentFlow.color.accent}`,borderRadius:"14px",padding:"16px 20px",marginBottom:"16px"}}>
                  <div style={{display:"flex",alignItems:"center",gap:"10px",marginBottom:"6px"}}>
                    <span style={{fontSize:"24px"}}>{currentFlow.icon}</span>
                    <h3 style={{fontSize:"18px",fontWeight:900,color:currentFlow.color.fg}}>{currentFlow.title}</h3>
                  </div>
                  <p style={{fontSize:"13px",color:currentFlow.color.fg,opacity:0.85,lineHeight:1.6}}>{currentFlow.desc}</p>
                </div>

                {/* Steps */}
                <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",padding:"20px",marginBottom:"14px"}}>
                  <div style={{fontSize:"12px",fontWeight:700,color:C.n500,marginBottom:"16px",letterSpacing:"0.06em"}}>STEPS — الخطوات</div>
                  <div style={{display:"flex",flexDirection:"column",alignItems:"flex-start",gap:"0",overflowX:"auto"}}>
                    {currentFlow.steps.map((step,i)=>(
                      <div key={step.n}>
                        <FlowStep step={step} isLast={i===currentFlow.steps.length-1}/>
                        {step.type==="decision" && step.branches && (
                          <div style={{display:"flex",gap:"10px",marginBottom:"8px",flexWrap:"wrap",marginTop:"4px"}}>
                            {step.branches.map((b,bi)=>(
                              <div key={bi} style={{background:C.n50,border:`1px solid ${C.n200}`,borderRadius:"10px",padding:"10px 14px",flex:"1",minWidth:"140px"}}>
                                <div style={{fontSize:"11px",fontWeight:800,color:C.a600,marginBottom:"6px"}}>{b.label}</div>
                                {b.steps.map((s,si)=>(
                                  <div key={si} style={{fontSize:"11px",color:C.n600,marginBottom:"3px",display:"flex",gap:"5px"}}>
                                    <span style={{color:C.p600}}>→</span>{s}
                                  </div>
                                ))}
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </div>

                {/* UX Notes */}
                <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",padding:"16px 20px"}}>
                  <div style={{fontSize:"12px",fontWeight:700,color:C.n500,marginBottom:"12px",letterSpacing:"0.06em"}}>UX NOTES — ملاحظات التصميم</div>
                  {currentFlow.uxNotes.map((note,i)=>(
                    <div key={i} style={{display:"flex",gap:"8px",marginBottom:"8px",background:C.a50,borderRadius:"8px",padding:"8px 12px",fontSize:"13px",color:C.a600}}>
                      <span style={{fontWeight:700,flexShrink:0}}>💡</span>{note}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* ══ TAB 4: NAV + UX NOTES ══ */}
        {tab==="nav" && (
          <div>
            {/* Bottom Nav */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"16px",overflow:"hidden",marginBottom:"20px"}}>
              <div style={{padding:"14px 20px",background:C.n50,borderBottom:`1px solid ${C.n100}`}}>
                <h3 style={{fontSize:"15px",fontWeight:900,color:C.n900}}>Bottom Navigation — 5 Tabs</h3>
                <p style={{fontSize:"12px",color:C.n500,marginTop:"2px"}}>هيكل الـ Navigation الرئيسي في تطبيق Flutter</p>
              </div>
              {/* Visual mockup */}
              <div style={{padding:"24px",background:`linear-gradient(180deg,${C.n50} 0%,${C.n100} 100%)`}}>
                <div style={{
                  background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"20px",
                  padding:"16px 8px 8px",maxWidth:"360px",margin:"0 auto",
                  boxShadow:"0 4px 24px rgba(0,0,0,0.08)",
                }}>
                  <div style={{padding:"8px 16px 16px",background:C.n50,borderRadius:"12px",marginBottom:"12px",textAlign:"center",color:C.n400,fontSize:"12px"}}>
                    محتوى الشاشة
                  </div>
                  <div style={{display:"flex",justifyContent:"space-around",borderTop:`1px solid ${C.n100}`,paddingTop:"12px"}}>
                    {NAV_TABS.map(t=>(
                      <div key={t.key} style={{
                        display:"flex",flexDirection:"column",alignItems:"center",gap:"3px",
                        flex:1,
                      }}>
                        <div style={{
                          width:t.highlight?50:36,height:t.highlight?50:36,
                          background:t.highlight?C.p600:C.n50,
                          borderRadius:t.highlight?"50%":"10px",
                          display:"flex",alignItems:"center",justifyContent:"center",
                          fontSize:t.highlight?20:16,
                          boxShadow:t.highlight?"0 4px 12px rgba(13,122,132,0.4)":undefined,
                          marginTop:t.highlight?"-20px":0,
                          border:t.highlight?`3px solid ${C.n0}`:undefined,
                        }}>{t.icon}</div>
                        <span style={{fontSize:"10px",color:t.highlight?"#FFF":C.n500,fontWeight:600,display:t.highlight?"none":"block"}}>{t.label}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
              <div style={{padding:"14px 20px",display:"flex",flexDirection:"column",gap:"8px"}}>
                {NAV_TABS.map(t=>(
                  <div key={t.key} style={{display:"flex",alignItems:"center",gap:"12px",background:t.highlight?C.p50:C.n50,borderRadius:"10px",padding:"10px 14px"}}>
                    <span style={{fontSize:"18px"}}>{t.icon}</span>
                    <div>
                      <span style={{fontSize:"13px",fontWeight:700,color:t.highlight?C.p600:C.n800}}>{t.label}</span>
                      {t.highlight && <span style={{fontSize:"11px",background:C.p600,color:"#FFF",padding:"1px 7px",borderRadius:"5px",marginRight:"6px",fontWeight:700}}>CTA رئيسي</span>}
                      <div style={{fontSize:"12px",color:C.n500,marginTop:"1px"}}>{t.desc}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Egyptian UX Notes */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"16px",overflow:"hidden"}}>
              <div style={{padding:"14px 20px",background:`linear-gradient(135deg,${C.p900},${C.p700})`,display:"flex",alignItems:"center",gap:"10px"}}>
                <span style={{fontSize:"20px"}}>🇪🇬</span>
                <div>
                  <h3 style={{fontSize:"15px",fontWeight:900,color:"#FFF"}}>ملاحظات UX خاصة بالسوق المصري</h3>
                  <p style={{fontSize:"12px",color:"rgba(255,255,255,0.6)",marginTop:"2px"}}>قواعد تصميم مبنية على خصائص المستخدم المصري</p>
                </div>
              </div>
              <div style={{padding:"16px 20px",display:"grid",gridTemplateColumns:"1fr 1fr",gap:"12px"}}>
                {UX_EGYPT.map((note,i)=>(
                  <div key={i} style={{background:C.n50,borderRadius:"12px",padding:"14px 16px"}}>
                    <div style={{display:"flex",alignItems:"center",gap:"8px",marginBottom:"8px"}}>
                      <span style={{fontSize:"20px"}}>{note.icon}</span>
                      <span style={{fontSize:"13px",fontWeight:800,color:C.n900}}>{note.title}</span>
                    </div>
                    <p style={{fontSize:"12px",color:C.n600,lineHeight:1.65}}>{note.desc}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
