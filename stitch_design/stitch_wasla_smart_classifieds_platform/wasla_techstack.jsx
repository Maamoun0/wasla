import { useState } from "react";

const C = {
  p50:"#E4F4F6",p100:"#B8E2E6",p200:"#74C4CC",
  p600:"#0D7A84",p700:"#0A606A",p900:"#032B30",
  a50:"#FEF5E4",a500:"#E89510",a600:"#C97C0C",
  n0:"#FFFFFF",n50:"#F9F7F3",n100:"#F0EDE7",n200:"#EAE4DA",
  n400:"#B0A89C",n500:"#8A8278",n600:"#6E6459",n700:"#4E473E",n900:"#161210",
  green:"#16A34A",red:"#DC2626",
};

const STACK = [
  {
    layer:"mobile",ar:"تطبيق الجوال",icon:"📱",
    color:{bg:"#E0F2FE",fg:"#0369A1"},
    tech:"Flutter 3",by:"Google",phase:1,
    desc:"إطار واحد يبني iOS وAndroid معاً بكود واحد — الاختيار الأمثل لمطوّر solo",
    reasons:[
      "كود واحد ← تطبيقين (iOS + Android)",
      "supabase_flutter SDK رسمي واحترافي",
      "أداء native حقيقي — لا WebView",
      "Hot Reload يسرّع التطوير 3x",
      "Flame Engine للرسوم والإشعارات",
    ],
    rejected:"React Native",whyNot:"أقل استقراراً مع Supabase، وأداء أضعف على الأجهزة المتوسطة",
    pkgs:["supabase_flutter","flutter_riverpod","go_router","google_maps_flutter","firebase_messaging","dio"],
  },
  {
    layer:"database",ar:"قاعدة البيانات",icon:"🗄️",
    color:{bg:"#EDE9FE",fg:"#5B21B6"},
    tech:"PostgreSQL 15",by:"via Supabase",phase:1,
    desc:"أقوى قاعدة بيانات relational مفتوحة المصدر — تتحمل ملايين الإعلانات بأداء ثابت",
    reasons:[
      "يدعم الـ 34 جدول بجميع علاقاتها الـ 45",
      "JSONB للحقول الديناميكية (category_fields)",
      "PostGIS للبحث الجغرافي — أقرب إعلان منك",
      "Full-text Search بالعربية عبر tsvector",
      "Row Level Security — صلاحيات على مستوى DB",
      "pg_cron للوظائف المجدولة (انتهاء الإعلانات)",
    ],
    rejected:"MySQL / MongoDB",whyNot:"MySQL أضعف في JSONB وFull-text. MongoDB لا يدعم 44 علاقة relational",
    pkgs:["pg_cron","pgaudit","PostGIS","pgvector (للـ AI لاحقاً)"],
  },
  {
    layer:"backend",ar:"الـ Backend",icon:"⚡",
    color:{bg:"#DCFCE7",fg:"#15803D"},
    tech:"Supabase",by:"Open Source BaaS",phase:1,
    desc:"Backend-as-a-Service مبني فوق PostgreSQL — يغني عن كتابة 80% من الـ API يدوياً في الـ MVP",
    reasons:[
      "PostgREST: API تلقائي مكتمل من DB مباشرة",
      "Auth مدمج: OTP SMS + Email + Google + Facebook",
      "Realtime: WebSocket تلقائي لأي جدول",
      "Storage مدمج: رفع الصور مع Transform تلقائي",
      "Edge Functions: Deno/TypeScript للـ Business Logic",
      "Free tier كريم جداً — يكفي حتى 10K مستخدم",
    ],
    rejected:"Firebase / Appwrite",whyNot:"Firebase NoSQL — لا يدعم 34 جدول علائقي. Appwrite أضعف في Realtime",
    pkgs:["supabase-js","supabase-flutter","@supabase/ssr","deno (Edge Functions)"],
  },
  {
    layer:"admin",ar:"لوحة التحكم",icon:"🖥️",
    color:{bg:"#FEF9C3",fg:"#854D0E"},
    tech:"Next.js 14",by:"Vercel — App Router",phase:1,
    desc:"لوحة الأدمن والمشرفين — React Server Components + deploy مجاني على Vercel",
    reasons:[
      "App Router: أحدث معمارية React للـ 2025",
      "Server Components: أداء عالٍ بدون JS زائد",
      "@supabase/ssr: Auth سلس بين Server وClient",
      "Deploy على Vercel مجاناً للـ admin panel",
      "يشارك TypeScript مع Edge Functions",
    ],
    rejected:"Laravel / Django Admin",whyNot:"يضيفان لغة ثانية (PHP/Python) — نحافظ على TypeScript فقط",
    pkgs:["@supabase/ssr","tailwindcss","shadcn/ui","recharts","@tanstack/react-query"],
  },
  {
    layer:"search",ar:"محرك البحث العربي",icon:"🔍",
    color:{bg:"#FEE2E2",fg:"#B91C1C"},
    tech:"Typesense",by:"Self-hosted",phase:2,
    desc:"محرك بحث خاطف السرعة يدعم العربية الكاملة — بديل Elasticsearch بـ 5% من التعقيد",
    reasons:[
      "دعم كامل للعربية والـ RTL",
      "Typo tolerance — يفهم الأخطاء الإملائية",
      "Faceted Search للفلاتر المتقدمة",
      "أسرع من Elasticsearch بـ 10x في الإعداد",
      "Self-hosted على VPS بـ $5 شهرياً",
    ],
    rejected:"Elasticsearch / Algolia",whyNot:"Elasticsearch معقد جداً للـ solo dev. Algolia $100+/شهر بعد 10K عملية",
    pkgs:["typesense-js","typesense-flutter"],
    note:"Phase 1: Supabase Full-text Search كافٍ تماماً",
  },
  {
    layer:"cache",ar:"الـ Cache والـ Queue",icon:"🚀",
    color:{bg:"#FEF5E4",fg:"#C97C0C"},
    tech:"Redis — Upstash",by:"Serverless Redis",phase:2,
    desc:"قاعدة بيانات في الذاكرة — تسرّع استجابة API ويتحمل load ضخم بدون زيادة DB queries",
    reasons:[
      "Cache الأقسام والإعلانات المميزة",
      "Rate Limiting لحماية API من الـ abuse",
      "Session store لتسريع Auth",
      "Queue للوظائف الخلفية عبر BullMQ",
      "Upstash: Serverless + free tier سخي جداً",
    ],
    rejected:"Memcached",whyNot:"Redis أقوى — يدعم Data Structures وPub/Sub وPersistence",
    pkgs:["@upstash/redis","ioredis","bullmq"],
    note:"Phase 1: ليس ضرورياً — Supabase يكفي للـ MVP",
  },
  {
    layer:"notifications",ar:"الإشعارات",icon:"🔔",
    color:{bg:"#F3E8FF",fg:"#7C3AED"},
    tech:"Firebase FCM",by:"Google — مجاني تماماً",phase:1,
    desc:"خدمة Push Notifications مجانية ولا محدودة لـ iOS وAndroid — المعيار الصناعي",
    reasons:[
      "مجاني بالكامل بدون أي حدود",
      "يدعم iOS + Android + Web",
      "تكامل مع Supabase Edge Functions",
      "Rich Notifications: صور + أزرار + actions",
      "99.99% uptime — موثوقية تامة",
    ],
    rejected:"OneSignal / Pusher",whyNot:"FCM مجاني تماماً. OneSignal يفرض رسوماً بعد 10K مستخدم",
    pkgs:["firebase_messaging (Flutter)","@firebase/messaging (Web)"],
  },
  {
    layer:"payments",ar:"الدفع الإلكتروني",icon:"💳",
    color:{bg:"#DCFCE7",fg:"#15803D"},
    tech:"Paymob",by:"بوابة #1 في مصر",phase:1,
    desc:"البوابة الوحيدة التي تغطي كل طرق الدفع المصرية في API واحد — إلزامية للسوق المصري",
    reasons:[
      "Visa + MasterCard + Meeza (بطاقة مياء)",
      "Fawry + Vodafone Cash + InstaPay + Vallu",
      "Flutter SDK رسمي جاهز",
      "Webhook فوري لـ transaction status",
      "Dashboard عربي سهل للإدارة",
    ],
    rejected:"Stripe / PayPal",whyNot:"Stripe غير متاح رسمياً في مصر. PayPal محدود — لا يدعم Fawry/VF Cash",
    pkgs:["Paymob Accept API","paymob_accept (Flutter unofficial)"],
  },
  {
    layer:"storage",ar:"تخزين الملفات والصور",icon:"☁️",
    color:{bg:"#E0F2FE",fg:"#0369A1"},
    tech:"Cloudflare R2",by:"Cloudflare",phase:2,
    desc:"تخزين S3-compatible بدون رسوم egress — يوفر 90% مقارنة بـ AWS S3 عند ملايين الصور",
    reasons:[
      "Zero egress fees — AWS تفرض $0.09/GB",
      "$0.015/GB storage فقط",
      "Cloudflare Images: resize + compress تلقائي",
      "CDN عالمي مدمج بدون رسوم إضافية",
      "99.999999999% (11 nines) durability",
    ],
    rejected:"AWS S3 / Cloudinary",whyNot:"S3 egress fees ستكلف آلاف الدولارات مع نمو الصور. Cloudinary غالي جداً",
    pkgs:["aws-sdk v3 (S3-compatible)","@aws-sdk/client-s3"],
    note:"Phase 1: Supabase Storage مجاني وأبسط — يكفي للـ MVP",
  },
  {
    layer:"monitoring",ar:"المراقبة والتحليل",icon:"📊",
    color:{bg:"#F1F5F9",fg:"#475569"},
    tech:"Sentry + PostHog",by:"Error & Product Analytics",phase:1,
    desc:"مراقبة الأخطاء وتتبع سلوك المستخدمين — free tiers ضخمة تكفي لسنوات",
    reasons:[
      "Sentry: يكشف كل crash فوراً مع stack trace",
      "PostHog: Product Analytics كـ Mixpanel لكن مجاني",
      "كلاهما لهم free tiers يكفي حتى 100K مستخدم",
      "Supabase Dashboard للـ DB metrics",
      "Uptime Robot لمراقبة الـ uptime مجاناً",
    ],
    rejected:"Datadog / New Relic",whyNot:"مكلفان جداً ($100+/شهر). Sentry+PostHog يغطيان 95% من الاحتياجات مجاناً",
    pkgs:["@sentry/nextjs","@sentry/flutter","posthog-js","posthog_flutter"],
  },
];

const ARCH_LAYERS = [
  {
    label:"CLIENTS", color:{bg:"#E0F2FE",border:"#7DD3FC",fg:"#0369A1"},
    items:[
      {icon:"📱",name:"Flutter App",sub:"iOS + Android"},
      {icon:"🖥️",name:"Next.js 14",sub:"Admin Panel"},
    ],
  },
  {
    label:"API GATEWAY", color:{bg:"#DCFCE7",border:"#86EFAC",fg:"#15803D"},
    items:[
      {icon:"⚡",name:"Supabase PostgREST",sub:"Auto REST API"},
      {icon:"🔧",name:"Edge Functions",sub:"Deno / TypeScript"},
      {icon:"🔒",name:"Row Level Security",sub:"Permissions @ DB"},
    ],
  },
  {
    label:"CORE SERVICES", color:{bg:"#EDE9FE",border:"#C4B5FD",fg:"#5B21B6"},
    items:[
      {icon:"🗄️",name:"PostgreSQL 15",sub:"34 Tables"},
      {icon:"🔐",name:"Auth + OTP",sub:"SMS / Social"},
      {icon:"📁",name:"Storage",sub:"Images + Files"},
      {icon:"📡",name:"Realtime",sub:"WebSocket"},
    ],
  },
  {
    label:"SCALE SERVICES (Phase 2)", color:{bg:"#FEF5E4",border:"#FCD34D",fg:"#C97C0C"},
    items:[
      {icon:"🔍",name:"Typesense",sub:"Arabic Search"},
      {icon:"🚀",name:"Redis / Upstash",sub:"Cache + Queue"},
      {icon:"☁️",name:"Cloudflare R2",sub:"Media Storage"},
      {icon:"🔧",name:"NestJS API",sub:"Custom Logic"},
    ],
  },
  {
    label:"EXTERNAL SERVICES", color:{bg:"#F1F5F9",border:"#CBD5E1",fg:"#475569"},
    items:[
      {icon:"🔔",name:"Firebase FCM",sub:"Push Notifications"},
      {icon:"💳",name:"Paymob",sub:"Egyptian Payments"},
      {icon:"🌐",name:"Cloudflare CDN",sub:"DNS + DDoS"},
      {icon:"📊",name:"Sentry + PostHog",sub:"Monitoring"},
    ],
  },
];

const PHASES = [
  {
    n:1,label:"MVP",timeAr:"60–90 يوم",
    color:{bg:"#DCFCE7",fg:"#15803D",accent:"#86EFAC"},
    cost:"$0",costSub:"Free tiers بالكامل",
    users:"0 ← 10,000 مستخدم",
    techs:["Flutter 3","Supabase (PG+Auth+API+Storage+Realtime)","Next.js 14 (Admin)","Firebase FCM","Paymob","Sentry"],
    desc:"بنية خفيفة ومتكاملة — تبنيها بالكامل خلال شهرين وتغطي 100% من features الأساسية",
  },
  {
    n:2,label:"Growth",timeAr:"شهر 3–6",
    color:{bg:"#FEF5E4",fg:"#C97C0C",accent:"#FCD34D"},
    cost:"$55–90",costSub:"شهرياً",
    users:"10,000 ← 100,000 مستخدم",
    techs:["Supabase Pro ($25/شهر)","+ Typesense (بحث عربي)","+ Upstash Redis (Cache)","+ Cloudflare R2 (Storage)"],
    desc:"إضافة محرك البحث العربي والـ Cache لتسريع المنصة عند التوسع",
  },
  {
    n:3,label:"Scale",timeAr:"شهر 12+",
    color:{bg:C.p50,fg:C.p600,accent:C.p200},
    cost:"$200–400",costSub:"شهرياً",
    users:"100,000 ← 1,000,000 مستخدم",
    techs:["+ NestJS API Layer","+ BullMQ Background Jobs","+ Hetzner VPS ($20/شهر)","+ Read Replicas للـ DB"],
    desc:"معمارية microservices خفيفة — تتحمل مليون مستخدم بدون إعادة كتابة الكود",
  },
];

const COMPARISONS = [
  {cat:"قاعدة البيانات",chosen:"PostgreSQL",rejected:"MongoDB",reason:"34 جدول بـ 45 علاقة — مستحيل بدون Relational DB. MongoDB لا يدعم JOINs بالكفاءة المطلوبة"},
  {cat:"Backend",chosen:"Supabase",rejected:"Firebase",reason:"Firebase NoSQL — لا يدعم schema المعقد أبداً. Supabase IS PostgreSQL"},
  {cat:"Backend (Scale)",chosen:"NestJS",rejected:"Express.js",reason:"Express غير منظم للمشاريع الكبيرة. NestJS: Decorators + DI + Modules = كود يُقرأ بعد سنة"},
  {cat:"تطبيق الجوال",chosen:"Flutter",rejected:"React Native",reason:"أداء native أفضل، supabase_flutter SDK رسمي ممتاز، codebase أنظف"},
  {cat:"Admin Panel",chosen:"Next.js 14",rejected:"Laravel / Django",reason:"يضيفان لغة ثانية — نحافظ على TypeScript فقط في كامل المشروع"},
  {cat:"البحث",chosen:"Typesense",rejected:"Elasticsearch",reason:"Elasticsearch يحتاج DevOps متخصص. Typesense: تنصيب في دقيقة، عربي كامل، $5/شهر"},
  {cat:"البحث",chosen:"Typesense",rejected:"Algolia",reason:"Algolia $100+/شهر بعد 10K عملية. Typesense self-hosted بـ $5 شهرياً"},
  {cat:"الـ Cache",chosen:"Redis/Upstash",rejected:"Memcached",reason:"Redis يدعم Data Structures + Pub/Sub + BullMQ Queue — أقوى بكثير"},
  {cat:"الدفع",chosen:"Paymob",rejected:"Stripe / PayPal",reason:"Stripe غير متاح رسمياً في مصر. Paymob يدعم Fawry + VF Cash + InstaPay — إلزامي"},
  {cat:"الإشعارات",chosen:"Firebase FCM",rejected:"OneSignal",reason:"FCM مجاني تماماً. OneSignal يفرض رسوماً بعد 10K مستخدم"},
  {cat:"Storage",chosen:"Cloudflare R2",rejected:"AWS S3",reason:"S3 egress fees = $0.09/GB × ملايين الصور = فاتورة كارثية. R2 = Zero egress"},
  {cat:"المراقبة",chosen:"Sentry + PostHog",rejected:"Datadog",reason:"Datadog $100+/شهر. Sentry + PostHog يغطيان 95% مجاناً حتى 100K مستخدم"},
];

// ═══════════════════════════════════════════
//  COMPONENTS
// ═══════════════════════════════════════════
function StackCard({ item }) {
  const { color,tech,by,phase,desc,reasons,rejected,whyNot,pkgs,note,icon,ar } = item;
  return (
    <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"16px",overflow:"hidden"}}>
      <div style={{background:color.bg,padding:"16px 18px"}}>
        <div style={{display:"flex",alignItems:"flex-start",justifyContent:"space-between",gap:"8px"}}>
          <div style={{display:"flex",alignItems:"center",gap:"10px"}}>
            <span style={{fontSize:"26px"}}>{icon}</span>
            <div>
              <div style={{fontSize:"17px",fontWeight:900,color:color.fg,fontFamily:"'IBM Plex Mono',monospace",lineHeight:1.2}}>{tech}</div>
              <div style={{fontSize:"11px",color:color.fg,opacity:0.75,marginTop:"2px"}}>{by} · {ar}</div>
            </div>
          </div>
          <span style={{
            fontSize:"10px",fontWeight:800,whiteSpace:"nowrap",
            background:phase===1?color.fg:"transparent",
            color:phase===1?"#FFF":color.fg,
            border:`1.5px solid ${color.fg}`,
            padding:"3px 10px",borderRadius:"20px",
            fontFamily:"'IBM Plex Mono',monospace",flexShrink:0,
          }}>{phase===1?"✓ MVP":"Phase 2"}</span>
        </div>
        <p style={{fontSize:"12px",color:color.fg,opacity:0.85,marginTop:"10px",lineHeight:1.65}}>{desc}</p>
      </div>
      <div style={{padding:"14px 18px"}}>
        <div style={{fontSize:"11px",fontWeight:800,color:C.n500,marginBottom:"8px",letterSpacing:"0.06em"}}>السبب</div>
        {reasons.map((r,i)=>(
          <div key={i} style={{display:"flex",gap:"7px",marginBottom:"5px",fontSize:"12px",color:C.n700}}>
            <span style={{color:C.green,fontWeight:700,flexShrink:0}}>✓</span><span>{r}</span>
          </div>
        ))}
        {note && (
          <div style={{background:C.a50,border:`1px solid ${C.a500}33`,borderRadius:"8px",padding:"8px 12px",marginTop:"10px",fontSize:"12px",color:C.a600}}>
            💡 {note}
          </div>
        )}
        <div style={{borderTop:`1px solid ${C.n100}`,marginTop:"12px",paddingTop:"12px"}}>
          <div style={{fontSize:"11px",fontWeight:700,color:C.n500,marginBottom:"4px"}}>
            رفضنا <span style={{color:C.red,fontFamily:"'IBM Plex Mono',monospace"}}>{rejected}</span>
          </div>
          <div style={{fontSize:"12px",color:C.n500,lineHeight:1.55}}>{whyNot}</div>
        </div>
        <div style={{marginTop:"12px",display:"flex",flexWrap:"wrap",gap:"5px"}}>
          {pkgs.map(p=>(
            <span key={p} style={{fontSize:"10px",background:color.bg,color:color.fg,padding:"2px 8px",borderRadius:"5px",fontFamily:"'IBM Plex Mono',monospace",fontWeight:500}}>{p}</span>
          ))}
        </div>
      </div>
    </div>
  );
}

function ArchLayer({ layer }) {
  const { label, color, items } = layer;
  const isScale = label.includes("Phase 2");
  return (
    <div style={{
      border:`2px solid ${color.border}`,
      borderRadius:"14px",overflow:"hidden",
      opacity: isScale ? 0.85 : 1,
    }}>
      <div style={{background:color.bg,padding:"8px 16px",display:"flex",alignItems:"center",justifyContent:"space-between"}}>
        <span style={{fontSize:"11px",fontWeight:800,color:color.fg,letterSpacing:"0.08em",fontFamily:"'IBM Plex Mono',monospace"}}>{label}</span>
        {isScale && <span style={{fontSize:"10px",background:`${color.fg}22`,color:color.fg,padding:"2px 8px",borderRadius:"10px",fontWeight:700}}>Phase 2</span>}
      </div>
      <div style={{padding:"12px 16px",display:"flex",gap:"12px",flexWrap:"wrap",background:`${color.bg}55`}}>
        {items.map((item,i)=>(
          <div key={i} style={{
            display:"flex",alignItems:"center",gap:"8px",
            background:C.n0,border:`1px solid ${color.border}`,
            borderRadius:"10px",padding:"8px 14px",flex:"1",minWidth:"140px",
          }}>
            <span style={{fontSize:"18px"}}>{item.icon}</span>
            <div>
              <div style={{fontSize:"12px",fontWeight:700,color:color.fg,fontFamily:"'IBM Plex Mono',monospace",lineHeight:1.2}}>{item.name}</div>
              <div style={{fontSize:"11px",color:color.fg,opacity:0.7}}>{item.sub}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════
//  MAIN
// ═══════════════════════════════════════════
export default function WaslaTechStack() {
  const [tab, setTab] = useState("stack");
  const tabs = [
    {id:"stack",  ar:"الـ Stack الكامل"},
    {id:"arch",   ar:"المعمارية"},
    {id:"compare",ar:"لماذا X لا Y؟"},
    {id:"phases", ar:"المراحل والتكلفة"},
  ];

  return (
    <div style={{fontFamily:"'Cairo',sans-serif",direction:"rtl",background:C.n50,minHeight:"100vh",color:C.n900}}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700;800;900&family=IBM+Plex+Mono:wght@400;600&display=swap');
        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
        ::-webkit-scrollbar{width:5px;height:5px;}
        ::-webkit-scrollbar-thumb{background:${C.p200};border-radius:4px;}
      `}</style>

      {/* ── HEADER ── */}
      <div style={{
        background:`linear-gradient(145deg,${C.p900} 0%,${C.p700} 50%,#0DA0AC 100%)`,
        padding:"24px 28px 0",
        position:"sticky",top:0,zIndex:200,
      }}>
        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"18px"}}>
          <div>
            <div style={{display:"flex",alignItems:"center",gap:"12px"}}>
              <span style={{fontSize:"20px",fontWeight:900,color:"#FFF"}}>وصلة</span>
              <span style={{background:"rgba(255,255,255,0.15)",color:"rgba(255,255,255,0.75)",padding:"2px 10px",borderRadius:"20px",fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace"}}>
                Tech Stack & Infrastructure
              </span>
            </div>
            <p style={{color:"rgba(255,255,255,0.5)",fontSize:"12px",marginTop:"3px"}}>
              {STACK.filter(s=>s.phase===1).length} تقنيات في الـ MVP · {STACK.filter(s=>s.phase===2).length} تقنيات في الـ Scale · 3 مراحل نمو
            </p>
          </div>
          <div style={{display:"flex",gap:"8px"}}>
            {["TypeScript","PostgreSQL","Flutter","Supabase"].map(t=>(
              <span key={t} style={{background:"rgba(255,255,255,0.12)",border:"1px solid rgba(255,255,255,0.2)",color:"rgba(255,255,255,0.8)",padding:"4px 10px",borderRadius:"6px",fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace"}}>
                {t}
              </span>
            ))}
          </div>
        </div>
        <div style={{display:"flex",gap:"2px"}}>
          {tabs.map(t=>(
            <button key={t.id} onClick={()=>setTab(t.id)} style={{
              background:tab===t.id?"rgba(255,255,255,0.15)":"transparent",
              border:"none",borderBottom:tab===t.id?`3px solid ${C.a500}`:"3px solid transparent",
              padding:"9px 18px",cursor:"pointer",fontSize:"13px",
              fontFamily:"'Cairo',sans-serif",fontWeight:tab===t.id?700:500,
              color:tab===t.id?"#FFF":"rgba(255,255,255,0.55)",
              borderRadius:"6px 6px 0 0",transition:"all 0.15s",
            }}>{t.ar}</button>
          ))}
        </div>
      </div>

      <div style={{maxWidth:"1100px",margin:"0 auto",padding:"24px 20px 60px"}}>

        {/* ══ TAB 1: STACK ══ */}
        {tab==="stack" && (
          <div>
            {/* Phase 1 */}
            <div style={{marginBottom:"28px"}}>
              <div style={{display:"flex",alignItems:"center",gap:"12px",marginBottom:"16px"}}>
                <div style={{background:"#DCFCE7",border:"2px solid #86EFAC",borderRadius:"10px",padding:"6px 16px",display:"flex",alignItems:"center",gap:"8px"}}>
                  <span style={{fontSize:"13px",fontWeight:900,color:"#15803D",fontFamily:"'IBM Plex Mono',monospace"}}>Phase 1 — MVP</span>
                  <span style={{fontSize:"12px",color:"#15803D",opacity:0.8}}>ابدأ في 60 يوم · $0 شهرياً</span>
                </div>
              </div>
              <div style={{display:"grid",gridTemplateColumns:"repeat(2,1fr)",gap:"14px"}}>
                {STACK.filter(s=>s.phase===1).map(s=><StackCard key={s.layer} item={s}/>)}
              </div>
            </div>
            {/* Phase 2 */}
            <div>
              <div style={{display:"flex",alignItems:"center",gap:"12px",marginBottom:"16px"}}>
                <div style={{background:C.a50,border:`2px solid ${C.a500}55`,borderRadius:"10px",padding:"6px 16px",display:"flex",alignItems:"center",gap:"8px"}}>
                  <span style={{fontSize:"13px",fontWeight:900,color:C.a600,fontFamily:"'IBM Plex Mono',monospace"}}>Phase 2 — Scale</span>
                  <span style={{fontSize:"12px",color:C.a600,opacity:0.8}}>عند 10K+ مستخدم · $55–90 شهرياً</span>
                </div>
              </div>
              <div style={{display:"grid",gridTemplateColumns:"repeat(2,1fr)",gap:"14px"}}>
                {STACK.filter(s=>s.phase===2).map(s=><StackCard key={s.layer} item={s}/>)}
              </div>
            </div>
          </div>
        )}

        {/* ══ TAB 2: ARCHITECTURE ══ */}
        {tab==="arch" && (
          <div>
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"16px",padding:"20px 24px",marginBottom:"20px"}}>
              <h3 style={{fontSize:"16px",fontWeight:900,color:C.n900,marginBottom:"4px"}}>معمارية وصلة — System Architecture</h3>
              <p style={{fontSize:"13px",color:C.n500}}>البنية التحتية الكاملة من الـ Clients إلى قاعدة البيانات</p>
            </div>

            {/* Arrow between layers */}
            <div style={{display:"flex",flexDirection:"column",gap:"0px"}}>
              {ARCH_LAYERS.map((layer, i) => (
                <div key={layer.label}>
                  <ArchLayer layer={layer} />
                  {i < ARCH_LAYERS.length - 1 && (
                    <div style={{textAlign:"center",padding:"6px 0",color:C.p200,fontSize:"18px",lineHeight:1}}>↕</div>
                  )}
                </div>
              ))}
            </div>

            {/* Data Flow */}
            <div style={{marginTop:"20px",background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",padding:"18px 20px"}}>
              <div style={{fontSize:"13px",fontWeight:800,color:C.n700,marginBottom:"14px"}}>تدفق البيانات — Data Flow</div>
              <div style={{display:"flex",flexDirection:"column",gap:"10px"}}>
                {[
                  {flow:"المستخدم يفتح التطبيق",detail:"Flutter → Supabase Auth → JWT Token → Row Level Security يطبق الصلاحيات تلقائياً"},
                  {flow:"ينشر إعلاناً",detail:"Flutter → Supabase API (PostgREST) → PostgreSQL → Realtime Event → إشعار للـ Watchlist"},
                  {flow:"يبحث عن خدمة",detail:"Flutter → Typesense (Phase 2) أو Supabase Full-text → PostgreSQL PostGIS → نتائج مرتبة بالقرب"},
                  {flow:"يدفع للـ Boost",detail:"Flutter → Paymob SDK → Webhook → Supabase Edge Function → تحديث is_featured في DB"},
                  {flow:"يتلقى إشعاراً",detail:"Supabase Trigger → Edge Function → Firebase FCM → تطبيق الجوال"},
                ].map((item,i)=>(
                  <div key={i} style={{display:"flex",gap:"12px",alignItems:"flex-start",background:C.n50,borderRadius:"10px",padding:"10px 14px"}}>
                    <div style={{background:C.p50,color:C.p600,padding:"2px 10px",borderRadius:"6px",fontSize:"12px",fontWeight:700,whiteSpace:"nowrap",flexShrink:0}}>{i+1}</div>
                    <div>
                      <div style={{fontSize:"13px",fontWeight:700,color:C.n800,marginBottom:"3px"}}>{item.flow}</div>
                      <div style={{fontSize:"12px",color:C.n500,fontFamily:"'IBM Plex Mono',monospace",lineHeight:1.6}}>{item.detail}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* ══ TAB 3: COMPARISONS ══ */}
        {tab==="compare" && (
          <div>
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"16px",overflow:"hidden",marginBottom:"20px"}}>
              <div style={{padding:"14px 18px",background:C.n50,borderBottom:`1px solid ${C.n100}`}}>
                <h3 style={{fontSize:"15px",fontWeight:900,color:C.n900}}>لماذا X ولا Y؟ — قرارات معمارية موثّقة</h3>
                <p style={{fontSize:"12px",color:C.n500,marginTop:"3px"}}>كل قرار تقني له مبرر واضح — لا اختيارات عشوائية</p>
              </div>
              <div style={{overflowX:"auto"}}>
                <table style={{width:"100%",borderCollapse:"collapse",fontSize:"13px"}}>
                  <thead>
                    <tr style={{background:C.n50}}>
                      {["المجال","اخترنا ✓","رفضنا ✗","السبب"].map(h=>(
                        <th key={h} style={{padding:"10px 14px",textAlign:"right",fontWeight:700,color:C.n600,borderBottom:`2px solid ${C.n200}`,fontSize:"12px",whiteSpace:"nowrap"}}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {COMPARISONS.map((row,i)=>(
                      <tr key={i} style={{background:i%2===0?C.n0:C.n50}}>
                        <td style={{padding:"10px 14px",borderBottom:`1px solid ${C.n100}`,fontWeight:700,color:C.n700,whiteSpace:"nowrap"}}>{row.cat}</td>
                        <td style={{padding:"10px 14px",borderBottom:`1px solid ${C.n100}`}}>
                          <span style={{background:"#DCFCE7",color:"#15803D",padding:"3px 10px",borderRadius:"6px",fontSize:"12px",fontWeight:700,fontFamily:"'IBM Plex Mono',monospace"}}>{row.chosen}</span>
                        </td>
                        <td style={{padding:"10px 14px",borderBottom:`1px solid ${C.n100}`}}>
                          <span style={{background:"#FEE2E2",color:C.red,padding:"3px 10px",borderRadius:"6px",fontSize:"12px",fontWeight:700,fontFamily:"'IBM Plex Mono',monospace"}}>{row.rejected}</span>
                        </td>
                        <td style={{padding:"10px 14px",borderBottom:`1px solid ${C.n100}`,color:C.n600,fontSize:"12px",lineHeight:1.5,maxWidth:"340px"}}>{row.reason}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Language unification note */}
            <div style={{background:C.p50,border:`1px solid ${C.p100}`,borderRadius:"14px",padding:"18px 20px"}}>
              <div style={{fontSize:"14px",fontWeight:800,color:C.p600,marginBottom:"10px"}}>🎯 مبدأ "لغة واحدة"</div>
              <p style={{fontSize:"13px",color:C.p700,lineHeight:1.7}}>
                كل تقنية في الـ Stack تستخدم <strong>TypeScript / Dart</strong> فقط — لا PHP ولا Python ولا Go.
                هذا يعني كود مشترك، types مشتركة، وتطوير أسرع بـ 50%+.
              </p>
              <div style={{display:"flex",gap:"10px",marginTop:"12px",flexWrap:"wrap"}}>
                {[
                  {lang:"Dart",where:"Flutter (Mobile)"},
                  {lang:"TypeScript",where:"Next.js (Admin)"},
                  {lang:"TypeScript",where:"Supabase Edge Functions"},
                  {lang:"TypeScript",where:"NestJS (Phase 2)"},
                  {lang:"SQL",where:"PostgreSQL Migrations"},
                ].map(item=>(
                  <div key={item.where} style={{background:C.n0,border:`1px solid ${C.p100}`,borderRadius:"8px",padding:"7px 12px"}}>
                    <div style={{fontSize:"12px",fontWeight:800,color:C.p600,fontFamily:"'IBM Plex Mono',monospace"}}>{item.lang}</div>
                    <div style={{fontSize:"11px",color:C.n500}}>{item.where}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* ══ TAB 4: PHASES & COST ══ */}
        {tab==="phases" && (
          <div>
            <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:"16px",marginBottom:"24px"}}>
              {PHASES.map(ph=>(
                <div key={ph.n} style={{background:C.n0,border:`2px solid ${ph.color.accent}`,borderRadius:"16px",overflow:"hidden"}}>
                  <div style={{background:ph.color.bg,padding:"16px 18px"}}>
                    <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:"6px"}}>
                      <span style={{fontSize:"11px",fontFamily:"'IBM Plex Mono',monospace",fontWeight:800,color:ph.color.fg}}>Phase {ph.n}</span>
                      <span style={{fontSize:"11px",color:ph.color.fg,background:`${ph.color.fg}18`,padding:"2px 8px",borderRadius:"6px",fontWeight:700}}>{ph.timeAr}</span>
                    </div>
                    <div style={{fontSize:"22px",fontWeight:900,color:ph.color.fg}}>{ph.label}</div>
                    <div style={{fontSize:"12px",color:ph.color.fg,opacity:0.75,marginTop:"2px"}}>{ph.users}</div>
                  </div>
                  <div style={{padding:"14px 18px"}}>
                    <div style={{display:"flex",alignItems:"baseline",gap:"6px",marginBottom:"12px"}}>
                      <span style={{fontSize:"28px",fontWeight:900,color:ph.color.fg}}>{ph.cost}</span>
                      <span style={{fontSize:"12px",color:C.n500}}>{ph.costSub}</span>
                    </div>
                    <p style={{fontSize:"12px",color:C.n600,lineHeight:1.6,marginBottom:"12px"}}>{ph.desc}</p>
                    {ph.techs.map((t,i)=>(
                      <div key={i} style={{display:"flex",gap:"6px",marginBottom:"5px",fontSize:"12px",color:C.n700}}>
                        <span style={{color:ph.n===1?C.green:C.a500,fontWeight:700}}>→</span>{t}
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>

            {/* Cost breakdown table */}
            <div style={{background:C.n0,border:`1px solid ${C.n200}`,borderRadius:"14px",overflow:"hidden",marginBottom:"16px"}}>
              <div style={{padding:"14px 18px",background:C.n50,borderBottom:`1px solid ${C.n100}`}}>
                <h3 style={{fontSize:"14px",fontWeight:800,color:C.n900}}>تفاصيل التكاليف الشهرية</h3>
              </div>
              <div style={{overflowX:"auto"}}>
                <table style={{width:"100%",borderCollapse:"collapse",fontSize:"12px"}}>
                  <thead>
                    <tr style={{background:C.n50}}>
                      {["الخدمة","Phase 1","Phase 2","Phase 3","ملاحظة"].map(h=>(
                        <th key={h} style={{padding:"9px 14px",textAlign:"right",fontWeight:700,color:C.n600,borderBottom:`1.5px solid ${C.n200}`,fontSize:"11px"}}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {[
                      {s:"Supabase",p1:"$0 (Free)",p2:"$25",p3:"$25+",note:"Free: 500MB DB, 1GB Storage"},
                      {s:"Vercel (Next.js)",p1:"$0",p2:"$0",p3:"$20",note:"Free tier: 100GB bandwidth"},
                      {s:"Firebase FCM",p1:"$0",p2:"$0",p3:"$0",note:"مجاني تماماً — لا حدود"},
                      {s:"Paymob",p1:"% من المعاملات",p2:"% من المعاملات",p3:"% من المعاملات",note:"لا رسوم ثابتة — فقط % صغيرة"},
                      {s:"Typesense",p1:"—",p2:"$5 (VPS)",p3:"$10",note:"Hetzner VPS CX11"},
                      {s:"Upstash Redis",p1:"—",p2:"$0–10",p3:"$10–20",note:"Free: 10K commands/يوم"},
                      {s:"Cloudflare R2",p1:"—",p2:"$5–10",p3:"$15–30",note:"$0.015/GB + Zero egress"},
                      {s:"Sentry + PostHog",p1:"$0",p2:"$0",p3:"$0",note:"Free حتى 100K users"},
                      {s:"Hetzner VPS",p1:"—",p2:"$5",p3:"$20",note:"NestJS + Typesense"},
                    ].map((row,i)=>(
                      <tr key={i} style={{background:i%2===0?C.n0:C.n50}}>
                        <td style={{padding:"9px 14px",fontWeight:700,color:C.n800,borderBottom:`1px solid ${C.n100}`,fontFamily:"'IBM Plex Mono',monospace",fontSize:"12px"}}>{row.s}</td>
                        <td style={{padding:"9px 14px",color:"#15803D",fontWeight:700,borderBottom:`1px solid ${C.n100}`}}>{row.p1}</td>
                        <td style={{padding:"9px 14px",color:C.a600,fontWeight:700,borderBottom:`1px solid ${C.n100}`}}>{row.p2}</td>
                        <td style={{padding:"9px 14px",color:C.p600,fontWeight:700,borderBottom:`1px solid ${C.n100}`}}>{row.p3}</td>
                        <td style={{padding:"9px 14px",color:C.n500,borderBottom:`1px solid ${C.n100}`,fontSize:"11px"}}>{row.note}</td>
                      </tr>
                    ))}
                    <tr style={{background:"#F0FDF4"}}>
                      <td style={{padding:"11px 14px",fontWeight:900,color:"#15803D",fontFamily:"'IBM Plex Mono',monospace"}}>TOTAL</td>
                      <td style={{padding:"11px 14px",fontWeight:900,color:"#15803D",fontSize:"15px"}}>~$0</td>
                      <td style={{padding:"11px 14px",fontWeight:900,color:C.a600,fontSize:"15px"}}>~$55</td>
                      <td style={{padding:"11px 14px",fontWeight:900,color:C.p600,fontSize:"15px"}}>~$200</td>
                      <td style={{padding:"11px 14px",color:C.n500,fontSize:"11px"}}>بدون تكاليف Paymob %</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            {/* Key insight */}
            <div style={{background:`linear-gradient(135deg,${C.p900},${C.p700})`,borderRadius:"14px",padding:"20px 24px"}}>
              <div style={{fontSize:"15px",fontWeight:900,color:"#FFF",marginBottom:"10px"}}>💡 الفكرة الأساسية</div>
              <p style={{fontSize:"13px",color:"rgba(255,255,255,0.8)",lineHeight:1.8}}>
                وصلة يمكن بناؤه <strong style={{color:C.a500}}>بالكامل بـ $0 شهرياً</strong> في المرحلة الأولى.
                تبدأ تدفع فقط عندما يكون لديك مستخدمون حقيقيون — وعندها الإيرادات من Boost والاشتراكات ستغطي التكاليف بفارق كبير.
              </p>
              <div style={{display:"flex",gap:"16px",marginTop:"14px",flexWrap:"wrap"}}>
                {[
                  {n:"10 إعلانات مميزة/يوم","price":"= 500 ج.م/يوم = 15,000 ج.م/شهر"},
                  {n:"50 اشتراك Business","price":"= 14,950 ج.م/شهر"},
                ].map((item,i)=>(
                  <div key={i} style={{background:"rgba(255,255,255,0.1)",border:"1px solid rgba(255,255,255,0.2)",borderRadius:"10px",padding:"10px 14px",flex:1,minWidth:"200px"}}>
                    <div style={{fontSize:"13px",fontWeight:700,color:C.a500}}>{item.n}</div>
                    <div style={{fontSize:"12px",color:"rgba(255,255,255,0.7)",marginTop:"2px"}}>{item.price}</div>
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
